// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/data/repository/tags_blocker/entity/booru_tag.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/database/json_store.dart';

class BooruTagsBlockerRepo {
  static const _key = 'blocked_tags';

  static JsonListStore get _store => JsonListStore(HiveSetup.settingsBox, _key);

  /// 取值。
  ///
  /// 每条记录的键此前是「列表下标」——每次载入按位置重建，任何一次增删都会
  /// 让 UI 手里那个 key 指向另一个标签（`delete(entry.key)` 删错人）。
  /// 现在键随记录一起落盘（`_key` 字段），跨启动稳定。
  /// 兼容老格式：裸 `BooruTag` JSON 的列表按下标补键，下次写入即升级。
  Map<int, BooruTag> getAll() {
    final items = _store.read();
    final result = <int, BooruTag>{};
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      try {
        // 新格式：{'_key': n, 'tag': {...}}；老格式：{serverId, name}
        final rawTag = item['tag'];
        if (rawTag is Map) {
          final key = (item['_key'] as num?)?.toInt();
          if (key == null) continue;
          result[key] = BooruTag.fromJson(Map<String, dynamic>.from(rawTag));
        } else {
          // 老格式：键按 1 基下标补（与 _upgradeLegacy 的口径一致，
          // 否则「读出来的 key」和「写回去的 key」对不上，删除会删错条目）
          result[i + 1] = BooruTag.fromJson(item);
        }
      } catch (_) {
        // 单条畸形跳过，不让整个屏蔽列表加载崩溃。
      }
    }
    return result;
  }

  /// 新增一条屏蔽标签。名称去重、空名忽略。
  Future<void> push(BooruTag tag) =>
      pushAll(serverId: tag.serverId, tags: [tag.name]);

  /// 批量新增。整批走**一次**事务：此前逐条 `push` 各做一遍
  /// 「读全量 → 判重 → 覆写」，与别处的并发写入互相覆盖。
  Future<void> pushAll({String serverId = '', required List<String> tags}) {
    final incoming =
        tags.map((t) => t.trim()).where((n) => n.isNotEmpty).toList();
    if (incoming.isEmpty) return Future<void>.value();

    return _store.update((items) {
      // 去重键必须含 serverId：只按名字去重的话，「已经全局屏蔽 cat，再想只在
      // A 站屏蔽 cat」会被静默吞掉——用户以为加上了，实际什么都没发生。
      final existing = <String>{
        for (final item in items)
          if (item['tag'] is Map)
            _dedupeKey(
              '${(item['tag'] as Map)['serverId'] ?? ''}',
              '${(item['tag'] as Map)['name'] ?? ''}',
            )
          else
            _dedupeKey('', '${item['name'] ?? ''}'),
      };
      var nextKey = items.fold<int>(0, (max, item) {
        final k = (item['_key'] as num?)?.toInt() ?? 0;
        return k > max ? k : max;
      });
      final next = [..._upgradeLegacy(items)];
      for (final name in incoming) {
        final key = _dedupeKey(serverId, name);
        if (existing.contains(key)) continue;
        existing.add(key);
        nextKey += 1;
        next.add({
          '_key': nextKey,
          'tag': BooruTag(serverId: serverId, name: name).toJson(),
        });
      }
      return next;
    });
  }

  /// 去重键 = 作用域 + 标签名。
  ///
  /// 用 `\u0000` 分隔：标签名里不会有它，避免「serverId 尾部 + 名字」拼出
  /// 与另一条记录相同的字符串（例如 ('a','bc') 与 ('ab','c')）。
  static String _dedupeKey(String serverId, String name) =>
      '${serverId.trim()}\u0000${name.trim()}';

  /// 把老格式（裸标签，键=下标）升级成带 `_key` 的新格式，避免升级后
  /// 「一部分记录有稳定键、一部分还按下标」这种半吊子状态。
  List<Map<String, dynamic>> _upgradeLegacy(List<Map<String, dynamic>> items) {
    final result = <Map<String, dynamic>>[];
    var index = 0;
    for (final item in items) {
      if (item['tag'] is Map) {
        result.add(item);
        continue;
      }
      index += 1;
      result.add({'_key': index, 'tag': item});
    }
    return result;
  }

  Future<void> delete(int key) {
    return _store.update((items) {
      // 先把老格式升级成稳定键，再按键删——否则老数据（无 _key）永远删不掉。
      final upgraded = _upgradeLegacy(items);
      return upgraded
          .where((item) => (item['_key'] as num?)?.toInt() != key)
          .toList();
    });
  }

  List<String> getBlockedTagNames({String? serverId}) {
    final all = getAll();
    return all.values
        .where((t) =>
            serverId == null || t.serverId.isEmpty || t.serverId == serverId)
        .map((t) => t.name)
        .toList();
  }
}
