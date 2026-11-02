// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/tags_blocker/booru_tags_blocker_repo.dart';
import 'package:boorunova/data/repository/tags_blocker/entity/booru_tag.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 过滤掉命中黑名单的帖子。
///
/// 首页 / 探索 / 图集详情共用同一口径：此前只有首页过滤，用户在首页屏蔽了
/// 的标签，在探索页和图集里照样能看到。
///
/// **站点作用域**（OPT §6.4）：`serverId` 为空 = 全局屏蔽；非空 = 只在该站点
/// 屏蔽。各站标签体系不同（`cat` 在 gelbooru 是一个角色、在别的站可能是普通
/// 标签），所以「只想在某站屏蔽某个词」是真实需求。
///
/// 按**每条帖子自己的 serverId** 判定，所以调用方不需要传站点 id——收藏、
/// 搜索、图集混站展示时也不会用错作用域。
List<PostSummary> filterBlockedPosts(
  List<PostSummary> posts,
  Map<int, BooruTag> blocked,
) {
  if (blocked.isEmpty) return posts;
  final global = <String>{};
  final scoped = <String, Set<String>>{};
  for (final tag in blocked.values) {
    if (tag.name.isEmpty) continue;
    if (tag.serverId.isEmpty) {
      global.add(tag.name);
    } else {
      (scoped[tag.serverId] ??= <String>{}).add(tag.name);
    }
  }
  if (global.isEmpty && scoped.isEmpty) return posts;
  return posts.where((p) {
    if (global.isNotEmpty && p.tags.any(global.contains)) return false;
    final names = scoped[p.serverId];
    if (names != null && p.tags.any(names.contains)) return false;
    return true;
  }).toList();
}

final tagsBlockerRepoProvider = Provider<BooruTagsBlockerRepo>((ref) {
  return BooruTagsBlockerRepo();
});

final tagsBlockerStateProvider =
    StateNotifierProvider<TagsBlockerNotifier, Map<int, BooruTag>>((ref) {
  final repo = ref.read(tagsBlockerRepoProvider);
  return TagsBlockerNotifier(repo);
});

class TagsBlockerNotifier extends StateNotifier<Map<int, BooruTag>> {
  TagsBlockerNotifier(this._repo) : super(_repo.getAll());

  final BooruTagsBlockerRepo _repo;

  // 三个写操作都返回是否成功：Hive 写失败（磁盘满 / box 被隔离）此前会变成
  // 一条未捕获异常，UI 完全没有反馈，用户以为标签已经屏蔽了。
  Future<bool> push({String serverId = '', required String tag}) =>
      _guard(() => _repo.push(BooruTag(serverId: serverId, name: tag)));

  Future<bool> pushAll({String serverId = '', required List<String> tags}) =>
      _guard(() => _repo.pushAll(serverId: serverId, tags: tags));

  Future<bool> delete(int key) => _guard(() => _repo.delete(key));

  Future<bool> _guard(Future<void> Function() write) async {
    try {
      await write();
      state = _repo.getAll();
      return true;
    } catch (e) {
      debugPrint('TagsBlockerNotifier: 写入失败: $e');
      return false;
    }
  }
}
