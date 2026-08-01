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

  List<BooruPost> getAll() {
    final raw = _box.get(_key) as String?;
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => BooruPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String _keyFor(String postId, String serverId) => '$serverId|$postId';

  bool isFavorite(String postId, {String serverId = ''}) {
    final key = _keyFor(postId, serverId);
    return getAll().any((p) => _keyFor(p.id, p.serverId) == key);
  }

  Future<void> toggle(BooruPost post) async {
    final all = getAll();
    final key = _keyFor(post.id, post.serverId);
    final existing = all.indexWhere((p) => _keyFor(p.id, p.serverId) == key);
    if (existing >= 0) {
      all.removeAt(existing);
    } else {
      all.add(post);
    }
    await _box.put(_key, jsonEncode(all.map((p) => p.toJson()).toList()));
  }

  Future<void> saveAll(List<BooruPost> posts) async {
    await _box.put(_key, jsonEncode(posts.map((p) => p.toJson()).toList()));
  }

  Future<void> remove(String postId, {String serverId = ''}) async {
    final all = getAll();
    final key = _keyFor(postId, serverId);
    all.removeWhere((p) => _keyFor(p.id, p.serverId) == key);
    await _box.put(_key, jsonEncode(all.map((p) => p.toJson()).toList()));
  }

  int get count => getAll().length;
}
