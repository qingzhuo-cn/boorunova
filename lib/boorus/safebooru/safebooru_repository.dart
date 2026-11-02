// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/gelbooru_v2/parser/gelbooru_v2_parser.dart';
import 'package:flutter/foundation.dart';

class SafebooruRepository extends BaseBooruRepository {
  SafebooruRepository({
    required super.dio,
    required super.serverId,
  });

  /// safebooru.org 的 DAPI 与 gelbooru 同源，单页上限同为 100：请求更大的
  /// limit 会被静默截断，而 hasMore 若拿原始 limit 去比就会把满页误判成
  /// 末页。
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
        ...authQueryParams,
      },
    );

    final xml = response.data;
    // 守卫用 `<post` + 空白/`>`：`contains('<post')` 对零结果响应
    // `<posts count="0" offset="0">` 也成立，等于没有守卫。
    if (xml is! String || !RegExp(r'<post[\s>]').hasMatch(xml)) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final posts = GelbooruV2Parser.parsePosts(
      serverId,
      dio.options.baseUrl,
      xml,
    );
    // 分页用响应自带的 count/offset（实测 `<posts count="6960037" offset="0">`）。
    // 用「本页条数 >= limit」推断会在解析过滤掉一条时误判为末页。
    final count = GelbooruV2Parser.parseCount(xml);
    final offset = GelbooruV2Parser.parseOffset(xml);
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: (count != null && offset != null)
          ? offset + posts.length < count
          : posts.length >= limit,
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
        'orderby': 'count',
        'limit': limit,
        // 与 searchPosts 一致：漏了凭据会静默 401
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
        ...authQueryParams,
      },
    );
    return _parseTagResponse(response.data);
  }

  /// tag 建议/热门标签的响应形态未被验证过（详见 M2）：
  ///
  /// 修复前的故障：`if (xml is! String || !xml.contains('<tag')) return []`
  /// 把任何非预期响应静默吞掉，用户只看到「没有建议」，查不到原因。
  /// XML 正常走 GelbooruV2Parser.parseSuggestions；其余形态打 debugPrint
  /// 说明收到了什么，端点本身不做猜测性改动。
  List<String> _parseTagResponse(Object? data) {
    if (data is String && RegExp(r'<tag[\s>]').hasMatch(data)) {
      return GelbooruV2Parser.parseSuggestions(data);
    }
    debugPrint('[SafebooruRepository] tag 建议响应非预期形态：'
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
