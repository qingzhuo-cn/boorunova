import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/tags_blocker/booru_tags_blocker_repo.dart';
import 'package:boorunova/data/repository/tags_blocker/entity/booru_tag.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/provider/booru/site_artwork.dart';
import 'package:boorunova/presentation/provider/tags_blocker_state.dart';
import 'package:boorunova/presentation/widgets/common/site_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 假黑名单仓库：绕开 Hive，直接给一份固定的屏蔽列表。
class _FakeBlockerRepo extends BooruTagsBlockerRepo {
  _FakeBlockerRepo(this._tags);

  final Map<int, BooruTag> _tags;

  @override
  Map<int, BooruTag> getAll() => _tags;
}

/// 假仓库：按 `标签|评级` 返回预置结果，并记录收到过的查询。
///
/// 头图候选完全取决于「发出去的查询」和「拿回来的帖子」这两件事，
/// 所以测试盯着这两样就够，不需要真的起服务器。
class _FakeRepo implements BooruRepository {
  _FakeRepo(this.responses, {this.throwOn = const <String>{}});

  /// 键是 `'$tags|${rating ?? '-'}'`。
  final Map<String, List<PostSummary>> responses;

  /// 这些键对应的查询直接抛异常，用于覆盖「换下一种查询」的分支。
  final Set<String> throwOn;

  final List<BooruQuery> queries = [];

  @override
  String get serverId => 'test';

  /// 视频解析是接口成员（视频站用），图片站返回 null 即「无需按需解析」。
  @override
  Future<String?> resolveMediaUrl(String postUrl) async => null;

  @override
  Map<String, String> get mediaHeaders => const {};

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    queries.add(query);
    final key = '${query.tags}|${query.rating ?? '-'}';
    if (throwOn.contains(key)) throw StateError('boom: $key');
    return BooruPageResult(
      posts: responses[key] ?? const [],
      hasMore: false,
    );
  }

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async => [];

  @override
  Future<List<String>> fetchTrendingTags({int limit = 20}) async => [];

  @override
  Future<List<BooruPool>> fetchPools({int page = 1, int limit = 20}) async => [];
}

PostSummary _post(
  String id, {
  String rating = 's',
  List<String> tags = const ['tag'],
  String original = '',
  String thumb = 'https://img.test/p.jpg',
}) {
  return PostSummary(
    id: id,
    serverId: 'test',
    thumbnailUrl: thumb,
    sampleUrl: '',
    originalUrl: original,
    tags: tags,
    aspectRatio: 1,
    width: 100,
    height: 100,
    rating: rating,
    score: 0,
  );
}

void main() {
  group('候选筛选', () {
    test('只留安全评级的非视频帖，且请求带上了安全评级', () async {
      final repo = _FakeRepo({
        'order:random|s': [
          _post('1'),
          _post('2', rating: 'e'),
          _post('3', rating: 'q'),
          _post('4', rating: 'g'),
          _post('5', original: 'https://img.test/v.mp4'),
          _post('6', rating: ''),
        ],
      });

      final posts = await fetchArtworkCandidates(repo);

      expect(posts.map((p) => p.id), ['1', '4']);
      expect(repo.queries.single.rating, kArtworkRating);
      expect(repo.queries.single.limit, greaterThan(1));
    });

    test('站点不支持 order:random（返回空）时退回默认排序', () async {
      final repo = _FakeRepo({
        'order:random|s': const [],
        '|s': [_post('7')],
      });

      final posts = await fetchArtworkCandidates(repo);

      expect(posts.map((p) => p.id), ['7']);
      expect(repo.queries.map((q) => q.tags), ['order:random', '']);
    });

    test('随机排序整批被过滤光时也要退回默认排序', () async {
      // 站点忽略了评级标签，order:random 回来一整页都是限制级：
      // 这时还去显示它才是错的，换默认排序再找一批安全图。
      final repo = _FakeRepo({
        'order:random|s': [_post('1', rating: 'e'), _post('2', rating: 'q')],
        '|s': [_post('3')],
      });

      final posts = await fetchArtworkCandidates(repo);

      expect(posts.map((p) => p.id), ['3']);
    });

    test('第一次查询抛异常时换下一种查询', () async {
      final repo = _FakeRepo(
        {'|s': [_post('9')]},
        throwOn: {'order:random|s'},
      );

      final posts = await fetchArtworkCandidates(repo);

      expect(posts.map((p) => p.id), ['9']);
    });

    test('两种查询都拿不到合格候选时返回空列表（UI 回落主题渐变）', () async {
      // 注意这是"两轮都拿不到"：第一轮安全口径被过滤光，第二轮（放开评级）
      // 这个假仓库也没有配任何数据，所以确实为空。
      final repo = _FakeRepo({
        'order:random|s': [_post('1', rating: 'e')],
        '|s': const [],
      });

      expect(await fetchArtworkCandidates(repo), isEmpty);
    });

    test('站点上没有任何「正常向」内容时，用站点自己的缩略图兜底', () async {
      // 用户实测："左侧栏的图片点不进去"——当时在用视频站：第一轮
      // （安全 + 非视频）恒为空，头图退化成点不动的渐变。第二轮放开评级
      // 并允许视频帖（封面仍是图片），头图才有东西可点。
      final videoPost = _post(
        'video',
        rating: 'e',
        thumb: 'https://img.test/thumb.jpg',
        original: 'https://img.test/v.mp4',
      );
      final repo = _FakeRepo({
        'order:random|s': const [],
        '|s': const [],
        'order:random|-': [videoPost],
      });

      final posts = await fetchArtworkCandidates(repo);
      expect(posts.map((p) => p.id), ['video'],
          reason: '第二轮应当拿到视频站自己的缩略图');
      expect(posts.first.thumbnailUrl, isNotEmpty);
    });

    test('有正常向内容时不会为了凑数去问第二轮', () async {
      final repo = _FakeRepo({
        'order:random|s': [_post('safe')],
        'order:random|-': [_post('unsafe', rating: 'e')],
      });

      final posts = await fetchArtworkCandidates(repo);
      expect(posts.map((p) => p.id), ['safe']);
      expect(repo.queries.any((q) => q.rating == null), isFalse,
          reason: '第一轮有结果就不该放宽口径');
    });

    test('评级取值按引擎口径放行 safe/general，其余一律拒绝', () {
      for (final ok in ['s', 'S', 'safe', 'g', 'GENERAL', ' general ']) {
        expect(isSafeRating(ok), isTrue, reason: ok);
      }
      for (final bad in ['e', 'explicit', 'q', 'questionable', '', 'unknown']) {
        expect(isSafeRating(bad), isFalse, reason: bad);
      }
    });
  });

  group('SiteArtwork', () {
    /// 假黑名单仓库：直接给一份固定结果。
    ///
    /// 不用真仓库是因为它读 Hive：在 `testWidgets` 的假异步时钟里，
    /// 真实文件 I/O（Hive 落盘）永远等不到完成回调，测试会一直挂住。
    /// 这里只需要「有一份屏蔽列表」这个前提，没必要真落盘。
    ProviderContainer newContainer({Map<int, BooruTag> blocked = const {}}) {
      final container = ProviderContainer(overrides: [
        tagsBlockerRepoProvider.overrideWithValue(_FakeBlockerRepo(blocked)),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    Future<void> pumpArtwork(
      WidgetTester tester,
      ProviderContainer container, {
      BooruRepository? repo,
      void Function(PostSummary)? onTap,
    }) async {
      if (repo != null) {
        await container.read(booruPageStateProvider.notifier).switchServer(repo);
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 176,
                child: SiteArtwork(onTap: onTap),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('点整张头图回调的就是当前显示的那张帖子', (tester) async {
      final repo = _FakeRepo({
        'order:random|s': [_post('1'), _post('2'), _post('3')],
      });
      PostSummary? tappedPost;

      await pumpArtwork(
        tester,
        newContainer(),
        repo: repo,
        onTap: (post) => tappedPost = post,
      );
      // 图片地址在测试环境必然加载失败（会顺移下一张），等它稳定下来。
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SiteArtwork));
      await tester.pump();

      // 必须是候选里的某一张，且点一次就给到具体帖子：调用方一次跳转就够，
      // 不需要再自己从整批候选里找下标。
      expect(['1', '2', '3'], contains(tappedPost?.id));
      expect(tappedPost?.rating, 's');
    });

    testWidgets('黑名单里的标签不会出现在头图候选里', (tester) async {
      final repo = _FakeRepo({
        'order:random|s': [
          _post('1', tags: const ['spoiler']),
          _post('2'),
        ],
      });
      PostSummary? tappedPost;

      await pumpArtwork(
        tester,
        newContainer(blocked: {0: const BooruTag(serverId: '', name: 'spoiler')}),
        repo: repo,
        onTap: (post) => tappedPost = post,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SiteArtwork));
      await tester.pump();

      expect(tappedPost?.id, '2');
    });

    testWidgets('候选全被黑名单挡掉时回落渐变，且不再可点', (tester) async {
      final repo = _FakeRepo({
        'order:random|s': [_post('1', tags: const ['spoiler'])],
      });
      var tapped = false;

      await pumpArtwork(
        tester,
        newContainer(blocked: {0: const BooruTag(serverId: '', name: 'spoiler')}),
        repo: repo,
        onTap: (_) => tapped = true,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SiteArtwork));
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('站点作用域的黑名单只在该站点生效（头图不再被别站的屏蔽影响）',
        (tester) async {
      // 第 2 轮曾把「只看标签名、不看作用域」钉成现状，并注明：站点作用域
      // （OPT §6.4）落地时这条会失败，且失败是有意的。这里就是那次「有意
      // 失败」的兑现：换成新口径，并同时验两个方向。
      final repo = _FakeRepo({
        'order:random|s': [_post('1', tags: const ['spoiler'])],
      });
      var tapped = false;

      // 1) 屏蔽条目属于**别的**站点 → 本站头图照常显示、可点
      await pumpArtwork(
        tester,
        newContainer(
            blocked: {5: const BooruTag(serverId: 'another-server', name: 'spoiler')}),
        repo: repo,
        onTap: (_) => tapped = true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SiteArtwork));
      await tester.pump();
      expect(tapped, isTrue,
          reason: '只在别的站屏蔽 spoiler，本站头图不该被挡');
    });

    testWidgets('站点作用域＝当前站点（或全局）时头图仍然被挡', (tester) async {
      final repo = _FakeRepo({
        'order:random|s': [_post('1', tags: const ['spoiler'])],
      });
      var tapped = false;

      // 当前活动站点的 serverId 是 'test'（见 _FakeRepo.serverId）
      await pumpArtwork(
        tester,
        newContainer(
            blocked: {5: const BooruTag(serverId: 'test', name: 'spoiler')}),
        repo: repo,
        onTap: (_) => tapped = true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SiteArtwork));
      await tester.pump();
      expect(tapped, isFalse, reason: '作用域命中当前站点时必须挡掉');
    });

    testWidgets('没有站点时不请求站点接口，也不可点（回落主题渐变）', (tester) async {
      var tapped = false;
      // 不接仓库 = 没有活动站点。此时头图必须是死的装饰，
      // 而不是拿着空站点去请求。
      await pumpArtwork(
        tester,
        newContainer(),
        onTap: (_) => tapped = true,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SiteArtwork));
      await tester.pump();

      expect(tapped, isFalse);
    });
  });
}
