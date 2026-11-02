// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/json_coerce.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';

/// Shimmie2 / paheal 系图站的解析。
///
/// 真实页面（rule34.paheal.net，实测 2026-10）的三处关键形态：
/// 1. 属性用**单引号**（`id='thumb_...'`），双引号正则一条都匹配不到；
/// 2. 缩略图 `src` 是**无扩展名**的哈希路径（`/1a/2b/<hash>`），
///    靠「必须带 .jpg」过滤会把整页都丢掉；
/// 3. 详情页的原图只出现在 `<meta property="og:image">`（同样是相对、
///    无扩展名路径），页面里没有 `<img id="image">`。
///
/// 所以判定规则是「不是显而易见的站点资源就当媒体」，而不是「必须是图片后缀」。
class Shimmie2Parser {
  Shimmie2Parser._();

  /// 站点资源特征：命中这些一律不当缩略图。
  ///
  /// 实测 paheal 的图库页里带扩展名的 img 只有 3 个，全是 logo / 统计像素。
  static final RegExp _assetPattern = RegExp(
    r'themes/|/gtag/|amung\.us|apple-touch-icon|gravatar|/static/|\.css|\.js|\.ico|^data:',
    caseSensitive: false,
  );

  /// JSON 接口：顶层可能是数组，也可能包一层（`{"posts": [...]}`）。
  static List<BooruPost> parseJson(String serverId, Object? decoded) {
    final raw = decoded is Map
        ? (decoded['posts'] ?? decoded['post'] ?? decoded['data'])
        : decoded;
    if (raw is! List) return const [];

    final posts = <BooruPost>[];
    for (final item in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final id = map['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      final file = asStrOrNull(map['file']) ?? asStrOrNull(map['image']) ?? '';
      final preview = asStrOrNull(map['preview']) ?? asStrOrNull(map['thumbnail']) ?? '';
      final sample = asStrOrNull(map['sample']) ?? '';
      // 没有任何可用媒体地址的条目直接跳过：放进去只会渲染成一张破图。
      if (file.isEmpty && preview.isEmpty) continue;

      final width = asIntOrNull(map['width']);
      final height = asIntOrNull(map['height']);
      final tagList = map['tags'];
      final tags = tagList is List
          ? tagList.whereType<String>().toList()
          : (tagList is String
              ? tagList.split(' ').where((t) => t.isNotEmpty).toList()
              : <String>[]);

      posts.add(BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: preview.isNotEmpty ? preview : file,
        sampleUrl: sample,
        originalUrl: file,
        tags: tags,
        aspectRatio: (width != null && height != null && height > 0)
            ? width / height
            : 1.0,
        width: width ?? 0,
        height: height ?? 0,
        rating: normalizeRating(asStrOrNull(map['rating'])),
        score: asIntOrNull(map['score']) ?? 0,
        source: asStrOrNull(map['source']),
        postUrl: asStrOrNull(map['post_url']),
      ));
    }
    return posts;
  }

  /// 图库 HTML：从 `/post/view/<id>` 链接反推条目。
  static List<BooruPost> parseList(
    String serverId,
    String baseUrl,
    String html, {
    int limit = 40,
  }) {
    final posts = <BooruPost>[];
    final seen = <String>{};

    // 必须先剥掉 script/style：实测 paheal 的页面里嵌着 JS 模板，
    // 其中同样含 `/post/view/<id>` 与未闭合的 `<img`。不剥的话正则会把
    // 模板片段当成条目（真页面回放时正是这样：40 条全配上了模板里的图）。
    final body = _stripScripts(html);

    final linkPattern = RegExp(
      r'''<a[^>]+href=["']([^"']*?/post/view/(\d+)[^"']*)["'][^>]*>(.*?)</a>''',
      dotAll: true,
      caseSensitive: false,
    );

    for (final match in linkPattern.allMatches(body)) {
      if (posts.length >= limit) break;
      final id = match.group(2) ?? '';
      if (id.isEmpty || !seen.add(id)) continue;

      final linkTag = match.group(0) ?? '';
      final inner = match.group(3) ?? '';

      // 精确配对：缩略图的 id 是 `thumb_<postId>`（实测）。只认这一种，
      // 不再"取片段里第一个像图片的东西"——那会把邻帖的图配过来。
      final thumbTag = _thumbTagIn(inner, id) ??
          _thumbTagIn(linkTag, id) ??
          _thumbTagInWindow(body, match.end, id);
      if (thumbTag == null) continue;

      final thumb = _firstMediaUrl(thumbTag);
      if (thumb == null) continue;

      // 标签来源：缩略图自己的 title（实测就是标签串），其次 alt。
      final tagSource = _attr(thumbTag, 'title') ?? '';
      final alt = _attr(thumbTag, 'alt') ?? '';
      posts.add(BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: _absolute(thumb, baseUrl),
        // 原图要进详情页才知道（og:image），列表页只有缩略图
        sampleUrl: '',
        originalUrl: '',
        tags: _tagsFrom(tagSource.isEmpty ? alt : tagSource),
        aspectRatio: 1.0,
        width: 0,
        height: 0,
        // paheal 系没有分级字段：按可疑记录，安全筛选不会把它当成安全图
        rating: 'q',
        score: 0,
        postUrl: _absolute('/post/view/$id', baseUrl),
      ));
    }
    return posts;
  }

  /// 去掉 script / style 内容（HTML 扫描的标准前置步骤）。
  static String _stripScripts(String html) => html
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '');

  /// 在片段里找「id 为 thumb_<postId>（或 thumb_rand_<postId>）的 img」。
  static String? _thumbTagIn(String html, String postId) {
    if (html.isEmpty) return null;
    final match = RegExp(
      '''<img[^>]*id=["']thumb_(?:rand_)?$postId["'][^>]*>''',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(0);
  }

  /// 在锚点之后的一小段窗口里按 id 找缩略图（有的主题把 img 放在链接之外）。
  /// 仍然只认 id 精确命中，否则宁可不收这条。
  static String? _thumbTagInWindow(String html, int from, String postId) {
    if (from >= html.length) return null;
    final window = html.substring(from, (from + 600).clamp(0, html.length));
    return _thumbTagIn(window, postId);
  }

  /// 详情页原图：只认 `og:image`（实测页面上没有别的原图入口）。
  static String? parsePostImage(String html, String baseUrl) {
    final match = RegExp(
      r'''<meta[^>]*property=["']og:image["'][^>]*>''',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) return null;
    final content = _attr(match.group(0) ?? '', 'content');
    if (content == null || content.isEmpty) return null;
    if (_assetPattern.hasMatch(content)) return null;
    return _absolute(content, baseUrl);
  }

  /// 取第一个「像媒体」的地址。
  ///
  /// 与 KVS 不同，这里**不要求**图片后缀（实测缩略图是无扩展名的哈希路径），
  /// 只排除站点资源与 data URI。相对路径与协议相对都由 [_absolute] 归一。
  static String? _firstMediaUrl(String html) {
    if (html.isEmpty) return null;
    final matches = RegExp(
      '''(?:data-original|data-src|data-lazy|src|poster)=["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html);
    for (final match in matches) {
      final url = match.group(1)?.trim() ?? '';
      if (url.isEmpty) continue;
      if (_assetPattern.hasMatch(url)) continue;
      return url;
    }
    return null;
  }

  static List<String> _tagsFrom(String source) {
    if (source.trim().isEmpty) return const [];
    return source
        .split(RegExp(r'[\s,]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static String? _attr(String tag, String name) {
    // 必须用 [\s\S] 而不是 `.`：实测 paheal 的 title 值会跨行（标签串很长），
    // 默认的 `.` 不匹配换行，会让整个属性匹配失败——表现为"缩略图对但标签空"。
    final match = RegExp(
      '$name\\s*=\\s*["\']([\\s\\S]*?)["\']',
      caseSensitive: false,
    ).firstMatch(tag);
    return match?.group(1)?.trim();
  }

  static String _absolute(String url, String baseUrl) {
    if (url.isEmpty) return '';
    // 协议相对（`//host/path`）在实测页面里很常见
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('http')) return url;
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return url.startsWith('/') ? '$base$url' : '$base/$url';
  }
}
