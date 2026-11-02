// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'dart:async';
import 'dart:convert';

import 'package:boorunova/foundation/util/json_safe.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

/// 带版本、写队列与损坏保护的 JSON 列表存储。
///
/// 存在的理由是把此前散在 6 个仓库里的三个隐患一次性收口：
///
/// 1. **并发丢更新**：此前每个仓库各自「读全量 → 改 → 整键覆写」，两处并发
///    （批量收藏 + 网格点赞、批量下载 + 单图下载）后写者会覆盖先写者。
///    这里所有写走同一条按键串行的队列，且读发生在队列内部，改的是最新值。
/// 2. **"损坏"与"空"不可区分**：此前解码失败一律返回空列表，紧接着一次
///    `add` 就会把整键覆写成只含新元素的内容——用户的收藏/历史就这么没了。
///    这里解码失败时先把原始值**改名留证**，再以空列表继续，并在同一次
///    运行内拒绝覆盖写入。
/// 3. **没有 schema 版本**：值写成 `{'_v': 2, 'items': [...]}`，读到裸数组
///    （v1）自动升级；读到比自己更新的版本则**不动它**，避免降级把数据写没。
class JsonListStore {
  JsonListStore(this._box, this._key);

  final Box _box;
  final String _key;

  /// 当前写入格式版本。读到裸 `List` 视为 v1，下次写入自动升级到 v2。
  static const int schemaVersion = 2;

  /// 每个键一条写队列。静态是为了跨实例共享——仓库实例随 `ref.invalidate`
  /// 重建，但存储只有一份，队列必须也跟着只有一条。
  static final Map<String, Future<void>> _tail = <String, Future<void>>{};

  /// 本次运行内该键是否遇到过损坏。
  static final Set<String> _corruptedKeys = <String>{};

  bool get corrupted => _corruptedKeys.contains(_key);

  /// 原始值备份到哪个键（损坏时才有值），供用户/开发者人工找回。
  String get backupKey => '${_key}__corrupt';

  Future<void> _enqueue(Future<void> Function() op) {
    final previous = _tail[_key] ?? Future<void>.value();
    final next = previous.then((_) => op());
    // 队列不能因为一次失败就断掉：接住异常，让后续写入继续排队。
    _tail[_key] = next.catchError((_) {});
    return next;
  }

  /// 读全部条目。单条畸形数据跳过，整键畸形则隔离原始值后返回空列表。
  List<Map<String, dynamic>> read() {
    final raw = asStringOrNull(_box.get(_key));
    if (raw == null || raw.isEmpty) return const [];

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      _quarantine(raw);
      return const [];
    }

    List<dynamic>? list;
    if (decoded is List) {
      // v1 裸数组：老数据，读到即视为合法，下次写入升级为 v2。
      list = decoded;
    } else if (decoded is Map) {
      // `_v` 可能是数字、数字字符串，也可能缺失/类型漂移。硬转型
      // `as num?` 遇到 `{'_v': '2'}` 这类数据会抛 TypeError，而本文件的
      // 承诺是「读取永不抛」——一次异常就把整份数据判成读不出来。
      final v = decoded['_v'];
      final version =
          v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 1 : 1);
      if (version > schemaVersion) {
        // 比当前代码更新的格式（例如用户装回了旧版本）：既不能解析也不能
        // 覆盖，否则等于用旧结构把新数据写坏。隔离留证并停止写入。
        _quarantine(raw);
        return const [];
      }
      final items = decoded['items'];
      list = items is List ? items : null;
      if (list == null) {
        _quarantine(raw);
        return const [];
      }
    } else {
      _quarantine(raw);
      return const [];
    }

    final result = <Map<String, dynamic>>[];
    for (final item in list) {
      // 转换必须和 fromJson 一样在 try 内：元素 key 非 String 时
      // Map<String, dynamic>.from 会抛 TypeError，此前它被放在 try 外，
      // 「单条畸形跳过」的承诺是落空的。
      try {
        final map = asStringMap(item);
        if (map != null) result.add(map);
      } catch (_) {
        // 跳过这一条
      }
    }
    return result;
  }

  /// 整键覆盖写入（串行）。
  Future<void> write(List<Map<String, dynamic>> items) =>
      _enqueue(() => _put(items));

  /// 串行的事务式改写入：读最新值 → 交给 [change] 改 → 写回。
  /// 返回写入后的列表，方便调用方同步刷新自己的内存缓存。
  Future<List<Map<String, dynamic>>> update(
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>> current)
        change,
  ) {
    late List<Map<String, dynamic>> result;
    return _enqueue(() async {
      final next = change(read());
      await _put(next);
      result = next;
    }).then((_) => result);
  }

  Future<void> _put(List<Map<String, dynamic>> items) async {
    if (_corruptedKeys.contains(_key)) {
      // 读到过损坏值：说明这份数据已经不是用户以为的那份了。继续覆盖会
      // 把「隔离出来的原始值」变成唯一的真相，静默丢掉剩余可恢复内容。
      // 本进程内拒绝写入，等用户重启后按新数据重新开始（原始值已留证）。
      throw StateError('存储 $backupKey 已损坏并被隔离，本次运行不再写入');
    }
    await _box.put(
      _key,
      jsonEncode(<String, dynamic>{'_v': schemaVersion, 'items': items}),
    );
  }

  /// 把无法解析的原始值改名放到 `<key>__corrupt`，并标记本进程不再写入。
  void _quarantine(String raw) {
    _corruptedKeys.add(_key);
    // put/delete 必须**同步一起发起**：read() 是同步 API，调用方（含单测）
    // 依赖「read() 返回时原始值已改名到 __corrupt、原键已清空」。
    // 但「同步发起」不等于「不处理结果」——修复前这两个 Future 没人接收，
    // 写盘失败（Android 上并不罕见）就是一条未处理异步异常，日志里只剩红字。
    // 这里把两个 Future 投进已有的写队列 await，并单独接住异常记日志；
    // 队列自身有 catchError 兜底，不会因为这次失败而卡死。
    Future<void> backup;
    try {
      backup = Future.wait<void>([
        _box.put(backupKey, raw),
        _box.delete(_key),
      ]).then<void>((_) {});
    } catch (e) {
      // box 已关闭等同步异常：备份失败也不能让 read() 抛，上层要能继续跑起来。
      debugPrint('JsonListStore: 隔离损坏值失败 key=$_key: $e');
      return;
    }
    unawaited(_enqueue(() => backup).catchError((e) {
      debugPrint('JsonListStore: 隔离损坏值失败 key=$_key: $e');
    }));
  }

  /// 清空（用于测试与「清除数据」入口）。
  Future<void> clear() => _enqueue(() => _box.delete(_key));

  /// 仅供测试：重置静态状态，避免用例之间互相污染。
  @visibleForTesting
  static void resetForTest() {
    _tail.clear();
    _corruptedKeys.clear();
  }
}
