import 'package:boorunova/data/repository/booru/entity/post.dart';

class GelbooruV2Parser {
  GelbooruV2Parser._();

  static const String searchEndpoint =
      '/index.php?page=dapi&s=post&q=index';
  static const String suggestEndpoint =
      '/index.php?page=dapi&s=tag&q=index';

  static List<BooruPost> parsePosts(
    String serverId,
    String baseUrl,
    String xml,
  ) {
    final posts = <BooruPost>[];
    final postPattern = RegExp(r'<post\s+(.*?)\s*/>');
    final matches = postPattern.allMatches(xml);

    for (final match in matches) {
      final attrs = _parseAttributes(match.group(1)!);
      if (attrs.isEmpty) continue;

      final id = attrs['id'] ?? '';
      final fileUrl = _decodeXml(attrs['file_url'] ?? '');
      final sampleUrl = _decodeXml(attrs['sample_url'] ?? '');
      final previewUrl = _decodeXml(attrs['preview_url'] ?? '');
      final tags = _decodeXml(attrs['tags'] ?? '');
      final width = int.tryParse(attrs['width'] ?? '0') ?? 0;
      final height = int.tryParse(attrs['height'] ?? '0') ?? 0;
      final rating = attrs['rating'] ?? 'q';
      final score = int.tryParse(attrs['score'] ?? '0') ?? 0;
      final source = _decodeXml(attrs['source'] ?? '');

      if (id.isEmpty || fileUrl.isEmpty || width <= 0 || height <= 0) continue;

      posts.add(BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: previewUrl,
        sampleUrl: sampleUrl,
        originalUrl: fileUrl,
        tags: tags.split(' ').where((t) => t.isNotEmpty).toList(),
        aspectRatio: width / height,
        width: width,
        height: height,
        rating: rating,
        score: score,
        source: source.isEmpty ? null : source,
        postUrl: '$baseUrl/index.php?page=post&s=view&id=$id',
      ));
    }

    return posts;
  }

  static List<String> parseSuggestions(String xml) {
    final tags = <String>[];
    final tagPattern = RegExp(r'<tag\s+(.*?)\s*/>');
    final matches = tagPattern.allMatches(xml);

    for (final match in matches) {
      final attrs = _parseAttributes(match.group(1)!);
      final name = _decodeXml(attrs['name'] ?? '');
      final count = int.tryParse(attrs['count'] ?? '0') ?? 0;
      if (name.isNotEmpty && count > 0) {
        tags.add(name);
      }
    }

    return tags;
  }

  static Map<String, String> _parseAttributes(String raw) {
    final attrs = <String, String>{};
    final attrPattern = RegExp(r'''(\w+)\s*=\s*"([^"]*)"''');
    for (final m in attrPattern.allMatches(raw)) {
      attrs[m.group(1)!] = m.group(2)!;
    }
    return attrs;
  }

  static String _decodeXml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&#x2F;', '/');
  }
}
