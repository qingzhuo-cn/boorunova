import 'package:boorunova/boorus/zerochan/parser/zerochan_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const serverId = 'zerochan';

  group('ZerochanParser.parsePosts', () {
    test('按实测字段形态解析（列表响应里没有 file / author）', () {
      // fixture 对齐实测：列表响应只有 id / width / height / md5 / thumbnail /
      // source / tag / tags（见审查 M1）。此前 fixture 里塞了站点**并不返回**的
      // file 与 author，测试因此一直在验证一个不存在的响应形态。
      final json = {
        'items': [
          {
            'id': 5001,
            'thumbnail': 'https://static.zerochan.net/thumb/5001.jpg',
            'width': 2000,
            'height': 1000,
            'md5': 'abc123',
            'tags': ['Scenery', 'Clouds'],
            'tag': 'Scenery',
            'source': 'https://example.com',
          },
          {
            'id': 5002,
            'thumbnail': '',
            'width': 900,
            'height': 900,
            'tags': <dynamic>[],
          },
        ],
        'total': 2,
      };

      // 显式传站点 URL（渠道默认值见 site_presets_test）
      final posts = ZerochanParser.parsePosts(serverId, json,
          baseUrl: 'https://www.zerochan.net');
      expect(posts, hasLength(2));

      final p1 = posts[0];
      expect(p1.id, '5001');
      expect(p1.serverId, serverId);
      // 大图地址只能靠详情页/按需解析拿到，列表里没有 → 保持为空，
      // 由展示层退回缩略图（M1 的真机核验项，见 docs/DEVICE_VERIFICATION.md）
      expect(p1.originalUrl, isEmpty);
      expect(p1.sampleUrl, isEmpty);
      expect(p1.thumbnailUrl, 'https://static.zerochan.net/thumb/5001.jpg');
      expect(p1.tags, ['Scenery', 'Clouds']);
      expect(p1.aspectRatio, closeTo(2.0, 0.001));
      // zerochan 是 ecchi 向站，无法逐帖判定 → 按可疑（q），不再假装安全
      expect(p1.rating, 'q');
      expect(p1.score, 0);
      expect(p1.source, 'https://example.com');
      expect(p1.uploader, isNull, reason: '列表响应里没有 author 字段');
      expect(p1.postUrl, 'https://www.zerochan.net/5001');

      final p2 = posts[1];
      expect(p2.tags, isEmpty);
      expect(p2.uploader, isNull);
      expect(p2.source, isNull);
    });

    test('响应里若有 file / author（未来或部分端点）仍能取到', () {
      // 与上一条互补：字段消失是实测口径，但解析器不该因为「现在没有」
      // 就把已有的取值路径删掉——那样站点一改回来就静默变成缩略图。
      final posts = ZerochanParser.parsePosts(
        serverId,
        {
          'items': [
            {
              'id': 7,
              'file': 'https://static.zerochan.net/full/7.jpg',
              'thumbnail': 'https://static.zerochan.net/thumb/7.jpg',
              'author': 'someone',
            },
          ],
        },
        baseUrl: 'https://www.zerochan.net',
      );
      expect(posts.single.originalUrl, 'https://static.zerochan.net/full/7.jpg');
      expect(posts.single.sampleUrl, 'https://static.zerochan.net/full/7.jpg');
      expect(posts.single.uploader, 'someone');
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
      // 显式传站点 URL（渠道默认值见 site_presets_test）
      final posts = ZerochanParser.parsePosts(serverId, json,
          baseUrl: 'https://www.zerochan.net');
      expect(posts, hasLength(1));
      expect(posts.first.id, '1');
      expect(posts.first.tags, isEmpty);
      expect(posts.first.width, 0);
    });
  });
}
