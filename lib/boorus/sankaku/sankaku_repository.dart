import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/sankaku/parser/sankaku_parser.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:dio/dio.dart';

class SankakuRepository extends BooruRepository {
  SankakuRepository({
    required Dio dio,
    required String serverId,
  })  : _dio = dio,
        _serverId = serverId;

  final Dio _dio;
  final String _serverId;

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    final response = await _dio.get(
      '/post/index.json',
      queryParameters: {
        'tags': query.tags,
        'page': query.page,
        'limit': query.limit,
      },
    );

    final data = response.data;
    if (data is! List) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final posts = SankakuParser.parsePosts(_serverId, data);
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(_serverId)).toList(),
      hasMore: posts.length >= query.limit,
    );
  }

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    final response = await _dio.get(
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
    final response = await _dio.get(
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
      await _dio.post('/post/$postId/favorites.json');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> removeFavorite(String postId) async {
    try {
      await _dio.delete('/post/$postId/favorites.json');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isFavorite(String postId) async {
    try {
      final response = await _dio.get('/favorite/index.json', queryParameters: {
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

extension _SankakuPostToSummary on BooruPost {
  PostSummary toSummary(String serverId) => PostSummary(
        id: id,
        serverId: serverId,
        thumbnailUrl: thumbnailUrl,
        sampleUrl: sampleUrl,
        originalUrl: originalUrl,
        tags: tags,
        tagGeneral: tagGeneral,
        tagArtist: tagArtist,
        tagCharacter: tagCharacter,
        tagCopyright: tagCopyright,
        tagMeta: tagMeta,
        aspectRatio: aspectRatio,
        width: width,
        height: height,
        rating: rating,
        score: score,
        source: source,
        postUrl: postUrl,
      );
}


