import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/gelbooru_v2/parser/gelbooru_v2_parser.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:dio/dio.dart';

class SafebooruRepository extends BooruRepository {
  SafebooruRepository({
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
      },
    );

    final xml = response.data;
    if (xml is! String || !xml.contains('<post')) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final posts = GelbooruV2Parser.parsePosts(
      _serverId,
      _dio.options.baseUrl,
      xml,
    );
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
        'orderby': 'count',
        'limit': limit,
      },
    );

    final xml = response.data;
    if (xml is! String || !xml.contains('<tag')) return [];

    return GelbooruV2Parser.parseSuggestions(xml);
  }

  @override
  Future<bool> addFavorite(String postId) async {
    try {
      await _dio.post('/index.php', queryParameters: {
        'page': 'favorites',
        's': 'add',
        'id': postId,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> removeFavorite(String postId) async {
    try {
      await _dio.post('/index.php', queryParameters: {
        'page': 'favorites',
        's': 'remove',
        'id': postId,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isFavorite(String postId) async {
    try {
      final response = await _dio.get('/index.php', queryParameters: {
        'page': 'favorites',
        's': 'index',
        'id': postId,
        'limit': 1,
      });
      return response.data.toString().contains('<post');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getFavoriteIds() async {
    return [];
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
