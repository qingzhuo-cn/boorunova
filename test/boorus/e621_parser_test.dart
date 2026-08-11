import 'package:boorunova/boorus/e621/parser/e621_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// E621Parser 单元测试：fixture 形态参照 e621 /posts.json 真实响应
// 特点：file/sample/preview 为嵌套 Map，tags 为分类 Map，score 为 Map
void main() {
  const serverId = 'e621';

  group('E621Parser.parsePosts', () {
    test('正常解析 2 条记录，关键字段正确', () {
      final json = [
        {
          'id': 4567890,
          'file': {
            'url': 'https://static1.e621.net/data/ab/cd/file1.png',
            'width': 2000,
            'height': 1000,
          },
          'sample': {
            'url': 'https://static1.e621.net/data/sample/ab/cd/sample1.jpg',
          },
          'preview': {
            'url': 'https://static1.e621.net/data/preview/ab/cd/preview1.jpg',
          },
          'tags': {
            'general': ['solo', 'canid'],
            'artist': ['artist_one'],
            'character': ['char_one'],
            'copyright': ['original'],
            'meta': ['hi_res'],
            'species': ['wolf'],
            'lore': ['feral'],
          },
          'rating': 'e',
          'score': {'total': 128, 'up': 130, 'down': -2},
          'sources': ['https://example.com/src1', 'https://example.com/src2'],
        },
        {
          'id': 4567891,
          'file': {
            'url': 'https://static1.e621.net/data/ef/gh/file2.webm',
            'width': 640,
            'height': 960,
          },
          'sample': <String, dynamic>{},
          'preview': <String, dynamic>{},
          'tags': {
            'general': ['animated'],
            // 其余分类缺失
          },
          'rating': 's',
          'score': {'total': 0},
          'sources': <dynamic>[],
        },
      ];

      final posts = E621Parser.parsePosts(serverId, json);
      expect(posts, hasLength(2));

      final p1 = posts[0];
      expect(p1.id, '4567890');
      expect(p1.serverId, serverId);
      expect(p1.originalUrl, 'https://static1.e621.net/data/ab/cd/file1.png');
      expect(p1.sampleUrl,
          'https://static1.e621.net/data/sample/ab/cd/sample1.jpg');
      expect(p1.thumbnailUrl,
          'https://static1.e621.net/data/preview/ab/cd/preview1.jpg');
      expect(p1.width, 2000);
      expect(p1.height, 1000);
      expect(p1.aspectRatio, closeTo(2.0, 1e-9));
      // 所有分类标签合并进 tags
      expect(p1.tags, containsAll(
          ['solo', 'canid', 'artist_one', 'char_one', 'original', 'hi_res', 'wolf', 'feral']));
      // species/lore 归入 tagGeneral
      expect(p1.tagGeneral, ['solo', 'canid', 'wolf', 'feral']);
      expect(p1.tagArtist, ['artist_one']);
      expect(p1.tagCharacter, ['char_one']);
      expect(p1.tagCopyright, ['original']);
      expect(p1.tagMeta, ['hi_res']);
      expect(p1.rating, 'e');
      expect(p1.score, 128);
      // source 取 sources 第一个
      expect(p1.source, 'https://example.com/src1');
      // postUrl 直接为 id 字符串
      expect(p1.postUrl, '4567890');

      final p2 = posts[1];
      expect(p2.id, '4567891');
      expect(p2.sampleUrl, '');
      expect(p2.thumbnailUrl, '');
      expect(p2.aspectRatio, closeTo(640 / 960, 1e-9));
      expect(p2.tags, ['animated']);
      expect(p2.rating, 's');
      expect(p2.score, 0);
      // sources 为空时 source 为 null
      expect(p2.source, isNull);
    });

    test('空输入返回空列表', () {
      expect(E621Parser.parsePosts(serverId, const []), isEmpty);
    });

    test('缺字段/畸形记录不崩溃，使用默认值', () {
      final json = [
        {'id': 42}, // 嵌套 Map 全缺失
        'not a map', // 被 whereType 过滤
        {
          'id': 43,
          'file': 'not a map', // 类型错误的嵌套字段
          'tags': 'also not a map',
          'score': 'not a map either',
        },
      ];

      final posts = E621Parser.parsePosts(serverId, json);
      expect(posts, hasLength(2));

      final p = posts[0];
      expect(p.id, '42');
      expect(p.width, 0);
      expect(p.height, 0);
      expect(p.aspectRatio, 1.0);
      expect(p.tags, isEmpty);
      expect(p.rating, 'q');
      expect(p.score, 0);

      final p2 = posts[1];
      expect(p2.id, '43');
      expect(p2.tags, isEmpty);
      expect(p2.originalUrl, '');
    });
  });
}
