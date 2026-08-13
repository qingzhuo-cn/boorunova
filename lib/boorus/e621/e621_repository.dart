import 'package:boorunova/boorus/e621/parser/e621_parser.dart';
import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';

class E621Repository extends BaseBooruRepository {
  E621Repository({
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
      '/posts.json',
      queryParameters: {
        'tags': tags,
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

    final posts = E621Parser.parsePosts(serverId, postsData);
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: posts.length >= query.limit,
    );
  }

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    if (query.isEmpty) return [];
    try {
      final response = await dio.get(
        '/tags.json',
        queryParameters: {
          'search[name_matches]': '*${query.toLowerCase()}*',
          'search[order]': 'count',
          'limit': limit,
        },
      );
      final data = response.data;
      if (data is! Map) return [];
      final tags = data['tags'];
      if (tags is! List) return [];
      return tags
          .whereType<Map<String, dynamic>>()
          .map((t) => (t['name'] as String?) ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
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
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => (e['name'] as String?) ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  @override
  Future<List<BooruPool>> fetchPools({int page = 1, int limit = 20}) async {
    try {
      final response = await dio.get(
        '/pools.json',
        queryParameters: {'page': page, 'limit': limit},
      );
      final data = response.data;
      if (data is! List) return [];
      return data.whereType<Map<String, dynamic>>().map((m) {
        final ids = (m['post_ids'] as List? ?? [])
            .map((i) => i.toString())
            .toList();
        return BooruPool(
          id: m['id']?.toString() ?? '',
          name: m['name']?.toString() ?? '',
          description: m['description']?.toString() ?? '',
          postCount: (m['post_count'] as int?) ?? ids.length,
          postIds: ids,
        );
      }).where((p) => p.id.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
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
      final response = await dio.get('/favorites.json', queryParameters: {
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
