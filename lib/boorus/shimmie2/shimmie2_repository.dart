// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:convert';

import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/shimmie2/parser/shimmie2_parser.dart';
import 'package:dio/dio.dart';

/// Shimmie2 / paheal 系图站仓库（rule34.paheal.net、allgirls.paheal.net 等）。
///
/// 实测 paheal（2026-10）的接口现实：
/// - 新版 `/api/post/list` → **404**（这是很早的分支），所以只探一次并记住结果，
///   免得每次搜索都白打一个请求；
/// - 列表用**查询参数**：`/post/list?tags=<标签>&page=<页>` → 200
///   （路径式的 `/post/list/all/1` 是 404）；
/// - 无标签时 `/post/list/<页>` → 200；
/// - 详情页没有 `<img id="image">`，原图只在 `<meta property="og:image">` 里。
class Shimmie2Repository extends BaseBooruRepository {
  Shimmie2Repository({
    required super.dio,
    required super.serverId,
  });

  /// JSON 接口可用性。null = 还没探过。实测 paheal 为 false。
  bool? _jsonApiAvailable;

  /// 单页上限（新版 JSON 接口的 limit ≤ 100；老 HTML 分支由解析侧截断）。
  static const int kMaxPageSize = 100;

  @override
  int get maxPageSize => kMaxPageSize;

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    final limit = clampLimit(query.limit);
    // 只探一次：paheal 上这个端点恒 404，每次搜索都试等于白花一次往返
    _jsonApiAvailable ??= await _probeJsonApi();
    if (_jsonApiAvailable ?? false) {
      final viaJson = await _searchViaJson(query, limit);
      if (viaJson != null) return viaJson;
      _jsonApiAvailable = false;
    }

    final tags = _encodeTags(query.tags);
    // 实测：带标签必须用查询参数（路径式会 404）；不带标签用路径式页号
    final path = tags.isEmpty
        ? '/post/list/${query.page}'
        : '/post/list?tags=$tags&page=${query.page}';

    final response = await dio.get(
      path,
      options: Options(responseType: ResponseType.plain),
    );
    final html = response.data;
    if (html is! String || html.isEmpty) {
      return const BooruPageResult(posts: [], hasMore: false);
    }
    final posts = Shimmie2Parser.parseList(
      serverId,
      dio.options.baseUrl,
      html,
      limit: limit,
    );
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: posts.isNotEmpty && posts.length >= limit,
    );
  }

  /// 探一次新版 JSON 接口是否存在。
  Future<bool> _probeJsonApi() async {
    try {
      final response = await dio.get(
        '/api/post/list',
        queryParameters: {'limit': 1, 'page': 1},
        options: Options(responseType: ResponseType.plain),
      );
      final data = response.data;
      if (data is! String) return false;
      final trimmed = data.trimLeft();
      if (trimmed.startsWith('<')) return false;
      return jsonDecode(trimmed) != null;
    } catch (_) {
      return false;
    }
  }

  Future<BooruPageResult?> _searchViaJson(BooruQuery query, int limit) async {
    try {
      final response = await dio.get(
        '/api/post/list',
        queryParameters: {
          'query': query.tags,
          'limit': limit,
          'page': query.page,
        },
        options: Options(responseType: ResponseType.plain),
      );
      final data = response.data;
      if (data is! String) return null;
      final posts = Shimmie2Parser.parseJson(serverId, jsonDecode(data));
      if (posts.isEmpty) return null;
      return BooruPageResult(
        posts: posts.map((p) => p.toSummary(serverId)).toList(),
        hasMore: posts.length >= limit,
      );
    } catch (_) {
      return null;
    }
  }

  /// paheal 没有标签建议接口（`/tags` 是 HTML 页面）。老实的空实现：
  /// UI 会显示「无建议」，好过猜一个不存在的端点然后每次搜索都报错。
  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async => [];

  /// 详情页原图：只有 og:image 可用（实测）。列表页给的是缩略图。
  @override
  Future<String?> resolveMediaUrl(String postUrl) async {
    if (postUrl.isEmpty) return null;
    try {
      final response = await dio.get(
        postUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data;
      if (html is! String || html.isEmpty) return null;
      return Shimmie2Parser.parsePostImage(html, dio.options.baseUrl);
    } catch (_) {
      return null;
    }
  }

  String _encodeTags(String tags) => tags
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('+');
}
