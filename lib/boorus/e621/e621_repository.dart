import 'package:boorunova/boorus/e621/parser/e621_parser.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:dio/dio.dart';

class E621Repository extends BooruRepository {
  E621Repository({
    required Dio dio,
    required String serverId,
  })  : _dio = dio,
        _serverId = serverId;

  final Dio _dio;
  final String _serverId;

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    final response = await _dio.get(
      '/posts.json',
      queryParameters: {
        'tags': query.tags,
        'page': query.page,
        'limit': query.limit,
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

    final posts = E621Parser.parsePosts(_serverId, postsData);
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(_serverId)).toList(),
      hasMore: posts.length >= query.limit,
    );
  }

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    return [];
  }

  @override
  Future<List<String>> fetchTrendingTags({int limit = 20}) async {
    final response = await _dio.get(
      '/tags.json',
      queryParameters: {
        'search[order]': 'count',
        'limit': limit,
      },
    );
    final data = response.data;
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => (e['name'] as String?) ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  @override
  Future<bool> addFavorite(String postId) async {
    try {
      await _dio.post('/favorites.json', data: {'post_id': postId});
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> removeFavorite(String postId) async {
    try {
      await _dio.delete('/favorites/$postId.json');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isFavorite(String postId) async {
    try {
      final response = await _dio.get('/favorites.json', queryParameters: {
        'search[post_id]': postId,
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
      final response = await _dio.get('/favorites.json', queryParameters: {
        'limit': 100,
      });
      final data = response.data;
      if (data is! List) return [];
      return data.map((e) => (e['post_id'] ?? e['id'])?.toString() ?? '').toList();
    } catch (_) {
      return [];
    }
  }
}

extension _E621PostToSummary on BooruPost {
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


