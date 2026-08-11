import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/moebooru/parser/moebooru_parser.dart';

class MoebooruRepository extends BaseBooruRepository {
  MoebooruRepository({
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
      '/post.json',
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

    final posts = MoebooruParser.parsePosts(serverId, data);
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: posts.length >= query.limit,
    );
  }

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    final response = await dio.get(
      '/tag.json',
      queryParameters: {
        'name': '*$query*',
        'order': 'count',
        'limit': limit,
      },
    );

    final data = response.data;
    if (data is! List) return [];
    return MoebooruParser.parseSuggestions(data);
  }

  @override
  Future<List<String>> fetchTrendingTags({int limit = 20}) async {
    final response = await dio.get(
      '/tag.json',
      queryParameters: {'order': 'count', 'limit': limit},
    );
    final data = response.data;
    if (data is! List) return [];
    return MoebooruParser.parseSuggestions(data);
  }

  @override
  Future<bool> addFavorite(String postId) async {
    try {
      await dio.post('/post/$postId/favorites.json');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> removeFavorite(String postId) async {
    try {
      await dio.delete('/post/$postId/favorites.json');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isFavorite(String postId) async {
    try {
      final response = await dio.get('/favorite/index.json', queryParameters: {
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
    return [];
  }
}
