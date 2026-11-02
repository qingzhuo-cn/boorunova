// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/danbooru/parser/danbooru_parser.dart';
import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';

class DanbooruRepository extends BaseBooruRepository {
  DanbooruRepository({
    required super.dio,
    required super.serverId,
  });

  /// danbooru 的单页上限（官方 API 允许 1–200）。
  ///
  /// 不夹持的危害不只是「请求被拒」：站点会**静默截断**到上限，而 hasMore
  /// 若拿原始 limit 去比（`100 >= 200` 为假），明明还有下一页却判成末页。
  static const int kMaxPageSize = 200;

  @override
  int get maxPageSize => kMaxPageSize;

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    // danbooru 2024 起是四档 g/s/q/e；UI 的「安全」对应 g（s 已是 sensitive）
    final tags = buildTagsQuery(query, ratingMapFourTier);
    // 请求与 hasMore 必须共用夹持后的同一个值
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
    if (data is! List) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final baseUrl = dio.options.baseUrl;
    final posts = DanbooruParser.parsePosts(serverId, baseUrl, data);
    final hasMore = posts.length >= limit;

    return BooruPageResult(
        posts: posts.map((p) => p.toSummary(serverId)).toList(), hasMore: hasMore);
  }

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    final response = await dio.get(
      '/tags.json',
      queryParameters: {
        'search[name_matches]': '*$query*',
        'search[order]': 'count',
        'limit': limit,
      },
    );

    final data = response.data;
    if (data is! List) return [];

    return DanbooruParser.parseSuggestions(data);
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
    if (data is! List) return [];
    return DanbooruParser.parseSuggestions(data);
  }

  @override
  Future<List<BooruPool>> fetchPools({int page = 1, int limit = 20}) async {
    // 网络/认证错误向上抛出，让 UI 显示真实原因；「暂不支持」由默认空实现表达
    final response = await dio.get(
      '/pools.json',
      queryParameters: {
        'page': page,
        'limit': limit,
        'search[order]': 'updated_at',
      },
    );
    final data = response.data;
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().map((m) {
      final ids = (m['post_ids'] as List? ?? [])
          .map((i) => i.toString())
          .toList();
      return BooruPool(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        description: m['description']?.toString() ?? '',
        postCount: m['post_count'] as int? ?? ids.length,
        postIds: ids,
      );
    }).where((p) => p.id.isNotEmpty).toList();
  }

}
