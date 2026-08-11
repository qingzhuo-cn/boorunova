import 'package:boorunova/boorus/moebooru/parser/moebooru_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// MoebooruParser 单元测试：fixture 形态参照 yande.re /post.json 真实响应
// 重点验证 _abs URL 归一化与 file_url 缺失时的兜底逻辑
void main() {
  const serverId = 'moebooru';

  group('MoebooruParser.parsePosts', () {
    test('正常解析 2 条记录，关键字段与 URL 归一化正确', () {
      final json = [
        {
          'id': 800001,
          // 协议相对 URL，应补 https:
          'file_url': '//files.yande.re/image/ab/cd/file1.jpg',
          'sample_url': '//files.yande.re/sample/ab/cd/sample1.jpg',
          'preview_url': '//files.yande.re/preview/ab/cd/preview1.jpg',
          'jpeg_url': '//files.yande.re/jpeg/ab/cd/jpeg1.jpg',
          'tags': 'landscape sky cloud',
          'width': 1920,
          'height': 1080,
          'rating': 's',
          'score': 77,
          'source': 'https://example.com/src1',
          'author': 'artist_one',
        },
        {
          'id': 800002,
          // http:// 应升级为 https://
          'file_url': 'http://files.yande.re/image/ef/gh/file2.png',
          'sample_url': 'https://files.yande.re/sample/ef/gh/sample2.png',
          'preview_url': 'https://files.yande.re/preview/ef/gh/preview2.png',
          'jpeg_url': '',
          'tags': 'portrait',
          'width': 800,
          'height': 1200,
          'rating': 'q',
          'score': 0,
          'source': '',
          'author': '',
        },
      ];

      final posts = MoebooruParser.parsePosts(serverId, json);
      expect(posts, hasLength(2));

      final p1 = posts[0];
      expect(p1.id, '800001');
      expect(p1.originalUrl, 'https://files.yande.re/image/ab/cd/file1.jpg');
      expect(p1.sampleUrl, 'https://files.yande.re/sample/ab/cd/sample1.jpg');
      expect(p1.thumbnailUrl, 'https://files.yande.re/preview/ab/cd/preview1.jpg');
      expect(p1.width, 1920);
      expect(p1.height, 1080);
      expect(p1.aspectRatio, closeTo(1920 / 1080, 1e-9));
      expect(p1.tags, ['landscape', 'sky', 'cloud']);
      expect(p1.rating, 's');
      expect(p1.score, 77);
      expect(p1.source, 'https://example.com/src1');
      expect(p1.uploader, 'artist_one');
      expect(p1.postUrl, 'https://yande.re/post/show/800001');

      final p2 = posts[1];
      expect(p2.originalUrl, 'https://files.yande.re/image/ef/gh/file2.png');
      expect(p2.source, isNull);
      expect(p2.uploader, isNull);
    });

    test('file_url 缺失时用 jpeg/sample 兜底', () {
      final json = [
        {
          'id': 800003,
          'file_url': '',
          'sample_url': '',
          'preview_url': '',
          'jpeg_url': 'https://files.yande.re/jpeg/xx/jpeg.jpg',
          'tags': '',
          'width': 100,
          'height': 100,
          'rating': 's',
          'score': 1,
        },
      ];

      final posts = MoebooruParser.parsePosts(serverId, json);
      expect(posts, hasLength(1));
      // file_url 与 sample_url 都兜底为 jpeg_url
      expect(posts[0].originalUrl, 'https://files.yande.re/jpeg/xx/jpeg.jpg');
      expect(posts[0].sampleUrl, 'https://files.yande.re/jpeg/xx/jpeg.jpg');
      expect(posts[0].tags, isEmpty);
    });

    test('空输入返回空列表', () {
      expect(MoebooruParser.parsePosts(serverId, const []), isEmpty);
    });

    test('缺字段/畸形记录不崩溃，使用默认值', () {
      final json = [
        {'id': 9},
        42, // 非 Map 被过滤
      ];

      final posts = MoebooruParser.parsePosts(serverId, json);
      expect(posts, hasLength(1));

      final p = posts[0];
      expect(p.id, '9');
      expect(p.width, 0);
      expect(p.height, 0);
      expect(p.aspectRatio, 1.0);
      expect(p.tags, isEmpty);
      expect(p.rating, 'q');
      expect(p.postUrl, 'https://yande.re/post/show/9');
    });

    test('id 缺失时 postUrl 为 null', () {
      final json = [
        {'width': 10, 'height': 10},
      ];
      final posts = MoebooruParser.parsePosts(serverId, json);
      expect(posts[0].postUrl, isNull);
    });
  });

  group('MoebooruParser.parseSuggestions', () {
    test('解析标签建议并过滤空名', () {
      final json = [
        {'name': 'sky'},
        {'name': 'cloud'},
        {'name': ''},
      ];
      expect(MoebooruParser.parseSuggestions(json), ['sky', 'cloud']);
    });

    test('空输入返回空列表', () {
      expect(MoebooruParser.parseSuggestions(const []), isEmpty);
    });
  });
}
