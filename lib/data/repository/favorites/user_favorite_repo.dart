import 'dart:convert';

import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

final userFavoritesRepoProvider = Provider<UserFavoritesRepo>((ref) {
  return UserFavoritesRepo();
});

class UserFavoritesRepo {
  Box get _box => HiveSetup.settingsBox;

  static const _key = 'favorites';

  /// 内存缓存：首次访问时从 Hive 反序列化一次，之后 isFavorite 走 O(1) 哈希。
  /// 实例失效（ref.invalidate）后缓存随之丢弃，下次访问惰性重载。
  List<BooruPost>? _cache;
  Set<String>? _keySet;

  List<BooruPost> _load() {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = _box.get(_key) as String?;
    final list = raw == null
        ? <BooruPost>[]
        : (jsonDecode(raw) as List)
            .map((e) => BooruPost.fromJson(e as Map<String, dynamic>))
            .toList();
    _cache = list;
    _keySet = list.map((p) => _keyFor(p.id, p.serverId)).toSet();
    return list;
  }

  List<BooruPost> getAll() => List.unmodifiable(_load());

  static String _keyFor(String postId, String serverId) => '$serverId|$postId';

  bool isFavorite(String postId, {String serverId = ''}) {
    _load();
    return _keySet!.contains(_keyFor(postId, serverId));
  }

  Future<void> toggle(BooruPost post) async {
    final all = _load();
    final key = _keyFor(post.id, post.serverId);
    final existing = all.indexWhere((p) => _keyFor(p.id, p.serverId) == key);
    if (existing >= 0) {
      all.removeAt(existing);
      _keySet!.remove(key);
    } else {
      all.add(post);
      _keySet!.add(key);
    }
    await _persist();
  }

  Future<void> saveAll(List<BooruPost> posts) async {
    _cache = List.of(posts);
    _keySet = posts.map((p) => _keyFor(p.id, p.serverId)).toSet();
    await _persist();
  }

  Future<void> remove(String postId, {String serverId = ''}) async {
    final all = _load();
    final key = _keyFor(postId, serverId);
    all.removeWhere((p) => _keyFor(p.id, p.serverId) == key);
    _keySet!.remove(key);
    await _persist();
  }

  // 缓存变更发生在首个 await 之前，未 await 的调用方随后 invalidate 也能读到新值
  // （Hive 的 put 同步更新内存帧，落盘异步）。
  Future<void> _persist() =>
      _box.put(_key, jsonEncode(_cache!.map((p) => p.toJson()).toList()));

  int get count => _load().length;
}
