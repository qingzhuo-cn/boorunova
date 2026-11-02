// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/sankaku/parser/sankaku_parser.dart';

class SankakuRepository extends BaseBooruRepository {
  SankakuRepository({
    required super.dio,
    required super.serverId,
  });

  /// sankaku 的单页上限（`/post/index.json` 的 limit ≤ 100）。
  ///
  /// 不夹持的危害：站点超限会**静默截断**，而 hasMore 拿原始 limit 比
  /// （`100 >= 200` 为假）就把满页误判成末页。请求与 hasMore 必须共用
  /// 夹持后的同一个值。
  static const int kMaxPageSize = 100;

  @override
  int get maxPageSize => kMaxPageSize;

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    final tags = buildTagsQuery(query, BaseBooruRepository.ratingMapLong);
    final limit = clampLimit(query.limit);

    final response = await dio.get(
      '/post/index.json',
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

    final posts = SankakuParser.parsePosts(serverId, data,
        baseUrl: dio.options.baseUrl);
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: posts.length >= limit,
    );
  }

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    final response = await dio.get(
      '/tag/index.json',
      queryParameters: {
        'name': '$query*',
        'limit': limit,
      },
    );

    final data = response.data;
    if (data is! List) return [];
    return SankakuParser.parseSuggestions(data);
  }

  @override
  Future<List<String>> fetchTrendingTags({int limit = 20}) async {
    final response = await dio.get(
      '/tag/index.json',
      queryParameters: {
        'order': 'count',
        'limit': limit,
      },
    );
    final data = response.data;
    if (data is! List) return [];
    return SankakuParser.parseSuggestions(data);
  }

}
