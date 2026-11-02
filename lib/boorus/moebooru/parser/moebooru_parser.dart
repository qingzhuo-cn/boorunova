// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/json_coerce.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';

class MoebooruParser {
  MoebooruParser._();

  /// 补全媒体 URL。
  ///
  /// `http://` **原样保留**：此前一律强升 `https://`，http-only 的实例
  /// （自建 moebooru 很常见）图片会全部挂掉。`//`（协议相对）才按站点
  /// 自身的 scheme 补全。
  static String _abs(String url, String siteUrl) {
    if (url.isEmpty) return url;
    if (url.startsWith('//')) {
      return siteUrl.startsWith('http://') ? 'http:$url' : 'https:$url';
    }
    return url;
  }

  static List<BooruPost> parsePosts(
    String serverId,
    List<dynamic> json, {
    String siteUrl = kMoebooruBaseUrl,
  }) {
    return parseEach(json, (post) {
      final id = asStr(post['id']);
      var fileUrl = _abs(asStr(post['file_url']), siteUrl);
      var sampleUrl = _abs(asStr(post['sample_url']), siteUrl);
      final previewUrl = _abs(asStr(post['preview_url']), siteUrl);
      final jpegUrl = _abs(asStr(post['jpeg_url']), siteUrl);
      final tags = asStr(post['tags']);
      final width = asInt(post['width']);
      final height = asInt(post['height']);
      final rating = asStr(post['rating'], fallback: 'q');
      final score = asInt(post['score']);
      final source = asStr(post['source']);
      final author = asStr(post['author']);

      // 部分帖子 file_url 缺失（如删除的帖子），用 jpeg/sample 兜底
      if (fileUrl.isEmpty) fileUrl = jpegUrl.isNotEmpty ? jpegUrl : sampleUrl;
      if (sampleUrl.isEmpty) sampleUrl = jpegUrl.isNotEmpty ? jpegUrl : fileUrl;

      return BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: previewUrl,
        sampleUrl: sampleUrl,
        originalUrl: fileUrl,
        tags: tags.isEmpty ? const [] : tags.split(' '),
        aspectRatio: height > 0 ? width / height : 1.0,
        width: width,
        height: height,
        rating: rating,
        score: score,
        source: asStrOrNull(source),
        postUrl: id.isEmpty ? null : '$siteUrl/post/show/$id',
        uploader: asStrOrNull(author),
      );
    });
  }

  static List<String> parseSuggestions(List<dynamic> json) {
    return json.whereType<Map<String, dynamic>>().map((tag) {
      return asStr(tag['name']);
    }).where((name) => name.isNotEmpty).toList();
  }
}
