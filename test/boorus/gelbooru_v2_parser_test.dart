import 'package:boorunova/boorus/gelbooru_v2/parser/gelbooru_v2_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const serverId = 'gelbooru_v2';
  const baseUrl = 'https://gelbooru.com';

  group('GelbooruV2Parser.parsePosts', () {
    test('解析 XML，含实体解码与 URL 拼接', () {
      const xml = '''
<posts count="2">
  <post id="100" file_url="https://img4.gelbooru.com/images/ab/cd.png" sample_url="https://img4.gelbooru.com/samples/ab/cd.jpg" preview_url="https://img4.gelbooru.com/thumbnails/ab/cd.jpg" tags="1girl solo smile &amp; wink" width="1200" height="800" rating="general" score="15" source="https://pixiv.net/artworks/1?x=1&amp;y=2" />
  <post id="101" file_url="https://img4.gelbooru.com/images/ef/gh.png" sample_url="" preview_url="" tags="scenery" width="640" height="480" rating="sensitive" score="0" source="" />
</posts>
''';

      final posts = GelbooruV2Parser.parsePosts(serverId, baseUrl, xml);
      expect(posts, hasLength(2));

      final p1 = posts[0];
      expect(p1.id, '100');
      expect(p1.serverId, serverId);
      expect(p1.originalUrl, 'https://img4.gelbooru.com/images/ab/cd.png');
      expect(p1.sampleUrl, 'https://img4.gelbooru.com/samples/ab/cd.jpg');
      // XML 实体解码：&amp; -> &
      expect(p1.tags, ['1girl', 'solo', 'smile', '&', 'wink']);
      expect(p1.width, 1200);
      expect(p1.height, 800);
      expect(p1.aspectRatio, closeTo(1.5, 0.001));
      expect(p1.rating, 'general');
      expect(p1.score, 15);
      expect(p1.source, 'https://pixiv.net/artworks/1?x=1&y=2');
      expect(p1.postUrl,
          '$baseUrl/index.php?page=post&s=view&id=100');

      final p2 = posts[1];
      expect(p2.tags, ['scenery']);
      expect(p2.source, isNull);
    });

    test('无效记录被跳过：缺 id/缺 file_url/宽高为 0', () {
      const xml = '''
<posts>
  <post id="" file_url="https://x/1.png" width="100" height="100" />
  <post id="201" file_url="" width="100" height="100" />
  <post id="202" file_url="https://x/2.png" width="0" height="100" />
  <post id="203" file_url="https://x/3.png" width="100" height="100" />
</posts>
''';
      final posts = GelbooruV2Parser.parsePosts(serverId, baseUrl, xml);
      // 只有 203 是完整记录
      expect(posts, hasLength(1));
      expect(posts.first.id, '203');
    });

    test('空输入/无 post 标签返回空列表', () {
      expect(GelbooruV2Parser.parsePosts(serverId, baseUrl, ''), isEmpty);
      expect(
        GelbooruV2Parser.parsePosts(serverId, baseUrl, '<posts count="0" />'),
        isEmpty,
      );
    });
  });

  group('GelbooruV2Parser.parseSuggestions', () {
    test('解析 tag 标签并过滤 count 为 0 的项', () {
      const xml = '''
<tags>
  <tag name="cat_girl" count="1234" />
  <tag name="dog_boy" count="56" />
  <tag name="unused_tag" count="0" />
  <tag name="" count="10" />
</tags>
''';
      expect(
        GelbooruV2Parser.parseSuggestions(xml),
        ['cat_girl', 'dog_boy'],
      );
    });

    test('name 里的实体被解码', () {
      const xml = '<tags><tag name="rock_&amp;_roll" count="5" /></tags>';
      expect(GelbooruV2Parser.parseSuggestions(xml), ['rock_&_roll']);
    });

    test('空输入返回空列表', () {
      expect(GelbooruV2Parser.parseSuggestions(''), isEmpty);
    });
  });
}
