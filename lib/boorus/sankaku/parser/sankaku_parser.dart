import 'package:boorunova/data/repository/booru/entity/post.dart';

class SankakuParser {
  SankakuParser._();

  static List<BooruPost> parsePosts(
    String serverId,
    List<dynamic> json,
  ) {
    return json.whereType<Map<String, dynamic>>().map((post) {
      final id = post['id']?.toString() ?? '';
      final fileUrl = (post['file_url'] as String?) ?? '';
      final sampleUrl = (post['sample_url'] as String?) ?? '';
      final previewUrl = (post['preview_url'] as String?) ?? '';
      final tags = (post['tags'] as String?) ?? '';
      final width = (post['width'] as int?) ?? 0;
      final height = (post['height'] as int?) ?? 0;
      final rating = (post['rating'] as String?) ?? 'q';
      final score = (post['score'] as int?) ?? 0;
      final source = (post['source'] as String?) ?? '';
      final author = (post['author'] as String?) ?? '';
      final jpegUrl = (post['jpeg_url'] as String?) ?? '';

      return BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: previewUrl,
        sampleUrl: jpegUrl.isNotEmpty ? jpegUrl : sampleUrl,
        originalUrl: fileUrl,
        tags: tags.isEmpty ? [] : tags.split(' '),
        aspectRatio: height > 0 ? width / height : 1.0,
        width: width,
        height: height,
        rating: rating,
        score: score,
        source: source.isEmpty ? null : source,
        postUrl: id,
        uploader: author.isEmpty ? null : author,
      );
    }).toList();
  }

  static List<String> parseSuggestions(List<dynamic> json) {
    return json.whereType<Map<String, dynamic>>().map((tag) {
      return (tag['name'] as String?) ?? '';
    }).where((name) => name.isNotEmpty).toList();
  }
}
