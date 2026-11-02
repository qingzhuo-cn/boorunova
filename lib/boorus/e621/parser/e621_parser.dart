// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/json_coerce.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';

class E621Parser {
  E621Parser._();

  static List<BooruPost> parsePosts(
    String serverId,
    List<dynamic> json, {
    String baseUrl = kE621BaseUrl,
  }) {
    return parseEach(json, (post) {
      final id = asStr(post['id']);
      // 嵌套字段可能是畸形类型（如字符串），宽容取值后不会再抛
      final file = asMap(post['file']);
      final sample = asMap(post['sample']);
      final preview = asMap(post['preview']);
      final tagsMap = asMap(post['tags']);

      final fileUrl = asStr(file['url']);
      final sampleUrl = asStr(sample['url']);
      final previewUrl = asStr(preview['url']);
      final width = asInt(file['width']);
      final height = asInt(file['height']);

      final tagGeneral = asStrList(tagsMap['general']);
      final tagArtist = asStrList(tagsMap['artist']);
      final tagCharacter = asStrList(tagsMap['character']);
      final tagCopyright = asStrList(tagsMap['copyright']);
      final tagMeta = asStrList(tagsMap['meta']);
      final tagSpecies = asStrList(tagsMap['species']);
      final tagLore = asStrList(tagsMap['lore']);

      final allTags = [
        ...tagGeneral,
        ...tagArtist,
        ...tagCharacter,
        ...tagCopyright,
        ...tagMeta,
        ...tagSpecies,
        ...tagLore,
      ];

      // 四档归一：e621 同样是 g/s/q/e，s=sensitive 并入 q。
      final rating =
          normalizeRatingFourTier(asStr(post['rating'], fallback: 'q'));
      final score = asInt(asMap(post['score'])['total']);
      final sources = asStrList(post['sources']);
      final source = sources.isNotEmpty ? sources.first : '';

      return BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: previewUrl,
        sampleUrl: sampleUrl,
        originalUrl: fileUrl,
        tags: allTags,
        tagGeneral: [...tagGeneral, ...tagSpecies, ...tagLore],
        tagArtist: tagArtist,
        tagCharacter: tagCharacter,
        tagCopyright: tagCopyright,
        tagMeta: tagMeta,
        aspectRatio: height > 0 ? width / height : 1.0,
        width: width,
        height: height,
        rating: rating,
        score: score,
        source: asStrOrNull(source),
        postUrl: id.isEmpty ? null : '$baseUrl/posts/$id',
      );
    });
  }
}
