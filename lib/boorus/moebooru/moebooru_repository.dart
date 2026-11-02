// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/moebooru/parser/moebooru_parser.dart';

class MoebooruRepository extends BaseBooruRepository {
  MoebooruRepository({
    required super.dio,
    required super.serverId,
  });

  /// moebooru（yande.re / konachan 等）单页上限为 100：请求更大的 limit
  /// 会被静默截断，而 hasMore 若拿原始 limit 去比就会把满页误判成末页。
  static const int kMaxPageSize = 100;

  @override
  int get maxPageSize => kMaxPageSize;

  /// moebooru 的认证只认 `login` + `password_hash` 两个**查询参数**，
  /// HTTP Basic 对它完全无效（registry 统一塞的 Authorization 头会被忽略）。
  ///
  /// 凭据由 registry 放进 dio.options.extra：authLogin 是用户名，
  /// authApiKey 存 password_hash。修复前本仓库全程不带任何认证，需要登录
  /// 才能看的帖子/图集在填了凭据后依然拿不到。
  Map<String, dynamic> get _moebooruAuthParams {
    final extra = dio.options.extra;
    final login = extra['authLogin'];
    final passwordHash = extra['authApiKey'];
    return <String, dynamic>{
      if (login is String && login.isNotEmpty) 'login': login,
      if (passwordHash is String && passwordHash.isNotEmpty)
        'password_hash': passwordHash,
    };
  }

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
    // 请求与 hasMore 必须共用夹持后的同一个值（见 clampLimit 注释）。
    final limit = clampLimit(query.limit);

    final response = await dio.get(
      '/post.json',
      queryParameters: {
        'tags': tags,
        'page': query.page,
        'limit': limit,
        ..._moebooruAuthParams,
      },
    );

    final data = response.data;
    if (data is! List) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final posts = MoebooruParser.parsePosts(serverId, data,
        siteUrl: dio.options.baseUrl);
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: posts.length >= limit,
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
        ..._moebooruAuthParams,
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
      queryParameters: {
        'order': 'count',
        'limit': limit,
        ..._moebooruAuthParams,
      },
    );
    final data = response.data;
    if (data is! List) return [];
    return MoebooruParser.parseSuggestions(data);
  }

  @override
  Future<List<BooruPool>> fetchPools({int page = 1, int limit = 20}) async {
    // 网络/认证错误向上抛出，让 UI 显示真实原因；「暂不支持」由默认空实现表达
    final response = await dio.get(
      '/pool.json',
      queryParameters: {
        'page': page,
        'limit': limit,
        ..._moebooruAuthParams,
      },
    );
    final data = response.data;
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().map((m) {
      return BooruPool(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        description: m['description']?.toString() ?? '',
        postCount: m['post_count'] as int? ?? 0,
      );
    }).where((p) => p.id.isNotEmpty).toList();
  }

}
