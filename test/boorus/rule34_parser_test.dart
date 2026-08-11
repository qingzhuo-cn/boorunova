import 'package:boorunova/boorus/rule34/parser/rule34_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const serverId = 'rule34';

  group('Rule34Parser.parsePosts', () {
    test('正常解析 2 条记录，关键字段正确', () {
      final json = [
        {
          'id': 12345,
          'file_url': 'https://rule34.xxx/images/12345.png',
          'sample_url': 'https://rule34.xxx/samples/12345.jpg',
          'preview_url': 'https://rule34.xxx/thumbnails/12345.jpg',
          'tags': 'landscape mountains sunset',
          'width': 1920,
          'height': 1080,
          'rating': 'safe',
          'score': 42,
          'source': 'https://example.com/src',
        },
        {
          'id': 12346,
          // 协议相对 URL 应补 https:
          'file_url': '//rule34.xxx/images/12346.png',
          'sample_url': '',
          'preview_url': '//rule34.xxx/thumbnails/12346.jpg',
          'tags': 'portrait',
          'width': 800,
          'height': 1200,
          'rating': 'explicit',
          'score': 7,
          'source': '',
        },
      ];

      final posts = Rule34Parser.parsePosts(serverId, json);
      expect(posts, hasLength(2));

      final p1 = posts[0];
      expect(p1.id, '12345');
      expect(p1.serverId, serverId);
      expect(p1.originalUrl, 'https://rule34.xxx/images/12345.png');
      expect(p1.sampleUrl, 'https://rule34.xxx/samples/12345.jpg');
      expect(p1.thumbnailUrl, 'https://rule34.xxx/thumbnails/12345.jpg');
      expect(p1.tags, ['landscape', 'mountains', 'sunset']);
      expect(p1.width, 1920);
      expect(p1.height, 1080);
      expect(p1.aspectRatio, closeTo(1920 / 1080, 0.001));
      expect(p1.rating, 's');
      expect(p1.score, 42);
      expect(p1.source, 'https://example.com/src');
      expect(p1.postUrl,
          'https://rule34.xxx/index.php?page=post&s=view&id=12345');

      final p2 = posts[1];
      // 协议相对 URL 归一化
      expect(p2.originalUrl, 'https://rule34.xxx/images/12346.png');
      // sample 为空时兜底用 file_url
      expect(p2.sampleUrl, p2.originalUrl);
      expect(p2.rating, 'e');
      expect(p2.source, isNull);
    });

    test('rating 归一化：safe/questionable/explicit/未知', () {
      List<Map<String, dynamic>> mk(String r) => [
            {'id': 1, 'file_url': 'a', 'rating': r}
          ];
      expect(Rule34Parser.parsePosts(serverId, mk('safe')).first.rating, 's');
      expect(Rule34Parser.parsePosts(serverId, mk('questionable')).first.rating,
          'q');
      expect(Rule34Parser.parsePosts(serverId, mk('explicit')).first.rating,
          'e');
      // 未知 rating 按 e 处理（保守策略）
      expect(Rule34Parser.parsePosts(serverId, mk('whatever')).first.rating,
          'e');
    });

    test('空输入返回空列表', () {
      expect(Rule34Parser.parsePosts(serverId, const []), isEmpty);
    });

    test('缺字段/畸形记录不崩溃', () {
      final json = [
        {'id': 99}, // 大量字段缺失
        'not a map', // 被 whereType 过滤
      ];
      final posts = Rule34Parser.parsePosts(serverId, json);
      expect(posts, hasLength(1));
      final p = posts.first;
      expect(p.id, '99');
      expect(p.width, 0);
      expect(p.aspectRatio, 1.0);
      expect(p.tags, isEmpty);
      // 缺失 rating 归一化为 e
      expect(p.rating, 'e');
    });

    test('id 缺失时 postUrl 为 null', () {
      final posts = Rule34Parser.parsePosts(serverId, [
        {'file_url': 'https://rule34.xxx/x.png'},
      ]);
      expect(posts.first.postUrl, isNull);
    });
  });

  group('Rule34Parser.parseSuggestions', () {
    test('解析 tag 字段并过滤空名', () {
      final json = [
        {'tag': 'sunset', 'count': 100},
        {'tag': 'mountains'},
        {'tag': ''},
        {'other': 'no tag field'},
      ];
      expect(Rule34Parser.parseSuggestions(json), ['sunset', 'mountains']);
    });

    test('空输入返回空列表', () {
      expect(Rule34Parser.parseSuggestions(const []), isEmpty);
    });
  });
}
