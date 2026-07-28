import 'package:boorunova/data/repository/booru/entity/post.dart';

class ZerochanParser {
  ZerochanParser._();

  static List<BooruPost> parsePosts(
    String serverId,
    Map<String, dynamic> json,
  ) {
    final items = json['items'];
    if (items is! List) return [];

    return items.whereType<Map<String, dynamic>>().map((post) {
      final id = post['id']?.toString() ?? '';
      final file = (post['file'] as String?) ?? '';
      final thumbnail = (post['thumbnail'] as String?) ?? '';
      final width = (post['width'] as int?) ?? 0;
      final height = (post['height'] as int?) ?? 0;
      final tagList = post['tags'];
      final tags = tagList is List
          ? tagList.whereType<String>().toList()
          : <String>[];
      final author = (post['author'] as String?) ?? '';
      final source = (post['source'] as String?) ?? '';
      const rating = 's';

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
        source: source.isEmpty ? null : source,
        postUrl: id,
        uploader: author.isEmpty ? null : author,
      );
    }).toList();
  }
}
