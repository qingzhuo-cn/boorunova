// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/gelbooru_v2/parser/gelbooru_v2_parser.dart';
import 'package:boorunova/boorus/rule34/parser/rule34_parser.dart';
import 'package:flutter/foundation.dart';

class Rule34Repository extends BaseBooruRepository {
  Rule34Repository({
    required super.dio,
    required super.serverId,
  });

  /// rule34.xxx 与 gelbooru 同源（DAPI 协议兼容），单页上限按 gelbooru 的
  /// 公开接口口径取 100：请求更大的 limit 站点会静默截断，而 hasMore 若
  /// 拿原始 limit 去比就会把满页误判成末页。
  static const int kMaxPageSize = 100;

  @override
  int get maxPageSize => kMaxPageSize;

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    final tags = buildTagsQuery(query, BaseBooruRepository.ratingMapLong);
    // 请求与 hasMore 必须共用夹持后的同一个值（见 clampLimit 注释）。
    final limit = clampLimit(query.limit);

    final response = await dio.get(
      '/index.php',
      queryParameters: {
        'page': 'dapi',
        's': 'post',
        'q': 'index',
        'tags': tags,
        'pid': query.page - 1,
        'limit': limit,
        'json': 1,
        ...authQueryParams,
      },
    );

    final data = response.data;
    // rule34 走 JSON DAPI：既可能是顶层数组，也可能被包成对象（`{"post":[...]}`）
    final raw = data is Map ? (data['post'] ?? data['posts']) : data;
    if (raw is! List) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    // 把本站点自己的 web 域名交给解析器：镜像站（rule34.us 等）此前帖子
    // 链接一律硬编码指向 rule34.xxx。
    final posts = Rule34Parser.parsePosts(serverId, raw,
        siteUrl: dio.options.baseUrl);
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: posts.length >= limit,
    );
  }

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    final response = await dio.get(
      '/index.php',
      queryParameters: {
        'page': 'dapi',
        's': 'tag',
        'q': 'index',
        'name_pattern': '%$query%',
        'limit': limit,
        'json': 1,
        // 与 searchPosts 一致：本站要 api_key + user_id，漏了会静默 401，
        // 表现是「永远没有标签建议」。
        ...authQueryParams,
      },
    );

    return _parseTagResponse(response.data);
  }

  @override
  Future<List<String>> fetchTrendingTags({int limit = 20}) async {
    final response = await dio.get(
      '/index.php',
      queryParameters: {
        'page': 'dapi',
        's': 'tag',
        'q': 'index',
        'orderby': 'count',
        'limit': limit,
        'json': 1,
        ...authQueryParams,
      },
    );
    return _parseTagResponse(response.data);
  }

  /// tag 建议/热门标签的响应形态从未验证：带 json=1 时本站**有时**仍回
  /// XML DAPI（`<tags><tag name="..." count="..." /></tags>`）。
  ///
  /// 修复前的故障：`if (data is! List) return []` 把非 List（含 XML）一律
  /// 静默吞掉——用户看到「没有任何标签建议」却无从判断是站点没建议还是
  /// 解析不认。这里对 XML 复用 GelbooruV2Parser.parseSuggestions，其余
  /// 形态打 debugPrint 说明到底收到了什么，便于定位。
  List<String> _parseTagResponse(Object? data) {
    if (data is List) {
      return Rule34Parser.parseSuggestions(data);
    }
    if (data is String && RegExp(r'<tag[\s>]').hasMatch(data)) {
      return GelbooruV2Parser.parseSuggestions(data);
    }
    debugPrint('[Rule34Repository] tag 建议响应非预期形态：'
        '${_describeResponse(data)}');
    return [];
  }

  String _describeResponse(Object? data) {
    if (data is String) {
      final head = data.length > 120 ? data.substring(0, 120) : data;
      return 'String(${data.length} 字符) 前 120 字：$head';
    }
    return '${data.runtimeType}';
  }
}
