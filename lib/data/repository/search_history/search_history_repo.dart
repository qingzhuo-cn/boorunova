// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'dart:convert';

import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/database/json_store.dart';
import 'package:boorunova/foundation/util/json_safe.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final searchHistoryRepoProvider = Provider<SearchHistoryRepo>((ref) {
  return SearchHistoryRepo();
});

/// 搜索历史仓库。
///
/// 迁移到 [JsonListStore] 的理由：此前是「读全量 → 改 → 整键覆写」，两个
/// 入口并发（搜索页 add + 设置页清除）会互相覆盖；解码失败还会被当成空列表，
/// 紧接着一次 add 就把用户的历史整键写没。
class SearchHistoryRepo {
  static const _key = 'search_history';

  /// 历史条数上限。
  static const int maxEntries = 20;

  /// 老格式（裸字符串数组）是否已转换。
  static bool _legacyConverted = false;

  static JsonListStore get _store =>
      JsonListStore(HiveSetup.settingsBox, _key);

  /// 元素在 JSON 里的键名。
  static const String _field = 'q';

  /// 老格式是 `jsonEncode(List<String>)`。
  ///
  /// [JsonListStore.read] 只认 Map 元素，直接切过去会把现有历史**全部丢掉**
  /// 并在下一次写入时把空结果固化——所以第一次访问时先原地转换一次：
  /// `['a','b']` → `{'_v':2,'items':[{'q':'a'},{'q':'b'}]}`。
  static void _convertLegacyIfNeeded() {
    if (_legacyConverted) return;
    _legacyConverted = true;
    final raw = asStringOrNull(HiveSetup.settingsBox.get(_key));
    if (raw == null || raw.isEmpty) return;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      // 畸形值交给 JsonListStore 的隔离逻辑处理
      return;
    }
    // 已经是封套（Map）就不是老格式
    if (decoded is! List) return;
    final items = <Map<String, dynamic>>[
      for (final item in decoded)
        if (item is String && item.isNotEmpty) {_field: item},
    ];
    // put 先更新内存值再落盘，读路径立刻能看到转换结果
    HiveSetup.settingsBox.put(
      _key,
      jsonEncode(<String, dynamic>{
        '_v': JsonListStore.schemaVersion,
        'items': items,
      }),
    );
  }

  List<String> getAll() {
    _convertLegacyIfNeeded();
    return _store
        .read()
        .map((m) => m[_field]?.toString() ?? '')
        .where((q) => q.isNotEmpty)
        .toList();
  }

  Future<void> add(String query) {
    _convertLegacyIfNeeded();
    if (query.isEmpty) return Future<void>.value();
    return _store.update((items) {
      final next = items
          .where((m) => m[_field]?.toString() != query)
          .toList()
        ..insert(0, <String, dynamic>{_field: query});
      if (next.length > maxEntries) {
        next.removeRange(maxEntries, next.length);
      }
      return next;
    });
  }

  Future<void> remove(String query) {
    _convertLegacyIfNeeded();
    return _store.update((items) => items
        .where((m) => m[_field]?.toString() != query)
        .toList());
  }

  Future<void> clear() => _store.clear();

  Future<void> replaceAll(List<String> items) {
    _convertLegacyIfNeeded();
    return _store.write([
      for (final query in items.take(maxEntries))
        if (query.isNotEmpty) {_field: query},
    ]);
  }

  /// 仅供测试：重置迁移标记（静态状态会跨用例残留）。
  @visibleForTesting
  static void resetForTest() => _legacyConverted = false;
}
