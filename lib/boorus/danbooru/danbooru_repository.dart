import 'package:boorunova/boorus/danbooru/parser/danbooru_parser.dart';
import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';

class DanbooruRepository extends BaseBooruRepository {
  DanbooruRepository({
    required super.dio,
    required super.serverId,
  });

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    // danbooru 的评级标签用短形式 rating:s/q/e
    final tags = <String>[
      if (query.tags.isNotEmpty) query.tags,
      if (query.rating != null)
        switch (query.rating!) {
          's' => 'rating:s',
          'q' => 'rating:q',
          'e' => 'rating:e',
          _ => 'rating:${query.rating}',
        },
    ].join(' ');

    final response = await dio.get(
      '/posts.json',
      queryParameters: {
        'tags': tags,
        'page': query.page,
        'limit': query.limit,
      },
    );

    final data = response.data;
    if (data is! List) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final baseUrl = dio.options.baseUrl;
    final posts = DanbooruParser.parsePosts(serverId, baseUrl, data);
    final hasMore = posts.length >= query.limit;

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
    try {
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
      return data.map((e) {
        final m = e as Map<String, dynamic>;
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
    } catch (_) {
      return [];
    }
  }

}
