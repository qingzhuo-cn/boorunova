import 'package:boorunova/data/repository/booru/entity/post.dart';

class E621Parser {
  E621Parser._();

  static List<BooruPost> parsePosts(
    String serverId,
    List<dynamic> json,
  ) {
    return json.whereType<Map<String, dynamic>>().map((post) {
      final id = post['id']?.toString() ?? '';
      final file = (post['file'] as Map<String, dynamic>?) ?? {};
      final sample = (post['sample'] as Map<String, dynamic>?) ?? {};
      final preview = (post['preview'] as Map<String, dynamic>?) ?? {};
      final tagsMap = (post['tags'] as Map<String, dynamic>?) ?? {};

      final fileUrl = (file['url'] as String?) ?? '';
      final sampleUrl = (sample['url'] as String?) ?? '';
      final previewUrl = (preview['url'] as String?) ?? '';
      final width = (file['width'] as int?) ?? 0;
      final height = (file['height'] as int?) ?? 0;

      final tagGeneral = _tagList(tagsMap['general']);
      final tagArtist = _tagList(tagsMap['artist']);
      final tagCharacter = _tagList(tagsMap['character']);
      final tagCopyright = _tagList(tagsMap['copyright']);
      final tagMeta = _tagList(tagsMap['meta']);
      final tagSpecies = _tagList(tagsMap['species']);
      final tagLore = _tagList(tagsMap['lore']);

      final allTags = [
        ...tagGeneral,
        ...tagArtist,
        ...tagCharacter,
        ...tagCopyright,
        ...tagMeta,
        ...tagSpecies,
        ...tagLore,
      ];

      final rating = (post['rating'] as String?) ?? 'q';
      final scoreMap = (post['score'] as Map<String, dynamic>?) ?? {};
      final score = (scoreMap['total'] as int?) ?? 0;
      final sources = _tagList(post['sources']);
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
        source: source.isEmpty ? null : source,
        postUrl: id,
      );
    }).toList();
  }

  static List<String> _tagList(Object? input) {
    if (input is List) {
      return input.whereType<String>().toList();
    }
    return [];
  }
}
