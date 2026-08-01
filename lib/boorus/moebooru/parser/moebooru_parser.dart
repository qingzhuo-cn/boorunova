import 'package:boorunova/data/repository/booru/entity/post.dart';

class MoebooruParser {
  MoebooruParser._();

  static const _siteUrl = 'https://yande.re';

  static String _abs(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('http://')) return 'https://${url.substring(7)}';
    return url;
  }

  static List<BooruPost> parsePosts(
    String serverId,
    List<dynamic> json,
  ) {
    return json.whereType<Map<String, dynamic>>().map((post) {
      final id = post['id']?.toString() ?? '';
      var fileUrl = _abs((post['file_url'] as String?) ?? '');
      var sampleUrl = _abs((post['sample_url'] as String?) ?? '');
      final previewUrl = _abs((post['preview_url'] as String?) ?? '');
      final jpegUrl = _abs((post['jpeg_url'] as String?) ?? '');
      final tags = (post['tags'] as String?) ?? '';
      final width = (post['width'] as int?) ?? 0;
      final height = (post['height'] as int?) ?? 0;
      final rating = (post['rating'] as String?) ?? 'q';
      final score = (post['score'] as int?) ?? 0;
      final source = (post['source'] as String?) ?? '';
      final author = (post['author'] as String?) ?? '';

      // 部分帖子 file_url 缺失（如删除的帖子），用 jpeg/sample 兜底
      if (fileUrl.isEmpty) fileUrl = jpegUrl.isNotEmpty ? jpegUrl : sampleUrl;
      if (sampleUrl.isEmpty) sampleUrl = jpegUrl.isNotEmpty ? jpegUrl : fileUrl;

      return BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: previewUrl,
        sampleUrl: sampleUrl,
        originalUrl: fileUrl,
        tags: tags.isEmpty ? [] : tags.split(' '),
        aspectRatio: height > 0 ? width / height : 1.0,
        width: width,
        height: height,
        rating: rating,
        score: score,
        source: source.isEmpty ? null : source,
        postUrl: id.isEmpty ? null : '$_siteUrl/post/show/$id',
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
