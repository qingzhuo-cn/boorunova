import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/provider/booru/tag_suggestions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 可计数的假仓库：记录 suggestTags 调用次数与 query。
class _FakeRepo implements BooruRepository {
  _FakeRepo(this.serverId);

  @override
  final String serverId;

  int suggestCalls = 0;
  final List<String> suggestQueries = [];

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async =>
      const BooruPageResult(posts: [], hasMore: false);

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    suggestCalls++;
    suggestQueries.add(query);
    return ['${query}_tag1', '${query}_tag2'];
  }

  @override
  Future<List<String>> fetchTrendingTags({int limit = 20}) async => [];

  @override
  Future<List<BooruPool>> fetchPools({int page = 1, int limit = 20}) async =>
      [];
}

void main() {
  test('缓存生效：同一站点同一 query 只请求一次', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repo = _FakeRepo('danbooru');
    await container.read(booruPageStateProvider.notifier).switchServer(repo);

    Future<List<String>> fetch() => container
        .read(tagSuggestionProvider((serverId: 'danbooru', query: 'cache_probe'))
            .future);

    final r1 = await fetch();
    final r2 = await fetch();

    expect(r1, ['cache_probe_tag1', 'cache_probe_tag2']);
    expect(r2, r1);
    // 第二次 read 命中模块级缓存，不再请求
    expect(repo.suggestCalls, 1);
  });

  test('跨站点隔离：同 query 不同 serverId 各自请求', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repoA = _FakeRepo('danbooru');
    await container.read(booruPageStateProvider.notifier).switchServer(repoA);
    final rA = await container.read(
        tagSuggestionProvider((serverId: 'danbooru', query: 'iso_probe'))
            .future);

    final repoB = _FakeRepo('e621');
    await container.read(booruPageStateProvider.notifier).switchServer(repoB);
    final rB = await container.read(
        tagSuggestionProvider((serverId: 'e621', query: 'iso_probe')).future);

    expect(rA, isNotEmpty);
    expect(rB, isNotEmpty);
    // 两个站点各自请求了一次（family 参数含 serverId，不串）
    expect(repoA.suggestCalls, 1);
    expect(repoB.suggestCalls, 1);
  });

  test('空 query 返回空列表且不请求', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repo = _FakeRepo('danbooru');
    await container.read(booruPageStateProvider.notifier).switchServer(repo);

    final r = await container.read(
        tagSuggestionProvider((serverId: 'danbooru', query: '')).future);

    expect(r, isEmpty);
    expect(repo.suggestCalls, 0);
  });

  test('无 repository 时返回空列表且不抛异常', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final r = await container.read(tagSuggestionProvider(
            (serverId: 'danbooru', query: 'anything'))
        .future);

    expect(r, isEmpty);
  });
}
