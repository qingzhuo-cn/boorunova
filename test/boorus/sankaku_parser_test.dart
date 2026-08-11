import 'package:boorunova/boorus/sankaku/parser/sankaku_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const serverId = 'sankaku';

  group('SankakuParser.parsePosts', () {
    test('正常解析 2 条记录，jpeg_url 优先于 sample_url', () {
      final json = [
        {
          'id': 777,
          'file_url': 'https://sankakucomplex.com/original/777.png',
          'sample_url': 'https://sankakucomplex.com/sample/777.jpg',
          'jpeg_url': 'https://sankakucomplex.com/jpeg/777.jpg',
          'preview_url': 'https://sankakucomplex.com/preview/777.jpg',
          'tags': '1girl solo long_hair',
          'width': 1500,
          'height': 2000,
          'rating': 's',
          'score': 88,
          'source': 'https://pixiv.net/x',
          'author': 'artist_name',
        },
        {
          'id': 778,
          'file_url': 'https://sankakucomplex.com/original/778.png',
          'sample_url': 'https://sankakucomplex.com/sample/778.jpg',
          // jpeg_url 缺失，sample 应回退到 sample_url
          'preview_url': '',
          'tags': '',
          'width': 0,
          'height': 0,
        },
      ];

      final posts = SankakuParser.parsePosts(serverId, json);
      expect(posts, hasLength(2));

      final p1 = posts[0];
      expect(p1.id, '777');
      expect(p1.serverId, serverId);
      expect(p1.originalUrl, 'https://sankakucomplex.com/original/777.png');
      // jpeg_url 非空时优先作为 sample
      expect(p1.sampleUrl, 'https://sankakucomplex.com/jpeg/777.jpg');
      expect(p1.thumbnailUrl, 'https://sankakucomplex.com/preview/777.jpg');
      expect(p1.tags, ['1girl', 'solo', 'long_hair']);
      expect(p1.aspectRatio, closeTo(0.75, 0.001));
      expect(p1.rating, 's');
      expect(p1.score, 88);
      expect(p1.source, 'https://pixiv.net/x');
      expect(p1.uploader, 'artist_name');
      // sankaku 的 postUrl 就是 id 本身
      expect(p1.postUrl, '777');

      final p2 = posts[1];
      // jpeg_url 缺失时回退 sample_url
      expect(p2.sampleUrl, 'https://sankakucomplex.com/sample/778.jpg');
      expect(p2.tags, isEmpty);
      expect(p2.aspectRatio, 1.0);
      expect(p2.rating, 'q'); // 默认
    });

    test('空输入返回空列表', () {
      expect(SankakuParser.parsePosts(serverId, const []), isEmpty);
    });

    test('缺字段/畸形记录不崩溃', () {
      final json = [
        {'id': 1},
        42, // 非 Map 被过滤
      ];
      final posts = SankakuParser.parsePosts(serverId, json);
      expect(posts, hasLength(1));
      expect(posts.first.id, '1');
      expect(posts.first.source, isNull);
      expect(posts.first.uploader, isNull);
    });
  });

  group('SankakuParser.parseSuggestions', () {
    test('解析 name 字段并过滤空名', () {
      final json = [
        {'name': 'long_hair', 'post_count': 5000},
        {'name': 'solo'},
        {'name': ''},
        {'id': 3},
      ];
      expect(SankakuParser.parseSuggestions(json), ['long_hair', 'solo']);
    });

    test('空输入返回空列表', () {
      expect(SankakuParser.parseSuggestions(const []), isEmpty);
    });
  });
}
