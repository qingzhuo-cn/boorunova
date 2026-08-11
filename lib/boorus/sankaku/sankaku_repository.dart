import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/sankaku/parser/sankaku_parser.dart';

class SankakuRepository extends BaseBooruRepository {
  SankakuRepository({
    required super.dio,
    required super.serverId,
  });

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    final tags = buildTagsQuery(query, BaseBooruRepository.ratingMapLong);

    final response = await dio.get(
      '/post/index.json',
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

    final posts = SankakuParser.parsePosts(serverId, data);
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: posts.length >= query.limit,
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
