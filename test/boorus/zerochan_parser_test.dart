import 'package:boorunova/boorus/zerochan/parser/zerochan_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const serverId = 'zerochan';

  group('ZerochanParser.parsePosts', () {
    test('正常解析 items 里的 2 条记录', () {
      final json = {
        'items': [
          {
            'id': 5001,
            'file': 'https://static.zerochan.net/full/5001.jpg',
            'thumbnail': 'https://static.zerochan.net/thumb/5001.jpg',
            'width': 2000,
            'height': 1000,
            'tags': ['Scenery', 'Clouds'],
            'author': 'uploader1',
            'source': 'https://example.com',
          },
          {
            'id': 5002,
            'file': 'https://static.zerochan.net/full/5002.jpg',
            'thumbnail': '',
            'width': 900,
            'height': 900,
            'tags': <dynamic>[],
          },
        ],
        'total': 2,
      };

      final posts = ZerochanParser.parsePosts(serverId, json);
      expect(posts, hasLength(2));

      final p1 = posts[0];
      expect(p1.id, '5001');
      expect(p1.serverId, serverId);
      // sample 与 original 都是 file 字段
      expect(p1.originalUrl, 'https://static.zerochan.net/full/5001.jpg');
      expect(p1.sampleUrl, p1.originalUrl);
      expect(p1.thumbnailUrl, 'https://static.zerochan.net/thumb/5001.jpg');
      expect(p1.tags, ['Scenery', 'Clouds']);
      expect(p1.aspectRatio, closeTo(2.0, 0.001));
      // zerochan 全站安全图，rating 固定 s，无分数
      expect(p1.rating, 's');
      expect(p1.score, 0);
      expect(p1.source, 'https://example.com');
      expect(p1.uploader, 'uploader1');
      expect(p1.postUrl, '5001');

      final p2 = posts[1];
      expect(p2.tags, isEmpty);
      expect(p2.uploader, isNull);
      expect(p2.source, isNull);
    });

    test('items 不是 List 时返回空列表', () {
      expect(ZerochanParser.parsePosts(serverId, const {}), isEmpty);
      expect(ZerochanParser.parsePosts(serverId, {'items': 'oops'}), isEmpty);
    });

    test('缺字段/畸形记录不崩溃', () {
      final json = {
        'items': [
          {'id': 1, 'tags': 'not a list'}, // tags 类型错误 -> 空标签
          'not a map',
        ],
      };
      final posts = ZerochanParser.parsePosts(serverId, json);
      expect(posts, hasLength(1));
      expect(posts.first.id, '1');
      expect(posts.first.tags, isEmpty);
      expect(posts.first.width, 0);
    });
  });
}
