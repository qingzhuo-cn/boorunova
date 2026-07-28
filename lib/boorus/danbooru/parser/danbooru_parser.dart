import 'package:boorunova/data/repository/booru/entity/post.dart';

class DanbooruParser {
  DanbooruParser._();

  static const String searchEndpoint = '/posts.json';
  static const String suggestEndpoint = '/tags.json';

  static String _normalize(String url, String baseUrl) {
    return url.startsWith('http') ? url : '$baseUrl$url';
  }

  static List<BooruPost> parsePosts(
    String serverId,
    String baseUrl,
    List<dynamic> json,
  ) {
    return json.whereType<Map<String, dynamic>>().map((post) {
      final id = post['id']?.toString() ?? '';
      final fileUrl = (post['file_url'] as String?) ?? '';
      final largeUrl = (post['large_file_url'] as String?) ?? '';
      final previewUrl = (post['preview_file_url'] as String?) ?? '';
      final width = (post['image_width'] as int?) ?? 0;
      final height = (post['image_height'] as int?) ?? 0;
      final tagString = (post['tag_string'] as String?) ?? '';
      final tagGeneral = (post['tag_string_general'] as String?) ?? '';
      final tagArtist = (post['tag_string_artist'] as String?) ?? '';
      final tagCharacter = (post['tag_string_character'] as String?) ?? '';
      final tagCopyright = (post['tag_string_copyright'] as String?) ?? '';
      final tagMeta = (post['tag_string_meta'] as String?) ?? '';
      final rating = (post['rating'] as String?) ?? 'q';
      final score = (post['score'] as int?) ?? 0;
      final source = (post['source'] as String?) ?? '';
      final uploader = (post['uploader_name'] as String?) ?? '';

      return BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: _normalize(previewUrl, baseUrl),
        sampleUrl: _normalize(largeUrl, baseUrl),
        originalUrl: _normalize(fileUrl, baseUrl),
        tags: tagString.isEmpty ? [] : tagString.split(' '),
        tagGeneral: _tagList(tagGeneral),
        tagArtist: _tagList(tagArtist),
        tagCharacter: _tagList(tagCharacter),
        tagCopyright: _tagList(tagCopyright),
        tagMeta: _tagList(tagMeta),
        aspectRatio: height > 0 ? width / height : 1.0,
        width: width,
        height: height,
        rating: rating,
        score: score,
        source: source.isEmpty ? null : source,
        postUrl: '$baseUrl/posts/$id',
        uploader: uploader.isEmpty ? null : uploader,
      );
    }).toList();
  }

  static List<String> _tagList(String input) =>
      input.isEmpty ? [] : input.split(' ');

  static List<String> parseSuggestions(List<dynamic> json) {
    return json.whereType<Map<String, dynamic>>().map((tag) {
      return (tag['name'] as String?) ?? '';
    }).where((name) => name.isNotEmpty).toList();
  }
}
