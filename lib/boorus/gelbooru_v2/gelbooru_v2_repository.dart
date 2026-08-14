import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/gelbooru_v2/parser/gelbooru_v2_parser.dart';

class GelbooruV2Repository extends BaseBooruRepository {
  GelbooruV2Repository({
    required super.dio,
    required super.serverId,
  });

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

    final response = await dio.get(
      '/index.php',
      queryParameters: {
        'page': 'dapi',
        's': 'post',
        'q': 'index',
        'tags': tags,
        'pid': query.page - 1,
        'limit': query.limit,
      },
    );

    final xml = response.data;
    if (xml is! String || !xml.contains('<post')) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final posts = GelbooruV2Parser.parsePosts(
      serverId,
      dio.options.baseUrl,
      xml,
    );
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: posts.length >= query.limit,
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
      },
    );
    final xml = response.data;
    if (xml is! String || !xml.contains('<tag')) return [];
    return GelbooruV2Parser.parseSuggestions(xml);
  }

}
