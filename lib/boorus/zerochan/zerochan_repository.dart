import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/zerochan/parser/zerochan_parser.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:dio/dio.dart';

class ZerochanRepository extends BooruRepository {
  ZerochanRepository({
    required Dio dio,
    required String serverId,
  })  : _dio = dio,
        _serverId = serverId;

  final Dio _dio;
  final String _serverId;

  @override
  String get serverId => _serverId;

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    final tags = query.tags.isEmpty ? 'index' : _encodeTags(query.tags);
    final response = await _dio.get(
      '/$tags',
      queryParameters: {
        'json': null,
        'p': query.page,
        'l': query.limit,
      },
    );

    final data = response.data;
    if (data is! Map) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final map = Map<String, dynamic>.from(data);
    final posts = ZerochanParser.parsePosts(_serverId, map);
    final total = map['total'] as int? ?? 0;
    final hasMore = posts.isNotEmpty &&
        (map['pages'] as int? ?? 1) > query.page;

    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(_serverId)).toList(),
      hasMore: hasMore || (total > query.page * query.limit),
    );
  }

  String _encodeTags(String tags) {
    return tags.split(RegExp(r'\s+')).join('+');
  }

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    return [];
  }

  @override
  Future<bool> addFavorite(String postId) async {
    return false;
  }

  @override
  Future<bool> removeFavorite(String postId) async {
    return false;
  }

  @override
  Future<bool> isFavorite(String postId) async {
    return false;
  }

  @override
  Future<List<String>> getFavoriteIds() async {
    return [];
  }
}

extension _ZerochanPostToSummary on BooruPost {
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
