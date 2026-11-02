// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/json_coerce.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';

class DanbooruParser {
  DanbooruParser._();

  static const String searchEndpoint = '/posts.json';
  static const String suggestEndpoint = '/tags.json';

  /// 相对路径补成绝对 URL。
  ///
  /// 空串必须原样返回空串：此前 `url.startsWith('http') ? url : '$baseUrl$url'`
  /// 会把「站点没给这个 URL」（banned/deleted/无文件帖）拼成站点首页——
  /// 于是缩略图和原图都变成一张 HTML 首页，下载下来是网页。
  static String _normalize(String url, String baseUrl) {
    if (url.isEmpty) return '';
    return url.startsWith('http') ? url : '$baseUrl$url';
  }

  static List<BooruPost> parsePosts(
    String serverId,
    String baseUrl,
    List<dynamic> json,
  ) {
    // 逐条 try/catch 丢条保页 + 宽容取值：单条 score=3.5 不该让整页搜索失败。
    return parseEach(json, (post) {
      final id = asStr(post['id']);
      final fileUrl = asStr(post['file_url']);
      final largeUrl = asStr(post['large_file_url']);
      final previewUrl = asStr(post['preview_file_url']);
      final width = asInt(post['image_width']);
      final height = asInt(post['image_height']);
      final tagString = asStr(post['tag_string']);
      final tagGeneral = asStr(post['tag_string_general']);
      final tagArtist = asStr(post['tag_string_artist']);
      final tagCharacter = asStr(post['tag_string_character']);
      final tagCopyright = asStr(post['tag_string_copyright']);
      final tagMeta = asStr(post['tag_string_meta']);
      // 四档归一：s=sensitive 并入 q，g=general 才是 UI 的「安全」。
      final rating = normalizeRatingFourTier(asStr(post['rating']));
      final score = asInt(post['score']);
      final source = asStr(post['source']);
      final uploader = asStr(post['uploader_name']);

      return BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: _normalize(previewUrl, baseUrl),
        sampleUrl: _normalize(largeUrl, baseUrl),
        originalUrl: _normalize(fileUrl, baseUrl),
        tags: _split(tagString),
        tagGeneral: _split(tagGeneral),
        tagArtist: _split(tagArtist),
        tagCharacter: _split(tagCharacter),
        tagCopyright: _split(tagCopyright),
        tagMeta: _split(tagMeta),
        aspectRatio: height > 0 ? width / height : 1.0,
        width: width,
        height: height,
        rating: rating,
        score: score,
        source: asStrOrNull(source),
        postUrl: '$baseUrl/posts/$id',
        uploader: asStrOrNull(uploader),
      );
    });
  }

  /// danbooru 的标签在一个空格分隔的字符串里。
  static List<String> _split(String input) =>
      input.isEmpty ? const [] : input.split(' ');

  static List<String> parseSuggestions(List<dynamic> json) {
    return json.whereType<Map<String, dynamic>>().map((tag) {
      return asStr(tag['name']);
    }).where((name) => name.isNotEmpty).toList();
  }
}
