import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/rule34/parser/rule34_parser.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:dio/dio.dart';

class Rule34Repository extends BooruRepository {
  Rule34Repository({
    required Dio dio,
    required String serverId,
  })  : _dio = dio,
        _serverId = serverId;

  final Dio _dio;
  final String _serverId;

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    final response = await _dio.get(
      '/index.php',
      queryParameters: {
        'page': 'dapi',
        's': 'post',
        'q': 'index',
        'tags': query.tags,
        'pid': query.page - 1,
        'limit': query.limit,
        'json': 1,
      },
    );

    final data = response.data;
    if (data is! List) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final posts = Rule34Parser.parsePosts(_serverId, data);
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary()).toList(),
      hasMore: posts.length >= query.limit,
    );
  }

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    final response = await _dio.get(
      '/index.php',
      queryParameters: {
        'page': 'dapi',
        's': 'tag',
        'q': 'index',
        'name_pattern': '%$query%',
        'limit': limit,
        'json': 1,
      },
    );

    final data = response.data;
    if (data is! List) return [];
    return Rule34Parser.parseSuggestions(data);
  }

  @override
  Future<List<String>> fetchTrendingTags({int limit = 20}) async {
    final response = await _dio.get(
      '/index.php',
      queryParameters: {
        'page': 'dapi',
        's': 'tag',
        'q': 'index',
        'orderby': 'count',
        'limit': limit,
        'json': 1,
      },
    );
    final data = response.data;
    if (data is! List) return [];
    return Rule34Parser.parseSuggestions(data);
  }

  @override
  Future<bool> addFavorite(String postId) async => false;

  @override
  Future<bool> removeFavorite(String postId) async => false;

  @override
  Future<bool> isFavorite(String postId) async => false;

  @override
  Future<List<String>> getFavoriteIds() async => [];
}

extension _Rule34PostToSummary on BooruPost {
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
