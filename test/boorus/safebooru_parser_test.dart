import 'package:boorunova/boorus/gelbooru_v2/parser/gelbooru_v2_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// safebooru 复用 GelbooruV2Parser（XML DAPI 协议），
/// 这里验证以 safebooru 的 serverId/baseUrl 驱动时行为正确。
void main() {
  const serverId = 'safebooru';
  const baseUrl = 'https://safebooru.org';

  group('Safebooru（复用 GelbooruV2Parser）', () {
    test('postUrl 指向 safebooru 域名，serverId 正确', () {
      const xml = '''
<posts>
  <post id="9001" file_url="https://safebooru.org/images/9001.png" sample_url="https://safebooru.org/samples/9001.jpg" preview_url="https://safebooru.org/thumbnails/9001.jpg" tags="smile" width="1000" height="1000" rating="safe" score="3" source="" />
</posts>
''';
      final posts = GelbooruV2Parser.parsePosts(serverId, baseUrl, xml);
      expect(posts, hasLength(1));

      final p = posts.first;
      expect(p.serverId, 'safebooru');
      expect(p.postUrl,
          'https://safebooru.org/index.php?page=post&s=view&id=9001');
      expect(p.rating, 'safe');
      expect(p.tags, ['smile']);
    });

    test('建议解析正常', () {
      const xml = '<tags><tag name="landscape" count="42" /></tags>';
      expect(GelbooruV2Parser.parseSuggestions(xml), ['landscape']);
    });
  });
}
