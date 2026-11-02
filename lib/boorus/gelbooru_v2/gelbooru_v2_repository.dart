// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/gelbooru_v2/parser/gelbooru_v2_parser.dart';

class GelbooruV2Repository extends BaseBooruRepository {
  GelbooruV2Repository({
    required super.dio,
    required super.serverId,
  });

  /// gelbooru 系 DAPI 的单页上限（公开接口口径为 100）：请求更大的 limit
  /// 会被静默截断，而 hasMore 若拿原始 limit 去比就会把满页误判成末页。
  static const int kMaxPageSize = 100;

  @override
  int get maxPageSize => kMaxPageSize;

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    final tags = <String>[
      if (query.tags.isNotEmpty) query.tags,
      if (query.rating != null)
        switch (query.rating!) {
          's' => 'rating:safe',
          'q' => 'rating:questionable',
          'e' => 'rating:explicit',
          _ => 'rating:${query.rating}',
        },
    ].join(' ');
    // 请求与 hasMore 必须共用夹持后的同一个值（见 clampLimit 注释）。
    final limit = clampLimit(query.limit);

    final response = await dio.get(
      '/index.php',
      queryParameters: {
        'page': 'dapi',
        's': 'post',
        'q': 'index',
        'tags': tags,
        'pid': query.page - 1,
        'limit': limit,
        ...authQueryParams,
      },
    );

    final xml = response.data;
    // 守卫必须用 `<post` + 空白/`>`：`xml.contains('<post')` 对零结果响应
    // `<posts count="0" offset="0"></posts>` 也成立（'<posts' 含 '<post'），
    // 等于没有守卫。
    if (xml is! String || !RegExp(r'<post[\s>]').hasMatch(xml)) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final posts = GelbooruV2Parser.parsePosts(
      serverId,
      dio.options.baseUrl,
      xml,
    );
    // 分页用响应自带的 count/offset：此前用「本页条数 >= limit」，只要解析
    // 过滤掉一条（缺 file_url 或尺寸）就会被判成末页，第 2 页永远加载不到
    // 且没有任何提示。取不到 count 时才退回旧口径。
    final count = GelbooruV2Parser.parseCount(xml);
    final offset = GelbooruV2Parser.parseOffset(xml);
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: (count != null && offset != null)
          ? offset + posts.length < count
          : posts.length >= limit,
    );
  }

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    final response = await dio.get(
      '/index.php',
      queryParameters: {
        'page': 'dapi',
        's': 'tag',
        'q': 'index',
        'name_pattern': '%$query%',
        'orderby': 'count',
        'limit': limit,
        // 修复前的故障：tag 接口没带 authQueryParams，gelbooru / rule34
        // 这类需要 api_key+user_id 的站点会静默 401，标签建议永远为空；
        // 帖子搜索（searchPosts）此前已带，这里补齐保持一致。
        ...authQueryParams,
      },
    );

    final xml = response.data;
    if (xml is! String || !xml.contains('<tag')) return [];

    return GelbooruV2Parser.parseSuggestions(xml);
  }

  @override
  Future<List<String>> fetchTrendingTags({int limit = 20}) async {
    final response = await dio.get(
      '/index.php',
      queryParameters: {
        'page': 'dapi',
        's': 'tag',
        'q': 'index',
        'orderby': 'count',
        'limit': limit,
        // 同 suggestTags：需 key 的站点此前建议静默 401。
        ...authQueryParams,
      },
    );
    final xml = response.data;
    if (xml is! String || !xml.contains('<tag')) return [];
    return GelbooruV2Parser.parseSuggestions(xml);
  }

}
