// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/data/repository/booru/entity/post.dart';

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
    this.duration,
    this.tagGeneral = const [],
    this.tagArtist = const [],
    this.tagCharacter = const [],
    this.tagCopyright = const [],
    this.tagMeta = const [],
    this.isVideo = false,
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

  /// 视频时长（`mm:ss`），仅视频站提供；时间线瓦片用它替代空白的播放标记。
  final String? duration;

  final List<String> tagGeneral;
  final List<String> tagArtist;
  final List<String> tagCharacter;
  final List<String> tagCopyright;
  final List<String> tagMeta;

  /// 视频帖标记：由解析器显式给出，而不是靠 URL 后缀推断。
  ///
  /// 视频站的列表页只给缩略图，帖子里没有 mp4/HLS 地址，靠 URL 判定必然
  /// 判成图片帖（点开只显示一张图）。这条标记是"打开时去解析播放地址"的
  /// 唯一依据。
  final bool isVideo;

  /// 转为可持久化的 [BooruPost]（收藏仓库的数据类型）。
  ///
  /// 此前四个调用点（首页收藏、批量收藏、查看器收藏、详情页收藏）各自
  /// 手写一份 17 字段的字面量拷贝。字段一多就必然漏传，而漏传是静默的
  /// ——收藏成功但数据残缺，没有任何报错。
  BooruPost toPost() => BooruPost(
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
        duration: duration,
        isVideo: isVideo,
      );
}

/// 展示用媒体 URL：优先 sample，退回 original，最后 thumbnail。
/// 单个下载、批量下载与详情页预览共用同一条优先级，避免三处各选各的。
String mediaUrlOf(PostSummary post) {
  if (post.sampleUrl.isNotEmpty) return post.sampleUrl;
  if (post.originalUrl.isNotEmpty) return post.originalUrl;
  return post.thumbnailUrl;
}

/// 跨站点唯一键：`serverId + postId`。
///
/// postId 只在单个站点内唯一。此前批量选择直接拿裸 postId 当 key，
/// 切换站点时选择状态不会被清空（clear 只在下拉刷新和手动清空时触发），
/// 于是 A 站的 42 号选择会误命中 B 站的 42 号——批量下载/收藏/分享
/// 把它一起带上。这正是收藏、下载、历史三处早已用 serverId 隔离、
/// 唯独批量选择漏掉的那一维。
String postKeyOf(PostSummary post) => '${post.serverId}/${post.id}';

/// 下载 URL 选择。[preferSample] 为真且 sample 存在时用 sample，
/// 否则走 [mediaUrlOf] 的优先级。
///
/// 单图下载、下载进度图标查询、批量下载此前各写一份三元表达式，
/// 其中一处还靠注释「与这里保持一致」来同步——改一处忘另一处就静默
/// 分叉，用户设了 sample 却被按原图下载。
/// 查看器预览用的地址。
///
/// [preferOriginal] 为真且站点确实给了原图时用原图，否则走 [mediaUrlOf]
/// 的优先级（sample 优先）。存在这个函数是因为 [mediaUrlOf] **总是**优先
/// sample——只传 `preferSample: false` 是拿不到原图的，站点偏好里的「预览用
/// 原图」会静默失效。
String previewUrlOf(PostSummary post, {required bool preferOriginal}) {
  if (preferOriginal && post.originalUrl.isNotEmpty) return post.originalUrl;
  return mediaUrlOf(post);
}

String downloadUrlOf(PostSummary post, {bool preferSample = false}) {
  if (preferSample && post.sampleUrl.isNotEmpty) return post.sampleUrl;
  return mediaUrlOf(post);
}

/// 下载前先补齐"需要按需解析"的地址。
///
/// 视频站帖子的三个地址里**没有**媒体地址（列表页只给缩略图），直接用
/// [downloadUrlOf] 会下到一张缩略图 jpg；paheal 系同理（列表只有缩略图）。
/// 这里在下载前解析一次真实地址，解析不到才退回原来的地址。
///
/// 图片站零开销：自带 original/sample 的帖子直接返回，连仓库都不碰。
Future<String> resolveDownloadUrl(
  PostSummary post,
  BooruRepository? repository, {
  bool preferSample = false,
}) async {
  final direct = downloadUrlOf(post, preferSample: preferSample);
  final needsResolve =
      post.isVideo && post.originalUrl.isEmpty && post.sampleUrl.isEmpty;
  if (!needsResolve) return direct;

  final pageUrl = permalinkOf(post);
  if (repository == null || pageUrl.isEmpty) return direct;
  // 站点必须对得上：拿另一个站点的仓库去解析只会得到 404 或垃圾
  if (post.serverId.isNotEmpty && repository.serverId != post.serverId) {
    return direct;
  }
  try {
    final resolved = await repository.resolveMediaUrl(pageUrl);
    return (resolved == null || resolved.isEmpty) ? direct : resolved;
  } catch (_) {
    return direct;
  }
}

/// 站点帖子页链接：分享、跳转详情、打开浏览器共用。
///
/// 此前这四处各写一遍 `post.postUrl ?? post.originalUrl`。解析器统一
/// 以 null 表示「站点没给链接」，但这里仍做 isNotEmpty 兜底——历史记录
/// 来自 JSON 反序列化，任何一环给出空串都不该把空地址分享出去。
String permalinkOf(PostSummary post) {
  final url = post.postUrl;
  if (url != null && url.isNotEmpty) return url;
  return post.originalUrl;
}

/// 视频判定。取 original / sample 两者中任一命中即算视频：
/// 有些站点 original 是 mp4 而 sample 是图，反之亦然。
///
/// 此前存在三套实现且口径不一：瀑布流只看 original、详情页只看
/// sample 优先的 mediaUrl —— 同一个帖子在列表显示视频角标、点进去却
/// 按图片渲染。这里取并集，是三者中最宽松也最不易误判的口径。
/// 视频判定。
///
/// 先看解析器给的 [PostSummary.isVideo] 显式标记（视频站必须走这条：
/// 列表页里根本没有视频地址），再看 original / sample 的 URL 后缀——
/// 图片站把 mp4 直接放在 original 里，靠后缀就能认出来。
///
/// 此前只看 URL，于是视频站的帖子被判成图片帖，点开只渲染一张缩略图。
bool isVideoPost(PostSummary post) =>
    post.isVideo || _isVideoUrl(post.originalUrl) || _isVideoUrl(post.sampleUrl);

/// 单个 URL 的视频判定。
///
/// 扩展名判定之外额外覆盖三类站点惯例：路径含 `/video/` 的直链、
/// sample 目录下的 mp4（部分站点把视频抽帧图放在同目录），
/// 以及 **HLS / DASH 流**（`.m3u8` / `.mpd`）——视频站（KVS 家族等）
/// 往往只给流清单，不认这两个扩展名就会把视频帖丢给图片组件渲染，
/// 表现是永远加载中的破图。
bool isVideoUrl(String url) => _isVideoUrl(url);

bool _isVideoUrl(String url) {
  if (url.isEmpty) return false;
  // 先剥掉 query / fragment：图站与视频站普遍用 `?token=` 之类做防盗链，
  // 不剥掉的话 `clip.mp4?token=1` 的 endsWith 判定必然落空。
  final bare = url.split('?').first.split('#').first.toLowerCase();
  return bare.endsWith('.mp4') ||
      bare.endsWith('.webm') ||
      bare.endsWith('.m3u8') ||
      bare.endsWith('.mpd') ||
      bare.contains('/video/') ||
      (bare.contains('/sample/') && bare.contains('.mp4'));
}

abstract class BooruRepository {
  /// 站点标识，用于跨站点缓存隔离。
  String get serverId;

  Future<BooruPageResult> searchPosts(BooruQuery query);
  Future<List<String>> suggestTags(String query, {int limit = 10});
  Future<List<String>> fetchTrendingTags({int limit = 20}) async => [];
  Future<List<BooruPool>> fetchPools({int page = 1, int limit = 20}) async =>
      [];

  /// 按需解析帖子的**媒体地址**（原图 / 播放直链）。
  ///
  /// 两类站点需要它：
  /// - 视频站（KVS 家族等）：列表页只有缩略图，mp4/HLS 地址藏在详情页的
  ///   播放器配置里；
  /// - paheal 系图站：列表页给的是无扩展名的缩略图，原图只在详情页的
  ///   `og:image` 里。
  /// 图片站无需实现，默认返回 null（调用方据此继续用帖子自带的 URL）。
  Future<String?> resolveMediaUrl(String postUrl) async => null;

  /// 播放/取原图时附带的请求头。
  ///
  /// 视频站的 CDN（KVS 的 `/get_file/` 等）普遍校验 UA 与 Referer：
  /// 播放器若用应用自己的 UA 去取，会拿到 403 或一段 HTML 错误页，
  /// 表现就是"地址解析出来了却播不了"。图片站返回空即可。
  Map<String, String> get mediaHeaders => const {};
}
