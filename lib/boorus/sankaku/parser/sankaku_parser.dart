// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/json_coerce.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';

class SankakuParser {
  SankakuParser._();

  static List<BooruPost> parsePosts(
    String serverId,
    List<dynamic> json, {
    String baseUrl = kSankakuBaseUrl,
  }) {
    return parseEach(json, (post) {
      final id = asStr(post['id']);
      final fileUrl = asStr(post['file_url']);
      final sampleUrl = asStr(post['sample_url']);
      final previewUrl = asStr(post['preview_url']);
      final tags = asStr(post['tags']);
      final width = asInt(post['width']);
      final height = asInt(post['height']);
      final rating = asStr(post['rating'], fallback: 'q');
      final score = asInt(post['score']);
      final source = asStr(post['source']);
      final author = asStr(post['author']);
      final jpegUrl = asStr(post['jpeg_url']);

      return BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: previewUrl,
        sampleUrl: jpegUrl.isNotEmpty ? jpegUrl : sampleUrl,
        originalUrl: fileUrl,
        tags: tags.isEmpty ? const [] : tags.split(' '),
        aspectRatio: height > 0 ? width / height : 1.0,
        width: width,
        height: height,
        rating: rating,
        score: score,
        source: asStrOrNull(source),
        postUrl: id.isEmpty ? null : '$baseUrl/post/show/$id',
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
