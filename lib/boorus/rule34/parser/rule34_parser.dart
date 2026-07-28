import 'package:boorunova/data/repository/booru/entity/post.dart';

class Rule34Parser {
  Rule34Parser._();

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
      final rating = _normalizeRating(post['rating'] as String? ?? '');
      final score = (post['score'] as int?) ?? 0;
      final source = (post['source'] as String?) ?? '';

      return BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: previewUrl,
        sampleUrl: sampleUrl.isNotEmpty ? sampleUrl : fileUrl,
        originalUrl: fileUrl,
        tags: tags.isEmpty ? [] : tags.split(' '),
        aspectRatio: height > 0 ? width / height : 1.0,
        width: width,
        height: height,
        rating: rating,
        score: score,
        source: source.isEmpty ? null : source,
        postUrl: id,
        uploader: null,
      );
    }).toList();
  }

  static List<String> parseSuggestions(List<dynamic> json) {
    return json.whereType<Map<String, dynamic>>().map((tag) {
      return (tag['tag'] as String?) ?? '';
    }).where((name) => name.isNotEmpty).toList();
  }

  static String _normalizeRating(String rating) {
    switch (rating.toLowerCase()) {
      case 'safe':
        return 's';
      case 'questionable':
        return 'q';
      case 'explicit':
        return 'e';
      default:
        return 'q';
    }
  }
}
