// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/e621/parser/e621_parser.dart';
import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';

class E621Repository extends BaseBooruRepository {
  E621Repository({
    required super.dio,
    required super.serverId,
  });

  /// e621 的单页上限（官方 API 允许 1–320）。
  ///
  /// 与 danbooru 同理：站点超限会静默截断，hasMore 拿原始 limit 比会把满页
  /// 误判成末页。请求与 hasMore 共用夹持后的同一个值。
  static const int kMaxPageSize = 320;

  @override
  int get maxPageSize => kMaxPageSize;

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    // e621 同样迁移到四档 g/s/q/e；「安全」查 rating:g（rating:safe 已过时，
    // 在现行站点上要么 0 结果、要么按 sensitive 口径返回）。
    final tags = buildTagsQuery(query, ratingMapFourTier);
    final limit = clampLimit(query.limit);

    final response = await dio.get(
      '/posts.json',
      queryParameters: {
        'tags': tags,
        'page': query.page,
        'limit': limit,
      },
    );

    final data = response.data;
    if (data is! Map) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final postsData = data['posts'];
    if (postsData is! List) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final posts = E621Parser.parsePosts(serverId, postsData,
        baseUrl: dio.options.baseUrl);
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: posts.length >= limit,
    );
  }

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    if (query.isEmpty) return [];
    try {
      final response = await dio.get(
        '/tags.json',
        queryParameters: {
          'search[name_matches]': '*${query.toLowerCase()}*',
          'search[order]': 'count',
          'limit': limit,
        },
      );
      final data = response.data;
      if (data is! Map) return [];
      final tags = data['tags'];
      if (tags is! List) return [];
      return tags
          .whereType<Map<String, dynamic>>()
          .map((t) => (t['name'] as String?) ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> fetchTrendingTags({int limit = 20}) async {
    final response = await dio.get(
      '/tags.json',
      queryParameters: {
        'search[order]': 'count',
        'limit': limit,
      },
    );
    final data = response.data;
    // /tags.json 返回的是对象 {"tags": [...]}（与 suggestTags 一致），非数组。
    if (data is! Map) return [];
    final tags = data['tags'];
    if (tags is! List) return [];
    return tags
        .whereType<Map<String, dynamic>>()
        .map((e) => (e['name'] as String?) ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  @override
  Future<List<BooruPool>> fetchPools({int page = 1, int limit = 20}) async {
    // 网络/认证错误向上抛出，让 UI 显示真实原因；「暂不支持」由默认空实现表达
    final response = await dio.get(
      '/pools.json',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data;
    // e621 的接口一律包一层对象（同文件 fetchTrendingTags 里的注释已经写明
    // `/tags.json` 返回 `{"tags": [...]}`）；`/pools.json` 同样是
    // `{"pools": [...]}`。此前只接受顶层数组 → 图集在 e621 上恒为空，
    // 而能力位又说支持，入口可见却永远空态。
    final raw = data is Map ? data['pools'] : data;
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().map((m) {
      final ids = (m['post_ids'] as List? ?? [])
          .map((i) => i.toString())
          .toList();
      return BooruPool(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        description: m['description']?.toString() ?? '',
        postCount: (m['post_count'] as int?) ?? ids.length,
        postIds: ids,
      );
    }).where((p) => p.id.isNotEmpty).toList();
  }

}
