// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:convert';

import 'package:boorunova/data/repository/server/credential_store.dart';
import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/server/entity/server_preferences.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/util/json_safe.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

final userServerRepoProvider = Provider<UserServerRepo>((ref) {
  return UserServerRepo();
});

class UserServerRepo {
  Box get _box => HiveSetup.serversBox;
  Box get _settingsBox => HiveSetup.settingsBox;
  static const _orderKey = 'server_order';

  /// 进程内的凭据镜像。
  ///
  /// 仓库的读取 API（[getAll] / [getById]）是**同步**的——十几处调用点都在
  /// build 里直接用——而安全存储是异步的。折中办法：启动时一次性把凭据读进
  /// 这里（见 [initCredentials]），之后读取路径同步覆盖到实体上。
  static final Map<String, ServerCredentials> _credentials = {};

  static CredentialStore _store = SecureCredentialStore();

  /// 换一个凭据存储（测试用）。
  @visibleForTesting
  static void useCredentialStore(CredentialStore store) {
    _store = store;
    _credentials.clear();
  }

  @visibleForTesting
  static Map<String, ServerCredentials> get credentialCache => _credentials;

  /// 启动时调用（`main` 里、首帧之前）。
  ///
  /// 两件事：
  /// 1. 把安全存储里的凭据读进内存镜像；
  /// 2. **一次性迁移**旧版本的明文凭据：先写进安全存储、读回确认，再抹掉
  ///    Hive 里的明文。顺序不能反——写失败就抹掉等于直接丢用户的 API Key。
  ///
  /// 必须在首帧之前完成：home_page 第一次请求就要带凭据，晚一步会以未认证
  /// 身份先打一枪（部分站点直接 401，用户看到的是「站点要 key」）。
  static Future<void> initCredentials() async {
    final repo = UserServerRepo();
    for (final server in repo._rawAll()) {
      ServerCredentials? stored;
      try {
        stored = await _store.read(server.id);
      } catch (e) {
        // 安全存储不可用（设备策略、Keystore 密钥失效）不能让应用起不来，
        // 也不能抹掉旧明文：保持原样，下次启动再试。
        debugPrint('读取凭据失败，保留原状: $e');
        continue;
      }

      final legacy = ServerCredentials(
        login: server.login,
        apiKey: server.apiKey,
      );
      final hasLegacy = legacy.isNotEmpty;

      if (hasLegacy) {
        try {
          await _store.write(server.id, legacy);
          // 读回确认：Keystore 写入失败在个别设备上是「静默」的
          final verify = await _store.read(server.id);
          if (verify == null || verify.isEmpty) {
            debugPrint('凭据迁移复核失败，保留 Hive 明文: ${server.id}');
            _credentials[server.id] = legacy;
            continue;
          }
          _credentials[server.id] = verify;
          // 确认落进安全存储之后才抹掉明文
          await repo._persist(server);
        } catch (e) {
          debugPrint('凭据迁移失败，保留 Hive 明文: $e');
          _credentials[server.id] = legacy;
        }
        continue;
      }

      if (stored != null && stored.isNotEmpty) {
        _credentials[server.id] = stored;
      }
    }

    await _purgeOrphans(repo._rawAll().map((s) => s.id).toSet());
  }

  /// 清理没有对应服务器的孤儿凭据。
  ///
  /// **只在刚刚发生过 box 损坏隔离时做**：那种情况下服务器记录确实没了，
  /// 安全存储里的密文却还在（两者同属应用私有目录，正常路径同生同死）。
  ///
  /// 一般情况刻意**不**清理：`_rawAll()` 会跳过单条损坏的记录——若为此就把
  /// 「服务器列表里暂时看不到」当成「已删除」，就会静默丢掉用户的 API Key。
  /// 宁可留一会儿孤儿，也不冒丢凭据的风险。
  static Future<void> _purgeOrphans(Set<String> liveIds) async {
    if (!HiveSetup.recoveredFromCorruption) return;
    try {
      final stored = await _store.ids();
      for (final id in stored) {
        if (liveIds.contains(id)) continue;
        debugPrint('清理孤儿凭据: $id');
        await _store.delete(id);
      }
    } catch (e) {
      debugPrint('清理孤儿凭据失败: $e');
    }
  }

  List<String> get _order {
    final raw = _settingsBox.get(_orderKey);
    if (raw is! List) return [];
    // 跳过非字符串元素，避免 schema 漂移时 cast 抛错。
    return raw.whereType<String>().toList();
  }

  Future<void> _saveOrder(List<String> order) async {
    await _settingsBox.put(_orderKey, order);
  }

  /// 解析出一条记录，**不叠加**内存凭据镜像。
  BooruServer? _parse(Object? value) {
    if (value is! String) return null;
    try {
      final map = asStringMap(jsonDecode(value));
      if (map == null) return null;
      return BooruServer.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// 全部站点的原始实体（凭据来自 Hive 里的历史字段，可能为空）。
  List<BooruServer> _rawAll() {
    final servers = <BooruServer>[];
    for (final v in _box.values) {
      final server = _parse(v);
      // 单条数据损坏时跳过，不让整个服务器列表加载崩溃。
      if (server != null) servers.add(server);
    }
    return servers;
  }

  /// 叠加内存镜像里的凭据。
  BooruServer _hydrate(BooruServer server) {
    final credentials = _credentials[server.id];
    if (credentials == null) return server;
    return server.withCredentials(credentials);
  }

  List<BooruServer> getAll() {
    final servers = _rawAll().map(_hydrate).toList();

    final order = _order;
    if (order.isEmpty) return servers;

    final map = {for (final s in servers) s.id: s};
    final ordered = <BooruServer>[];
    for (final id in order) {
      if (map.containsKey(id)) {
        ordered.add(map.remove(id)!);
      }
    }
    ordered.addAll(map.values);
    return ordered;
  }

  /// 按**展示顺序**移动一个站点。
  ///
  /// 下标基准必须是展示列表：`getAll()` 会把 order 里没有的站点追加到
  /// 尾部（旧版本写入路径、备份导入都可能漏记 order），所以 order 可能比
  /// 展示列表短。此前直接以 order 当下标基准，用户拖动第 3 项时实际移动的
  /// 是 order 的第 3 项，与看到的列表错位。这里先用 getAll 的完整 id 序列
  /// 重建 order 再移动，顺带把 order 补齐。
  Future<void> reorder(int oldIndex, int newIndex) {
    final ids = getAll().map((s) => s.id).toList();
    if (ids.isEmpty || oldIndex < 0 || oldIndex >= ids.length) {
      return Future<void>.value();
    }
    var target = newIndex;
    if (target > oldIndex) target--;
    if (target < 0) target = 0;
    if (target >= ids.length) target = ids.length - 1;
    final item = ids.removeAt(oldIndex);
    ids.insert(target, item);
    return _saveOrder(ids);
  }

  /// 某站点的偏好；站点不存在或 id 为空时返回「全部跟随全局」。
  ///
  /// 浏览与下载路径都要按站点取偏好，而它们手里只有 serverId（帖子带着它），
  /// 没有整条实体。收在这里，避免每处各写一遍 null 兜底。
  ServerPreferences preferencesOf(String? serverId) {
    if (serverId == null || serverId.isEmpty) {
      return const ServerPreferences();
    }
    return getById(serverId)?.preferences ?? const ServerPreferences();
  }

  BooruServer? getById(String id) {
    final server = _parse(_box.get(id));
    return server == null ? null : _hydrate(server);
  }

  /// 只写 Hive 记录（走 toStoredJson，凭据的键都不会出现）。
  Future<void> _persist(BooruServer server) async {
    await _box.put(server.id, jsonEncode(server.toStoredJson()));
  }

  /// 安全存储调用包一层：设备策略 / 密钥失效时不能把整条保存流程带崩。
  /// 返回是否成功，失败留日志。
  static Future<bool> _storeSafely(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (e) {
      debugPrint('安全存储写入失败: $e');
      return false;
    }
  }

  /// 保存站点。
  ///
  /// 返回**凭据是否成功持久化**：写不进安全存储时站点仍然保存成功（但凭据
  /// 只在本会话有效），调用方据此提示用户，而不是让它在下次启动时静默消失。
  Future<bool> save(BooruServer server) async {
    // 凭据先落安全存储，再写不含凭据的 Hive 记录：反过来的话，写安全存储
    // 失败时明文已经没了，用户的 Key 就静默丢了。
    final credentials = ServerCredentials(
      login: server.login,
      apiKey: server.apiKey,
    );
    var persisted = true;
    if (credentials.isEmpty) {
      await _storeSafely(() => _store.delete(server.id));
      _credentials.remove(server.id);
    } else {
      final wrote =
          await _storeSafely(() => _store.write(server.id, credentials));
      // 复核一次：个别设备的 Keystore 是**静默失败**的（调用不报错、读回来
      // 却是空）。保存是低频操作，多一次往返换「提示可信」划算。
      persisted = wrote && await _verifyStored(server.id, credentials);
      // 写失败也放进内存镜像：本次会话照常可用，且**站点本身不会保存失败**
      // （用户看到的是「添加成功」，而不是一个说不清原因的报错）。
      _credentials[server.id] = credentials;
      if (!persisted) {
        debugPrint('凭据未能持久化，仅本会话有效: ${server.id}');
      }
    }
    await _persist(server);
    final order = _order;
    if (!order.contains(server.id)) {
      order.add(server.id);
      await _saveOrder(order);
    }
    return persisted;
  }

  /// 导入备份时保存站点：写记录，但**完全不碰凭据存储**。
  ///
  /// 备份本来就不含凭据（`toBackupJson`），所以导入绝不该有「清空某个站点
  /// 凭据」的副作用。用 [save] 会走到「凭据为空 → 删掉存储里的条目」那条
  /// 分支：只要哪天调用方忘了按 id 跳过已存在的站点，用户导入一次备份就会
  /// 静默丢掉自己的 API Key。把这条通道单独拆出来，安全性就不再依赖调用方
  /// 记得先过滤。
  Future<void> saveImported(BooruServer server) async {
    await _persist(server);
    final order = _order;
    if (!order.contains(server.id)) {
      order.add(server.id);
      await _saveOrder(order);
    }
    // 已有的凭据继续生效（导入的实体里没有凭据字段）
    final credentials = await _readStored(server.id);
    if (credentials != null) _credentials[server.id] = credentials;
  }

  /// 读回确认凭据真的落进了安全存储。
  static Future<bool> _verifyStored(
    String id,
    ServerCredentials expected,
  ) async {
    try {
      final read = await _store.read(id);
      if (read == null || read.isEmpty) return false;
      if (expected.apiKey != null && read.apiKey != expected.apiKey) {
        return false;
      }
      if (expected.login != null && read.login != expected.login) return false;
      return true;
    } catch (e) {
      debugPrint('凭据复核失败: $e');
      return false;
    }
  }

  static Future<ServerCredentials?> _readStored(String id) async {
    try {
      return await _store.read(id);
    } catch (e) {
      debugPrint('读取凭据失败: $e');
      return null;
    }
  }

  /// 只更新站点偏好。
  ///
  /// 不走 [save]：改一个画质不该顺手触发一次凭据写入与读回复核，更不该因为
  /// 安全存储此刻不可用而给用户弹「凭据没保存」的提示。
  Future<void> savePreferences(
    String id,
    ServerPreferences preferences,
  ) async {
    final server = getById(id);
    if (server == null) return;
    await _persist(server.copyWith(preferences: preferences));
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
    // 站点没了，安全存储里的凭据也要清掉，否则是永久残留的机密
    await _storeSafely(() => _store.delete(id));
    _credentials.remove(id);
    final order = _order;
    order.remove(id);
    await _saveOrder(order);
  }

  Future<void> update(BooruServer server) async {
    await save(server);
  }

  int get count => _box.length;
}
