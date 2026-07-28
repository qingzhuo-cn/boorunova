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

  bool isFavorite(String postId) {
    return getAll().any((p) => p.id == postId);
  }

  Future<void> toggle(BooruPost post) async {
    final all = getAll();
    final existing = all.indexWhere((p) => p.id == post.id);
    if (existing >= 0) {
      all.removeAt(existing);
    } else {
      all.add(post);
    }
    await _box.put(_key, jsonEncode(all.map((p) => p.toJson()).toList()));
  }

  Future<void> remove(String postId) async {
    final all = getAll();
    all.removeWhere((p) => p.id == postId);
    await _box.put(_key, jsonEncode(all.map((p) => p.toJson()).toList()));
  }

  int get count => getAll().length;
}
