// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/database/json_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

final userFavoritesRepoProvider = Provider<UserFavoritesRepo>((ref) {
  return UserFavoritesRepo();
});

class UserFavoritesRepo {
  static const _key = 'favorites';

  static JsonListStore get _store => JsonListStore(HiveSetup.settingsBox, _key);

  /// 内存缓存：`isFavorite` 会被瀑布流每格调用，不能每次都解码整份 JSON。
  ///
  /// 刻意做成 **static**：仓库实例随 `ref.invalidate` 重建，而缓存若跟着实例走，
  /// 就会出现「A 实例持旧快照、B 实例持新快照，各自整键覆写」——v1.8.0 修过
  /// 下载历史同一类丢更新，这里漏了。缓存全局一份，写入统一走 JsonListStore
  /// 的串行事务（事务内部读的是**存储里的最新值**，不是这份缓存）。
  static Box? _cacheBox;
  static List<BooruPost>? _cache;
  static Set<String>? _keySet;

  static List<BooruPost> _load() {
    final box = HiveSetup.settingsBox;
    // box 换了（重启、测试里换临时目录）就丢掉旧缓存
    if (!identical(_cacheBox, box)) {
      _cacheBox = box;
      _cache = null;
      _keySet = null;
    }
    final cached = _cache;
    if (cached != null) return cached;
    _adopt(_store.read());
    return _cache!;
  }

  /// 用一份「存储格式」的列表重建缓存。
  static void _adopt(List<Map<String, dynamic>> items) {
    final list = items
        .map((m) {
          try {
            return BooruPost.fromJson(m);
          } catch (_) {
            return null;
          }
        })
        .whereType<BooruPost>()
        .toList();
    _cache = list;
    _keySet = list.map((p) => _keyFor(p.id, p.serverId)).toSet();
  }

  List<BooruPost> getAll() => List.unmodifiable(_load());

  static String _keyFor(String postId, String serverId) => '$serverId|$postId';

  static String _keyOfEntry(Map<String, dynamic> entry) =>
      _keyFor('${entry['id'] ?? ''}', '${entry['serverId'] ?? ''}');

  /// [serverId] 必传：键是 `serverId|postId`，给个空串默认值会拼出一个
  /// 永远不存在的键，`isFavorite` 静默返回 false、`remove` 静默删不到，
  /// 而调用方看不到任何异常。漏传应该在编译期就报错。
  bool isFavorite(String postId, {required String serverId}) {
    _load();
    return _keySet!.contains(_keyFor(postId, serverId));
  }

  Future<void> toggle(BooruPost post) async {
    final key = _keyFor(post.id, post.serverId);
    final written = await _store.update((items) {
      final exists = items.any((e) => _keyOfEntry(e) == key);
      if (exists) {
        return items.where((e) => _keyOfEntry(e) != key).toList();
      }
      // 新收藏放最前：收藏页按存储顺序展示，最近收藏应该在最上面
      return <Map<String, dynamic>>[post.toJson(), ...items];
    });
    _adopt(written);
  }

  Future<void> saveAll(List<BooruPost> posts) async {
    final encoded = posts.map((p) => p.toJson()).toList();
    await _store.write(encoded);
    _adopt(encoded);
  }

  /// 同 [isFavorite]：`serverId` 必传，漏传会拼出空 serverId 的键而删不到。
  Future<void> remove(String postId, {required String serverId}) async {
    final key = _keyFor(postId, serverId);
    final written = await _store.update(
      (items) => items.where((e) => _keyOfEntry(e) != key).toList(),
    );
    _adopt(written);
  }

  int get count => _load().length;
}
