import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/tags_blocker/entity/booru_tag.dart';
import 'package:boorunova/presentation/provider/tags_blocker_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// 站点作用域黑名单的过滤口径（OPT §6.4）。
///
/// 需要它的现实理由：各站标签体系不同——`cat` 在某个站是一个角色，在另一个站
/// 可能只是普通标签。所以「全局屏蔽」与「只在某站屏蔽」必须能共存。
PostSummary _post({
  required String id,
  required String serverId,
  required List<String> tags,
}) =>
    PostSummary(
      id: id,
      serverId: serverId,
      thumbnailUrl: '',
      sampleUrl: '',
      originalUrl: '',
      tags: tags,
      aspectRatio: 1,
      width: 100,
      height: 100,
      rating: 's',
      score: 0,
    );

Map<int, BooruTag> _blocked(List<BooruTag> tags) => {
      for (var i = 0; i < tags.length; i++) i + 1: tags[i],
    };

void main() {
  group('filterBlockedPosts 的作用域', () {
    test('全局条目在所有站点都生效', () {
      final posts = [
        _post(id: '1', serverId: 'a', tags: ['cat']),
        _post(id: '2', serverId: 'b', tags: ['cat']),
        _post(id: '3', serverId: 'a', tags: ['dog']),
      ];

      final filtered = filterBlockedPosts(
        posts,
        _blocked(const [BooruTag(name: 'cat')]),
      );

      expect(filtered.map((p) => p.id), ['3']);
    });

    test('站点条目只在那个站点生效（不泄漏到别的站）', () {
      final posts = [
        _post(id: '1', serverId: 'a', tags: ['cat']),
        _post(id: '2', serverId: 'b', tags: ['cat']),
      ];

      final filtered = filterBlockedPosts(
        posts,
        _blocked(const [BooruTag(serverId: 'a', name: 'cat')]),
      );

      expect(filtered.map((p) => p.id), ['2'],
          reason: '在 A 站屏蔽 cat 不该把 B 站的 cat 也屏蔽掉');
    });

    test('同一个标签可以既是全局又是指定站点（互不干扰）', () {
      final posts = [
        _post(id: '1', serverId: 'a', tags: ['cat']),
        _post(id: '2', serverId: 'b', tags: ['cat']),
        _post(id: '3', serverId: 'b', tags: ['dog']),
      ];

      final filtered = filterBlockedPosts(
        posts,
        _blocked(const [
          BooruTag(serverId: 'a', name: 'cat'),
          BooruTag(serverId: 'b', name: 'dog'),
        ]),
      );

      expect(filtered.map((p) => p.id), ['2'],
          reason: '两条站点作用域各自只影响自己的站');
    });

    test('混合站点的列表按每条帖子自己的 serverId 判定', () {
      final posts = [
        _post(id: 'a1', serverId: 'a', tags: ['x']),
        _post(id: 'b1', serverId: 'b', tags: ['x']),
        _post(id: 'c1', serverId: 'c', tags: ['x']),
      ];

      final filtered = filterBlockedPosts(
        posts,
        _blocked(const [
          BooruTag(serverId: 'b', name: 'x'),
          BooruTag(name: 'y'),
        ]),
      );

      expect(filtered.map((p) => p.id), ['a1', 'c1']);
    });

    test('空名单与空标签名都不影响结果', () {
      final posts = [_post(id: '1', serverId: 'a', tags: ['cat'])];
      expect(filterBlockedPosts(posts, const {}), hasLength(1));
      expect(
        filterBlockedPosts(posts, _blocked(const [BooruTag(name: '')])),
        hasLength(1),
      );
    });
  });
}
