class BooruQuery {
  const BooruQuery({
    required this.tags,
    this.page = 1,
    this.limit = 40,
    this.rating,
  });

  final String tags;
  final int page;
  final int limit;
  final String? rating;

  BooruQuery copyWith({
    String? tags,
    int? page,
    int? limit,
    String? rating,
  }) {
    return BooruQuery(
      tags: tags ?? this.tags,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      rating: rating ?? this.rating,
    );
  }
}

class BooruPageResult {
  const BooruPageResult({
    required this.posts,
    required this.hasMore,
  });

  final List<PostSummary> posts;
  final bool hasMore;
}

/// 图集（Pool）：一组有序的相关帖子合集。
class BooruPool {
  const BooruPool({
    required this.id,
    required this.name,
    this.description = '',
    this.postCount = 0,
    this.postIds = const [],
  });

  final String id;
  final String name;
  final String description;
  final int postCount;
  final List<String> postIds;

  /// 显示名：下划线转空格。
  String get displayName => name.replaceAll('_', ' ');
}

class PostSummary {
  const PostSummary({
    required this.id,
    required this.thumbnailUrl,
    required this.sampleUrl,
    required this.originalUrl,
    required this.tags,
    required this.aspectRatio,
    required this.width,
    required this.height,
    required this.rating,
    required this.score,
    this.serverId = '',
    this.source,
    this.postUrl,
    this.tagGeneral = const [],
    this.tagArtist = const [],
    this.tagCharacter = const [],
    this.tagCopyright = const [],
    this.tagMeta = const [],
  });

  final String id;
  final String thumbnailUrl;
  final String sampleUrl;
  final String originalUrl;
  final List<String> tags;
  final double aspectRatio;
  final int width;
  final int height;
  final String rating;
  final int score;
  final String serverId;
  final String? source;
  final String? postUrl;
  final List<String> tagGeneral;
  final List<String> tagArtist;
  final List<String> tagCharacter;
  final List<String> tagCopyright;
  final List<String> tagMeta;
}

abstract class BooruRepository {
  /// 站点标识，用于跨站点缓存隔离。
  String get serverId;

  Future<BooruPageResult> searchPosts(BooruQuery query);
  Future<List<String>> suggestTags(String query, {int limit = 10});
  Future<List<String>> fetchTrendingTags({int limit = 20}) async => [];
  Future<List<BooruPool>> fetchPools({int page = 1, int limit = 20}) async => [];
}
