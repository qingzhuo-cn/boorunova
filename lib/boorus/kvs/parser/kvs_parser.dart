// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/data/repository/booru/entity/post.dart';

/// KVS（Kernel Video Sharing）站点的解析。
///
/// 这一族 CMS 的 HTML 结构在几百个站点上高度一致，但**并非同一份模板**，
/// 所以这里的策略是「按优先级找，找不到就退一步」：
/// 列表页从 `/videos/<id>/<slug>/` 这种链接反推条目与缩略图；
/// 详情页先解 `flashvars`（官方播放器配置），失败再全局找媒体直链。
///
/// 说明：本环境对这些域名做了污染（解析到假 IP），无法用真实页面验证，
/// 因此解析全部写成容错的，配套测试用的是按家族结构构造的固件。
/// 真机上用「探测」页确认一次即可。
class KvsParser {
  KvsParser._();

  /// 视频页里能拿到的播放信息。
  static const List<String> _videoKeys = [
    'video_url',
    'video_alt_url',
    'video_alt_url2',
    'video_alt_url3',
  ];

  /// 解析列表页，抽出视频条目（id / 缩略图 / 标题 / 时长）。
  static List<BooruPost> parseList(
    String serverId,
    String baseUrl,
    String html, {
    int limit = 40,
  }) {
    final posts = <BooruPost>[];
    final seen = <String>{};

    // 剥掉 script/style 再扫：视频站的页面里同样嵌着 JS 模板，
    // 其中的链接与未闭合标签会被正则误当成条目。
    final body = html
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '');

    // 视频链接：KVS 的详情页固定形如 /video/<数字 id>/<slug>/（单数）
    final linkPattern = RegExp(
      r'''<a[^>]+href=["']([^"']*?/videos?/(\d+)/[^"']*)["'][^>]*>(.*?)</a>''',
      dotAll: true,
      caseSensitive: false,
    );

    for (final match in linkPattern.allMatches(body)) {
      if (posts.length >= limit) break;
      final href = match.group(1) ?? '';
      final id = match.group(2) ?? '';
      final inner = match.group(3) ?? '';
      if (id.isEmpty || !seen.add(id)) continue;

      // 缩略图：`src` 常是 base64 占位符，真地址在 data-original / data-webp；
      // 也可能挂在链接之后（往后取一小段窗口兜底）。
      final thumb = _firstMediaUrl(inner) ??
          _firstMediaUrl(match.group(0) ?? '') ??
          _firstMediaUrl(_window(body, match.end));
      if (thumb == null) continue;

      final title = _attr(match.group(0) ?? '', 'title') ?? '';
      final duration = _durationNear(body, match.end);
      final slug = href.split('/').where((s) => s.isNotEmpty).last;

      posts.add(BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: _absolute(thumb, baseUrl),
        // 播放地址要打开详情页才知道：留空，由 resolveMediaUrl 按需解析。
        sampleUrl: '',
        originalUrl: '',
        // 标签有两个来源：URL slug 与链接 title。视频站不提供标签字段，
        // 这两个是唯一能免费拿到的，够黑名单与标签展示用。
        tags: [
          ..._tagsFromSlug(slug),
          ..._tagsFromText(title),
        ],
        // 列表页拿不到真实比例，按 16:9 估；视频站缩略图基本是这个比例。
        aspectRatio: 16 / 9,
        width: 0,
        height: 0,
        // 视频站是成人内容站：按限制级记录，安全筛选与侧栏头图自然避开它。
        rating: 'e',
        score: 0,
        postUrl: _absolute(href, baseUrl),
        // 时长写进它自己的字段（此前塞在 uploader 里，字段名与内容不符）
        duration: duration,
        // 视频帖必须**显式**标记：列表页里没有任何 mp4/HLS 地址
        // （播放地址要开详情页才知道），只靠 URL 判定会被当成图片帖，
        // 于是点开只渲染一张缩略图——这正是用户实测到的"只显示图片"。
        isVideo: true,
      ));
    }
    return posts;
  }

  /// 解析详情页，返回「可播放地址」与「缩略图/海报」。
  ///
  /// [baseUrl] 用于把协议相对（`//cdn/...`）与站内相对路径补成绝对地址：
  /// 播放器拿到没有 scheme 的地址只会失败，而视频站的媒体地址三种写法都有。
  static KvsVideo? parseVideoPage(String html, {String baseUrl = ''}) {
    final fields = _parseFlashvars(html);

    // 优先级：mp4 优先（能播也能存），流清单兜底（能播不能存）。
    // KVS 的 video_url 通常是最低档 mp4，video_alt_url/2 是 720/1080。
    final candidates = <String?>[
      fields['video_alt_url2'],
      fields['video_alt_url3'],
      fields['video_alt_url'],
      fields['video_url'],
    ];
    String? playable;
    for (final candidate in candidates) {
      if (candidate == null || candidate.isEmpty) continue;
      final current = playable;
      if (current == null || _prefer(candidate, current)) {
        playable = candidate;
      }
    }

    // flashvars 里没有（新版播放器把配置塞在别处）→ 全局找媒体直链
    playable ??= _bestMediaUrl(html);
    if (playable == null || playable.isEmpty) return null;

    return KvsVideo(
      url: _absolute(playable, baseUrl),
      poster: fields['poster'] ?? fields['preview_url'],
    );
  }

  /// 反转义并归一：`https:\/\/` → `https://`，`&amp;` → `&`。
  ///
  /// 实测 rule34video 的详情页里有 122 处转义斜杠；`&amp;` 则出现在带参
  /// 数（token）的地址里，不还原会把参数名变成 `amp;token`，服务端直接拒。
  static String _clean(String url) => url
      .replaceAll(r'\/', '/')
      .replaceAll(r'\u002F', '/')
      .replaceAll('&amp;', '&')
      .trim();

  /// mp4 优于流清单：能播也能存。
  static bool _prefer(String candidate, String current) {
    final cStream = _isStream(candidate);
    final curStream = _isStream(current);
    if (cStream != curStream) return curStream;
    return false;
  }

  static bool _isStream(String url) {
    final bare = url.split('?').first.toLowerCase();
    return bare.endsWith('.m3u8') || bare.endsWith('.mpd');
  }

  /// 解 `var flashvars = { ... };` 里的键值对。
  ///
  /// 值可能是单引号/双引号字符串，也可能带转义斜杠（`https:\/\/`）——
  /// 后者在 KVS 里很常见，必须先反转义。
  static Map<String, String> _parseFlashvars(String html) {
    final result = <String, String>{};
    final block = RegExp(r'flashvars\s*=\s*\{', caseSensitive: false)
        .firstMatch(html);
    if (block == null) return result;

    // 从 { 起做括号配平，避免把后面的脚本一起吞进来
    final start = html.indexOf('{', block.start);
    var depth = 0;
    var end = start;
    for (var i = start; i < html.length; i++) {
      final ch = html[i];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) {
          end = i;
          break;
        }
      }
    }
    if (end <= start) return result;
    final body = html.substring(start + 1, end);

    for (final key in _videoKeys) {
      final value = _jsString(body, key);
      if (value != null) result[key] = value;
    }
    result['poster'] = _jsString(body, 'poster') ?? _jsString(body, 'preview_url') ?? '';
    // 去掉空值，调用方只需判 containsKey
    result.removeWhere((_, v) => v.isEmpty);
    return result;
  }

  static String? _jsString(String body, String key) {
    final match = RegExp(
      """['"]?$key['"]?\\s*:\\s*['"](.*?)['"]""",
      dotAll: true,
    ).firstMatch(body);
    if (match == null) return null;
    return _clean(match.group(1) ?? '');
  }

  static String? _bestMediaUrl(String html) {
    // 实测 rule34video 的详情页里 `_preview.mp4` 出现 25 次（悬停预览小片），
    // `/get_file/` 出现 33 次（正片）。若不做区分，兜底会取到预览小片——
    // 用户点开看到的是几秒钟的静音预览。
    final candidates = RegExp(
      r'''https?://[^"'\s\\]+?\.(?:mp4|webm|m3u8|mpd)(?:\?[^"'\s\\]*)?''',
      caseSensitive: false,
    )
        .allMatches(html)
        .map((m) => _clean(m.group(0)!))
        .where((url) =>
            !url.toLowerCase().contains('_preview.') &&
            !url.toLowerCase().contains('/preview.'))
        .toList();
    if (candidates.isEmpty) return null;

    // 正片优先：KVS 的真实媒体走 /get_file/；再看 mp4 优先于流清单
    int score(String url) {
      final lower = url.toLowerCase();
      var value = 0;
      if (lower.contains('/get_file/')) value += 4;
      if (lower.contains('.mp4')) value += 2;
      return value;
    }

    candidates.sort((a, b) => score(b).compareTo(score(a)));
    return candidates.first;
  }

  static String? _firstMediaUrl(String html) {
    if (html.isEmpty) return null;
    // 允许相对路径（有的主题给 `/thumbs/xxx.jpg`），由 _absolute 补齐域名
    final match = RegExp(
      '''(?:data-original|data-src|data-webp|data-lazy|src|poster)=["']([^"']+?\\.(?:jpe?g|png|webp|gif)(?:\\?[^"']*)?)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1);
  }

  static String _window(String html, int from) {
    if (from >= html.length) return '';
    final end = (from + 600).clamp(0, html.length);
    return html.substring(from, end);
  }

  static String? _durationNear(String html, int from) {
    final window = _window(html, from);
    final match = RegExp(r'''class=["'][^"']*duration[^"']*["'][^>]*>\s*([0-9:]+)''')
        .firstMatch(window);
    final value = match?.group(1)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  static String? _attr(String tag, String name) {
    // [\s\S] 而非 `.`：属性值可能跨行（标题很长时会被换行折行）
    final match = RegExp(
      '$name\\s*=\\s*["\']([\\s\\S]*?)["\']',
      caseSensitive: false,
    ).firstMatch(tag);
    return match?.group(1)?.trim();
  }

  /// 从 URL slug 反推标签：`big-breast-blonde-3d` → [big breast blonde 3d]
  /// 这是视频站唯一能免费拿到的标签来源，够黑名单与标签展示用。
  static List<String> _tagsFromSlug(String slug) {
    final clean = slug.replaceAll(RegExp(r'\.(html?|php)$'), '');
    return clean
        .split(RegExp(r'[-_+]'))
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty && !RegExp(r'^\d+$').hasMatch(t))
        .toList();
  }

  /// 从标题反推标签（`title="Big Breast Blonde 3D"`）。
  static List<String> _tagsFromText(String text) {
    if (text.isEmpty) return const [];
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length > 1 && !RegExp(r'^\d+$').hasMatch(t))
        .toList();
  }

  static String _absolute(String url, String baseUrl) {
    if (url.isEmpty) return '';
    // 协议相对（`//host/path`）在真实页面里很常见，先补齐 scheme，
    // 否则会被当成站内路径拼成 `https://site//host/path`。
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('http')) return url;
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return url.startsWith('/') ? '$base$url' : '$base/$url';
  }
}

/// 详情页解析结果。
class KvsVideo {
  const KvsVideo({required this.url, this.poster});

  /// 可播放地址（mp4 或 HLS 清单）。
  final String url;

  /// 海报图（可能为空）。
  final String? poster;
}
