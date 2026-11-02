import 'dart:io';

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/provider/booru/tag_suggestions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// 可计数的假仓库：记录 suggestTags 调用次数与 query。
class _FakeRepo implements BooruRepository {
  _FakeRepo(this.serverId);

  @override
  final String serverId;

  @override
  Future<String?> resolveMediaUrl(String postUrl) async => null;

  @override
  Map<String, String> get mediaHeaders => const {};

  int suggestCalls = 0;
  final List<String> suggestQueries = [];
  final List<int> suggestLimits = [];

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async =>
      const BooruPageResult(posts: [], hasMore: false);

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    suggestCalls++;
    suggestQueries.add(query);
    suggestLimits.add(limit);
    return ['${query}_tag1', '${query}_tag2'];
  }

  @override
  Future<List<String>> fetchTrendingTags({int limit = 20}) async => [];

  @override
  Future<List<BooruPool>> fetchPools({int page = 1, int limit = 20}) async =>
      [];
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('boorunova_tag_suggest');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveSetup.settingsBoxName);
    // 模块级缓存跨用例保留，这里显式清掉，避免用例互相污染
    clearTagSuggestionCache();
  });

  tearDown(() async {
    try {
      await Hive.close();
    } catch (_) {}
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

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
  test('建议条数来自 AppSettings（不再是不持久化的内存 provider）', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repo = _FakeRepo('danbooru');
    await container.read(booruPageStateProvider.notifier).switchServer(repo);
    await container.read(settingsProvider.notifier).setTagSuggestionLimit(7);

    await container.read(tagSuggestionProvider(
            (serverId: 'danbooru', query: 'limit_probe'))
        .future);
    expect(repo.suggestLimits.last, 7);
    // 落盘：杀进程后不该回到 12
    final raw = HiveSetup.settingsBox.get('app_settings') as Map;
    expect(raw['tagSuggestionLimit'], 7);
  });

  test('缓存有上限：超过后淘汰最旧的一条', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repo = _FakeRepo('danbooru');
    await container.read(booruPageStateProvider.notifier).switchServer(repo);

    for (var i = 0; i < kTagSuggestionCacheMax + 5; i++) {
      await container.read(tagSuggestionProvider(
              (serverId: 'danbooru', query: 'q$i'))
          .future);
    }
    expect(tagSuggestionCacheSize, lessThanOrEqualTo(kTagSuggestionCacheMax),
        reason: '无上限的缓存会一直堆积，长会话里内存只增不减');
    expect(tagSuggestionCacheHas('danbooru', 12, 'q0'), isFalse,
        reason: '最旧的条目应被 LRU 淘汰');
    expect(
        tagSuggestionCacheHas(
            'danbooru', 12, 'q${kTagSuggestionCacheMax + 4}'),
        isTrue,
        reason: '最新条目必须在缓存里');
  });
}
