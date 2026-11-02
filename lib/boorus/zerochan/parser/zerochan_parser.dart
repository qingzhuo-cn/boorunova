// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/json_coerce.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';

class ZerochanParser {
  ZerochanParser._();

  static List<BooruPost> parsePosts(
    String serverId,
    Map<String, dynamic> json, {
    String baseUrl = kZerochanBaseUrl,
  }) {
    return parseEach(asMapList(json['items']), (post) {
      final id = asStr(post['id']);
      final file = asStr(post['file']);
      final thumbnail = asStr(post['thumbnail']);
      final width = asInt(post['width']);
      final height = asInt(post['height']);
      final tags = asStrList(post['tags']);
      final author = asStr(post['author']);
      final source = asStr(post['source']);
      // zerochan 是 ecchi 向站，站上并非全部安全：此前硬编码 's'（安全）
      // 会把擦边内容标成绿徽章并通过头图的安全口径。无法判定按可疑处理，
      // 与 shimmie2 的口径一致。
      const rating = 'q';

      return BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: thumbnail,
        sampleUrl: file,
        originalUrl: file,
        tags: tags,
        aspectRatio: height > 0 ? width / height : 1.0,
        width: width,
        height: height,
        rating: rating,
        score: 0,
        source: asStrOrNull(source),
        postUrl: id.isEmpty ? null : '$baseUrl/$id',
        uploader: asStrOrNull(author),
      );
    });
  }
}
