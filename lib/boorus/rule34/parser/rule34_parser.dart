// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/json_coerce.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';

class Rule34Parser {
  Rule34Parser._();

  /// 缺省站点域名。仓库会把自己配置的 baseUrl 传进来：
  /// 同引擎的镜像站（rule34.us 等）此前帖子链接一律硬编码指向 rule34.xxx。
  static const String defaultSiteUrl = kRule34SiteUrl;

  static String _abs(String url) {
    if (url.startsWith('//')) return 'https:$url';
    return url;
  }

  static List<BooruPost> parsePosts(
    String serverId,
    List<dynamic> json, {
    String siteUrl = defaultSiteUrl,
  }) {
    // 站点的 web 域名以 hxxp 之外的协议给出时，帖子链接同样要能用
    final base = siteUrl.endsWith('/')
        ? siteUrl.substring(0, siteUrl.length - 1)
        : siteUrl;
    return parseEach(json, (post) {
      final id = asStr(post['id']);
      final fileUrl = _abs(asStr(post['file_url']));
      var sampleUrl = _abs(asStr(post['sample_url']));
      final previewUrl = _abs(asStr(post['preview_url']));
      final tags = asStr(post['tags']);
      final width = asInt(post['width']);
      final height = asInt(post['height']);
      final rating = _normalizeRating(asStr(post['rating']));
      final score = asInt(post['score']);
      final source = _abs(asStr(post['source']));

      if (sampleUrl.isEmpty) sampleUrl = fileUrl;

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
        postUrl:
            id.isEmpty ? null : '$base/index.php?page=post&s=view&id=$id',
        uploader: null,
      );
    });
  }

  static List<String> parseSuggestions(List<dynamic> json) {
    return json.whereType<Map<String, dynamic>>().map((tag) {
      return asStr(tag['tag']);
    }).where((name) => name.isNotEmpty).toList();
  }

  /// 评级归一交给共享实现：此前这里的未知值落到 `e`（限制级），
  /// 字段缺失或站点新增枚举都会被当成限制级，安全筛选与头图判定随之出错。
  static String _normalizeRating(String rating) => normalizeRating(rating);
}
