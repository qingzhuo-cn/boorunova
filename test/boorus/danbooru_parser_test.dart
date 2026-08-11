import 'package:boorunova/boorus/danbooru/parser/danbooru_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// DanbooruParser 单元测试：fixture 形态参照 danbooru /posts.json 真实响应
void main() {
  const serverId = 'danbooru';
  const baseUrl = 'https://danbooru.donmai.us';

  group('DanbooruParser.parsePosts', () {
    test('正常解析 2 条记录，关键字段正确', () {
      final json = [
        {
          'id': 7000001,
          'file_url': 'https://cdn.donmai.us/original/ab/cd/file1.jpg',
          'large_file_url': 'https://cdn.donmai.us/sample/ab/cd/sample1.jpg',
          'preview_file_url': 'https://cdn.donmai.us/preview/ab/cd/preview1.jpg',
          'image_width': 1200,
          'image_height': 800,
          'tag_string': '1girl solo smile',
          'tag_string_general': '1girl solo',
          'tag_string_artist': 'some_artist',
          'tag_string_character': 'hatsune_miku',
          'tag_string_copyright': 'vocaloid',
          'tag_string_meta': 'highres',
          'rating': 's',
          'score': 42,
          'source': 'https://example.com/src1',
          'uploader_name': 'uploader1',
        },
        {
          // 相对路径 URL，验证 baseUrl 拼接
          'id': 7000002,
          'file_url': '/data/file2.png',
          'large_file_url': '/data/sample2.png',
          'preview_file_url': '/data/preview2.png',
          'image_width': 500,
          'image_height': 1000,
          'tag_string': 'landscape',
          'tag_string_general': 'landscape',
          'rating': 'q',
          'score': -3,
          'source': '',
          'uploader_name': '',
        },
      ];

      final posts = DanbooruParser.parsePosts(serverId, baseUrl, json);
      expect(posts, hasLength(2));

      final p1 = posts[0];
      expect(p1.id, '7000001');
      expect(p1.serverId, serverId);
      expect(p1.originalUrl, 'https://cdn.donmai.us/original/ab/cd/file1.jpg');
      expect(p1.sampleUrl, 'https://cdn.donmai.us/sample/ab/cd/sample1.jpg');
      expect(p1.thumbnailUrl, 'https://cdn.donmai.us/preview/ab/cd/preview1.jpg');
      expect(p1.width, 1200);
      expect(p1.height, 800);
      expect(p1.aspectRatio, closeTo(1.5, 1e-9));
      expect(p1.tags, ['1girl', 'solo', 'smile']);
      expect(p1.tagGeneral, ['1girl', 'solo']);
      expect(p1.tagArtist, ['some_artist']);
      expect(p1.tagCharacter, ['hatsune_miku']);
      expect(p1.tagCopyright, ['vocaloid']);
      expect(p1.tagMeta, ['highres']);
      expect(p1.rating, 's');
      expect(p1.score, 42);
      expect(p1.source, 'https://example.com/src1');
      expect(p1.uploader, 'uploader1');
      expect(p1.postUrl, '$baseUrl/posts/7000001');

      final p2 = posts[1];
      expect(p2.id, '7000002');
      // 相对路径拼接 baseUrl
      expect(p2.originalUrl, '$baseUrl/data/file2.png');
      expect(p2.sampleUrl, '$baseUrl/data/sample2.png');
      expect(p2.thumbnailUrl, '$baseUrl/data/preview2.png');
      expect(p2.aspectRatio, closeTo(0.5, 1e-9));
      expect(p2.rating, 'q');
      expect(p2.score, -3);
      // 空 source/uploader 转为 null
      expect(p2.source, isNull);
      expect(p2.uploader, isNull);
    });

    test('空输入返回空列表', () {
      expect(DanbooruParser.parsePosts(serverId, baseUrl, const []), isEmpty);
    });

    test('缺字段/畸形记录不崩溃，使用默认值', () {
      final json = [
        {'id': 123}, // 大量字段缺失
        'not a map', // 非 Map 元素被 whereType 过滤
        <String, dynamic>{}, // 完全空 Map
      ];

      final posts = DanbooruParser.parsePosts(serverId, baseUrl, json);
      // 非 Map 被过滤，剩 2 条
      expect(posts, hasLength(2));

      final p = posts[0];
      expect(p.id, '123');
      expect(p.width, 0);
      expect(p.height, 0);
      // height 为 0 时 aspectRatio 兜底 1.0
      expect(p.aspectRatio, 1.0);
      expect(p.tags, isEmpty);
      expect(p.rating, 'q');
      expect(p.score, 0);
      expect(p.originalUrl, baseUrl); // 空 URL 经 _normalize 拼成 baseUrl
    });
  });

  group('DanbooruParser.parseSuggestions', () {
    test('解析标签建议并过滤空名', () {
      final json = [
        {'name': 'hatsune_miku'},
        {'name': 'vocaloid'},
        {'name': ''},
        {'other': 1},
      ];
      expect(
        DanbooruParser.parseSuggestions(json),
        ['hatsune_miku', 'vocaloid'],
      );
    });

    test('空输入返回空列表', () {
      expect(DanbooruParser.parseSuggestions(const []), isEmpty);
    });
  });
}
