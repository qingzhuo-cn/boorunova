import 'package:boorunova/boorus/danbooru/parser/danbooru_parser.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:dio/dio.dart';

class DanbooruRepository extends BooruRepository {
  DanbooruRepository({
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
        if (query.rating != null) 'rating': query.rating,
      },
    );

    final data = response.data;
    if (data is! List) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final baseUrl = _dio.options.baseUrl;
    final posts = DanbooruParser.parsePosts(_serverId, baseUrl, data);
    final hasMore = posts.length >= query.limit;

    return BooruPageResult(
        posts: posts.map((p) => p.toSummary()).toList(), hasMore: hasMore);
  }

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    final response = await _dio.get(
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
    final response = await _dio.get(
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
      final response = await _dio.get('/favorites.json', queryParameters: {
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

extension _PostToSummary on BooruPost {
  PostSummary toSummary() => PostSummary(
        id: id,
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
