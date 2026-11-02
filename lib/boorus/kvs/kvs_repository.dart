// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/kvs/parser/kvs_parser.dart';
import 'package:dio/dio.dart';

/// KVS 视频站仓库。
///
/// 分页语义是**实测**出来的（rule34video.com，2026-10）：
/// - `/latest-updates/<page>/` 有效（第 2 页首条 id 与第 1 页不同）；
/// - `/search/<tags>/?page=N` **无效**（返回的仍是第 1 页）；
/// - `/search/<tags>/<page>/` 返回 404；
/// - `/latest-updates/999/` 仍返回 200 且有内容（**没有"空页即结束"信号**）。
///
/// 因此：列表页按页取，并用「首条 id 与上一页相同 ⇒ 已被服务端夹住」判定结束；
/// 搜索只取第一页并显式 hasMore=false——宁可只给一页结果，也不要让无限滚动
/// 在那儿对着同一个地址反复请求。
class KvsRepository extends BaseBooruRepository {
  KvsRepository({
    required super.dio,
    required super.serverId,
  });

  /// 单页上限。
  ///
  /// KVS 是 HTML 列表页，`limit` 只用于**解析侧截断**（每页固定约 24 条）；
  /// hasMore 不看它（见 [kvsHasMore]），所以这里夹持只是防止调用方传入
  /// 一个荒谬的上限导致一页解析上千条。
  static const int kMaxPageSize = 100;

  @override
  int get maxPageSize => kMaxPageSize;

  /// 上一次请求的首条 id，用于识别服务端的分页夹持。键是查询签名。
  final Map<String, String> _firstIdOfPreviousPage = {};

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    final signature = '${query.tags}|$serverId';
    final hasTags = query.tags.trim().isNotEmpty;

    // 搜索：只取第一页（无法可靠翻页，见类注释）
    String path;
    if (!hasTags) {
      path = '/latest-updates/${query.page}/';
    } else if (query.page <= 1) {
      path = '/search/${_encodeTags(query.tags)}/';
    } else {
      // 约定路径试一次；不通就当作没有更多，不把错误抛给 UI
      try {
        final result = await _fetch(
          '/search/${_encodeTags(query.tags)}/${query.page}/',
          query,
          signature,
          paginated: true,
        );
        return result;
      } catch (_) {
        return const BooruPageResult(posts: [], hasMore: false);
      }
    }

    return _fetch(path, query, signature, paginated: !hasTags);
  }

  Future<BooruPageResult> _fetch(
    String path,
    BooruQuery query,
    String signature, {
    required bool paginated,
  }) async {
    final response = await dio.get(
      path,
      options: Options(responseType: ResponseType.plain),
    );

    final html = response.data;
    if (html is! String || html.isEmpty) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final posts = KvsParser.parseList(
      serverId,
      dio.options.baseUrl,
      html,
      limit: clampLimit(query.limit),
    );
    if (posts.isEmpty) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    // 服务端把超页请求夹回同一页时，首条 id 会与上一页相同：
    // 判定为结束（否则 hasMore 永远为真，无限滚动会反复请求同一地址）。
    final firstId = posts.first.id;
    final previousFirstId = _firstIdOfPreviousPage[signature];
    final clamped = previousFirstId != null &&
        previousFirstId == firstId &&
        query.page > 1;
    _firstIdOfPreviousPage[signature] = firstId;

    if (clamped) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: kvsHasMore(returned: posts.length, paginated: paginated),
    );
  }

  /// 是否还有下一页。
  ///
  /// **不能**用 `posts.length >= query.limit` 判断：KVS 站点每页固定给
  /// 约 24 条，而应用的页大小是 40，于是 `24 >= 40` 恒为 false——
  /// 表现就是"加载了一批缩略图之后再也不加载了"（用户实测症状）。
  /// 这里的口径是：只要本页拿到了内容且这条路径支持翻页，就继续请求；
  /// 真正结束由服务端分页夹持（首条 id 重复）与空页来判定。
  static bool kvsHasMore({required int returned, required bool paginated}) =>
      paginated && returned > 0;

  /// 视频站没有标签建议接口（标签只能从 URL slug 与标题反推）。
  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async => [];

  /// 按需解析播放地址：只带播放器配置的详情页能给出 mp4/HLS 直链。
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
      return KvsParser.parseVideoPage(html, baseUrl: dio.options.baseUrl)?.url;
    } catch (_) {
      // 失败交给查看器显示可重试的错误态
      return null;
    }
  }

  /// 播放请求头：把站点自己的 UA 与 Referer 交给播放器。
  ///
  /// KVS 的媒体走 `/get_file/...`，这类地址多数带防盗链校验——播放器
  /// 用默认 UA 去取会拿到 403 或 HTML，用户看到的就是"一直加载/播不了"。
  @override
  Map<String, String> get mediaHeaders {
    final ua = dio.options.headers['User-Agent']?.toString() ?? '';
    final base = dio.options.baseUrl;
    return {
      if (ua.isNotEmpty) 'User-Agent': ua,
      if (base.isNotEmpty) 'Referer': base.endsWith('/') ? base : '$base/',
    };
  }

  /// KVS 的标签用 `+` 连接，逐段 percent-encode。
  String _encodeTags(String tags) => tags
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('+');
}
