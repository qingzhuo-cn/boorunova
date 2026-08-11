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
  Future<bool> addFavorite(String postId) async {
    try {
      await dio.post('/favorites.json', data: {'post_id': postId});
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> removeFavorite(String postId) async {
    try {
      await dio.delete('/favorites/$postId.json');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isFavorite(String postId) async {
    try {
      final response = await dio.get('/favorites.json', queryParameters: {
        'post_id': postId,
        'limit': 1,
      });
      final data = response.data;
      return data is List && data.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getFavoriteIds() async {
    try {
      final response = await dio.get('/favorites.json', queryParameters: {
        'limit': 100,
      });
      final data = response.data;
      if (data is! List) return [];
      return data.map((e) => e['post_id']?.toString() ?? '').toList();
    } catch (_) {
      return [];
    }
  }
}
