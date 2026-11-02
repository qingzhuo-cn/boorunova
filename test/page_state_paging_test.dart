import 'dart:async';

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// 假引擎：按脚本返回结果或抛错，用 Completer 控制响应时序。
class _FakeRepo implements BooruRepository {
  _FakeRepo({this.onSearch});

  final Future<BooruPageResult> Function(BooruQuery query)? onSearch;

  @override
  String get serverId => 'fake';

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    final handler = onSearch;
    if (handler == null) {
      return const BooruPageResult(posts: [], hasMore: false);
    }
    return handler(query);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PostSummary _post(String id) => PostSummary(
      id: id,
      thumbnailUrl: 'https://example.test/$id-thumb.jpg',
      sampleUrl: 'https://example.test/$id.jpg',
      originalUrl: 'https://example.test/$id-orig.jpg',
      tags: const ['tag'],
      aspectRatio: 1,
      width: 100,
      height: 100,
      rating: 's',
      score: 0,
      serverId: 'fake',
    );

void main() {
  group('loadMore 去重与熔断', () {
    test('某页全是与已有列表重复的帖子时 appended 为空，hasMore 熔断为 false', () async {
      var requests = 0;
      final notifier = BooruPageNotifier();
      addTearDown(notifier.dispose);

      final repo = _FakeRepo(onSearch: (query) async {
        requests++;
        // 引擎 offset/pid 退化：无论第几页都原样返回同一批帖子。
        return BooruPageResult(
          posts: [_post('a'), _post('b')],
          hasMore: true,
        );
      });
      await notifier.switchServer(repo);
      expect(notifier.state.posts, hasLength(2));
      expect(notifier.state.hasMore, isTrue);

      await notifier.loadMore();

      expect(notifier.state.posts.map((p) => p.id), ['a', 'b'],
          reason: '重复帖不应被追加（否则会出现重复 Hero tag）');
      expect(notifier.state.hasMore, isFalse,
          reason: '这一页有内容但去重后无新增 -> 熔断，否则坏引擎被无限爬页');

      // 熔断后继续滚动不应再打请求
      final before = requests;
      await notifier.loadMore();
      expect(requests, before,
          reason: 'hasMore=false 后 loadMore 必须直接返回，不再请求');
    });

    test('某页部分重复、部分新增时正常追加且 hasMore 不被误熔断', () async {
      final notifier = BooruPageNotifier();
      addTearDown(notifier.dispose);

      final repo = _FakeRepo(onSearch: (query) async {
        if (query.page == 1) {
          return BooruPageResult(
            posts: [_post('a'), _post('b')],
            hasMore: true,
          );
        }
        // 第 2 页有旧帖 c 重复、但也有新帖 d。
        return BooruPageResult(
          posts: [_post('b'), _post('d')],
          hasMore: true,
        );
      });
      await notifier.switchServer(repo);
      await notifier.loadMore();

      expect(notifier.state.posts.map((p) => p.id), ['a', 'b', 'd'],
          reason: '只追加真正的新帖，b 不应出现两次');
      expect(notifier.state.hasMore, isTrue,
          reason: '有新增就不是退化页，不能误熔断');
      expect(notifier.state.currentPage, 2);
    });
  });

  group('switchServer 竞态', () {
    test('switchServer 期间迟到的旧站响应被丢弃', () async {
      final notifier = BooruPageNotifier();
      addTearDown(notifier.dispose);

      final slowA = Completer<BooruPageResult>();
      final fastB = Completer<BooruPageResult>();
      final repoA = _FakeRepo(onSearch: (_) => slowA.future);
      final repoB = _FakeRepo(onSearch: (_) => fastB.future);

      // A 站请求挂起（尚未返回）时立刻切到 B 站
      final pendingA = notifier.switchServer(repoA);
      final switchingB = notifier.switchServer(repoB);

      fastB.complete(BooruPageResult(posts: [_post('b')], hasMore: false));
      await switchingB;
      expect(notifier.state.posts.map((p) => p.id), ['b']);
      expect(notifier.state.isLoading, isFalse);

      // A 站的响应现在才回来：必须被序号守卫丢弃
      slowA.complete(BooruPageResult(posts: [_post('a')], hasMore: true));
      await pendingA;

      expect(notifier.state.posts.map((p) => p.id), ['b'],
          reason: '过期请求不得覆盖新站结果（否则切站后显示上一个站的内容）');
      expect(notifier.state.hasMore, isFalse,
          reason: 'hasMore 也必须保持 B 站的值，不能被过期响应改写');
      expect(notifier.state.isLoading, isFalse);
    });

    test('切站后迟到的旧站错误同样被丢弃', () async {
      final notifier = BooruPageNotifier();
      addTearDown(notifier.dispose);

      final slowA = Completer<BooruPageResult>();
      final repoA = _FakeRepo(onSearch: (_) => slowA.future);
      final repoB = _FakeRepo(
        onSearch: (_) async =>
            BooruPageResult(posts: [_post('b')], hasMore: false),
      );

      final pendingA = notifier.switchServer(repoA);
      await notifier.switchServer(repoB);
      expect(notifier.state.error, isNull);

      slowA.completeError(StateError('old server down'));
      await pendingA;

      expect(notifier.state.error, isNull,
          reason: '旧站报错不能把新站结果染成错误态');
      expect(notifier.state.posts.map((p) => p.id), ['b']);
    });
  });
}
