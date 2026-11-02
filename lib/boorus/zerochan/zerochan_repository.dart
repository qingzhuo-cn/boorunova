// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/zerochan/parser/zerochan_parser.dart';

class ZerochanRepository extends BaseBooruRepository {
  ZerochanRepository({
    required super.dio,
    required super.serverId,
  });

  /// zerochan 的单页上限（`l` 参数 ≤ 100）。
  ///
  /// 站点超限会静默截断，hasMore 若拿原始 limit 比就把满页误判成末页。
  static const int kMaxPageSize = 100;

  @override
  int get maxPageSize => kMaxPageSize;

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    final limit = clampLimit(query.limit);
    // 空查询走站点根路径。此前走 `/index`，实测命中的是标签「Index」的图
    // （item 的 tag 字段为 "Index"）——默认浏览（首页、侧栏头图、探索）
    // 会变成某个角色的图集。
    final path = query.tags.isEmpty ? '/' : '/${_encodeTags(query.tags)}';
    final response = await dio.get(
      path,
      queryParameters: {
        // 用真实值而不是 null：Dio 可能丢弃 null 参数，导致请求不带 json 标志而返回 HTML。
        'json': '1',
        'p': query.page,
        'l': limit,
      },
    );

    final data = response.data;
    if (data is! Map) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final map = Map<String, dynamic>.from(data);
    final posts = ZerochanParser.parsePosts(serverId, map,
        baseUrl: dio.options.baseUrl);

    // hasMore 用「本页是否满员」判定。列表响应实测并不含 total / pages
    // （只有 items 与 id/width/height/md5/thumbnail/source/tag/tags），
    // 旧实现读那两个键恒为 0/1 → hasMore 恒 false，无限滚动永远停在第 1 页
    // （最多 40 张），而且 `posts.isNotEmpty && ...` 曾被 `||` 短路掉，
    // 空页也可能被当成还有下一页，形成自驱请求。
    final hasMore = posts.isNotEmpty && posts.length >= limit;

    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: hasMore,
    );
  }

  /// zerochan 的多标签分隔符是**逗号**：实测 `/Solo+Smile?json=1` 返回 404，
  /// `/Solo,Smile?json=1` 正常。此前用 `+` 拼接，导致任何 ≥2 标签的搜索
  /// （以及被拼进查询串的评级标签）在该站点全部失效。
  String _encodeTags(String tags) => tags
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map(Uri.encodeComponent)
      .join(',');

  /// zerochan 无标签建议 API，返回空。
  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    return [];
  }

  /// zerochan 无热门标签 API，返回空。
  @override
  Future<List<String>> fetchTrendingTags({int limit = 20}) async {
    return [];
  }
}
