import 'package:boorunova/boorus/danbooru/parser/danbooru_parser.dart';
import 'package:boorunova/boorus/e621/parser/e621_parser.dart';
import 'package:boorunova/boorus/engine/json_coerce.dart';
import 'package:boorunova/boorus/moebooru/parser/moebooru_parser.dart';
import 'package:boorunova/boorus/rule34/parser/rule34_parser.dart';
import 'package:boorunova/boorus/sankaku/parser/sankaku_parser.dart';
import 'package:boorunova/boorus/zerochan/parser/zerochan_parser.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:flutter_test/flutter_test.dart';

/// M5 的守卫：站点响应并不守约，单条脏数据（score=3.5、width="1200"、
/// 标签列表里混进数字）不能让**整页搜索**抛异常。
void main() {
  group('宽容取值工具', () {
    test('asInt：int / num / 字符串数字 / 脏值', () {
      expect(asInt(12), 12);
      expect(asInt(3.9), 3);
      expect(asInt('12'), 12);
      expect(asInt(' 12 '), 12);
      expect(asInt('abc'), 0);
      expect(asInt(null), 0);
      expect(asInt(null, fallback: -1), -1);
      expect(asInt(<int>[1]), 0);
    });

    test('asDouble / asStr / asStrOrNull', () {
      expect(asDouble('1.5'), 1.5);
      expect(asDouble(2), 2.0);
      expect(asDouble('x'), 0.0);
      expect(asStr(null), '');
      expect(asStr(42), '42');
      expect(asStr(null, fallback: 'q'), 'q');
      expect(asStrOrNull('   '), isNull);
      expect(asStrOrNull(' x '), 'x');
    });

    test('asStrList 跳过非字符串元素（List<String>.from 会抛）', () {
      expect(asStrList(['a', 3, null, 'b']), ['a', 'b']);
      expect(asStrList('not a list'), isEmpty);
    });

    test('asMap / asMapList 对脏输入不抛', () {
      expect(asMap('nope'), isEmpty);
      expect(asMap(<int, String>{1: 'a'}), isEmpty,
          reason: '键不是 String 时 Map.from 会抛，必须兜住');
      expect(asMap({'a': 1}), {'a': 1});
      expect(asMapList([{'a': 1}, 'x', 3]), hasLength(1));
    });

    test('parseEach 丢条保页', () {
      var seen = 0;
      final out = parseEach<int>([
        {'id': 1},
        'not a map',
        {'id': 2},
        {'id': 3},
      ], (raw) {
        seen++;
        final id = asInt(raw['id']);
        if (id == 3) throw StateError('单条彻底坏掉');
        return id;
      });
      expect(seen, 3);
      expect(out, [1, 2], reason: '坏的那条被丢掉，好的照常返回');
    });
  });

  group('各引擎对脏记录的容错（不再是整页失败）', () {
    test('danbooru：score 是 double、宽高是字符串', () {
      final posts = DanbooruParser.parsePosts('s', 'https://x', [
        {
          'id': 1,
          'score': 3.5,
          'image_width': '1200',
          'image_height': 800.0,
          'tag_string': 'a b',
        },
      ]);
      expect(posts, hasLength(1));
      expect(posts.single.score, 3);
      expect(posts.single.width, 1200);
      expect(posts.single.height, 800);
      expect(posts.single.tags, ['a', 'b']);
    });

    test('e621：score.total 是字符串、tags 里混入数字', () {
      final posts = E621Parser.parsePosts('s', [
        {
          'id': 1,
          'score': {'total': '128'},
          'tags': {
            'general': ['solo', 7],
          },
        },
      ]);
      expect(posts.single.score, 128);
      expect(posts.single.tags, ['solo']);
    });

    test('moebooru / sankaku / rule34 / zerochan 同样丢条保页', () {
      expect(
        MoebooruParser.parsePosts('s', [
          {'id': 1, 'score': '5', 'width': 100.0, 'height': 200},
        ]).single.score,
        5,
      );
      expect(
        SankakuParser.parsePosts('s', [
          {'id': 2, 'score': '9'}, 
        ]).single.score,
        9,
      );
      expect(
        Rule34Parser.parsePosts('s', [
          {'id': 3, 'score': 4.7, 'rating': 'safe'},
        ]).single.score,
        4,
      );
      expect(
        ZerochanParser.parsePosts('s', {
          'items': [
            {'id': 4, 'tags': ['a', 5, 'b']},
          ],
        }).single.tags,
        ['a', 'b'],
      );
    });

    test('rule34 的帖子链接跟随配置域名，不再硬编码 rule34.xxx', () {
      final posts = Rule34Parser.parsePosts('s', [
        {'id': 77},
      ], siteUrl: 'https://rule34.us/');
      expect(posts.single.postUrl,
          'https://rule34.us/index.php?page=post&s=view&id=77');
    });
  });

  group('BooruPost.fromJson 的宽容口径', () {
    test('脏标签列表 / double 宽高 / 非法宽高比都能读', () {
      final post = BooruPost.fromJson({
        'id': '1',
        'tags': ['a', 3, null],
        'width': 1200.0,
        'height': '800',
        'score': '7',
        'aspectRatio': 0,
      });
      expect(post.tags, ['a']);
      expect(post.width, 1200);
      expect(post.height, 800);
      expect(post.score, 7);
      expect(post.aspectRatio, 1.0,
          reason: '0/NaN/无穷会让 AspectRatio 抛断言，必须兜到 1.0');
    });
  });
}
