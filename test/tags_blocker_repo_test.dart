import 'dart:convert';
import 'dart:io';

import 'package:boorunova/data/repository/tags_blocker/booru_tags_blocker_repo.dart';
import 'package:boorunova/data/repository/tags_blocker/entity/booru_tag.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/database/json_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// 黑名单仓库单测（审查第 4 节点名的测试空白之一）。
///
/// 要点是**键的稳定性**与**老数据可删**：此前键是列表下标，每次载入按位置
/// 重建，任何一次增删都会让 UI 手里那个 key 指向另一个标签——`delete(key)`
/// 删错人，用户点 A 删掉 B。
void main() {
  late Directory tempDir;
  late Box box;

  setUp(() async {
    JsonListStore.resetForTest();
    tempDir = Directory.systemTemp.createTempSync('boorunova_blocker');
    Hive.init(tempDir.path);
    box = await Hive.openBox(HiveSetup.settingsBoxName);
  });

  tearDown(() async {
    try {
      await Hive.deleteFromDisk();
    } catch (_) {}
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('push 之后键是稳定的（新实例读到的 key 不变）', () async {
    await BooruTagsBlockerRepo().pushAll(tags: ['gore', 'spoiler']);
    final first = BooruTagsBlockerRepo().getAll();
    final second = BooruTagsBlockerRepo().getAll();
    expect(first.keys.toList()..sort(), second.keys.toList()..sort());
    expect(first.values.map((t) => t.name).toSet(), {'gore', 'spoiler'});
  });

  test('按稳定键删除删的是那一条，不是同位置的下标', () async {
    final repo = BooruTagsBlockerRepo();
    await repo.pushAll(tags: ['a', 'b', 'c']);
    final all = repo.getAll();
    final keyOfB = all.entries.firstWhere((e) => e.value.name == 'b').key;

    await repo.delete(keyOfB);

    expect(repo.getAll().values.map((t) => t.name).toSet(), {'a', 'c'});
  });

  test('同一作用域内名称去重；不同作用域是两条', () async {
    // 口径在「站点作用域」落地时**有意改变**：此前只按名字去重，于是
    // 「先全局屏蔽 gore，再想只在 X 站屏蔽 gore」会被静默吞掉。现在去重键
    // 是 (作用域, 名字)，所以不同作用域各留一条。
    final repo = BooruTagsBlockerRepo();
    await repo.pushAll(tags: ['gore']);
    await repo.pushAll(tags: ['gore']);
    expect(repo.getAll(), hasLength(1), reason: '同作用域同名字不重复');

    await repo.push(const BooruTag(serverId: 'x', name: 'gore'));
    expect(repo.getAll(), hasLength(2),
        reason: '站点作用域是独立的一条，不能被全局那条吞掉');
  });

  test('空名与纯空白被忽略', () async {
    final repo = BooruTagsBlockerRepo();
    await repo.pushAll(tags: ['', '   ', 'ok']);
    expect(repo.getAll().values.map((t) => t.name).toList(), ['ok']);
  });

  test('serverId 会被记录（作用域过滤的输入）', () async {
    final repo = BooruTagsBlockerRepo();
    await repo.pushAll(serverId: 'danbooru', tags: ['gore']);
    await repo.pushAll(tags: ['global']);

    final tags = repo.getAll().values.toList();
    expect(tags.firstWhere((t) => t.name == 'gore').serverId, 'danbooru');
    expect(tags.firstWhere((t) => t.name == 'global').serverId, isEmpty);
    // getBlockedTagNames 的空 serverId 条目对所有站点生效
    expect(repo.getBlockedTagNames(serverId: 'e621'), contains('global'));
    expect(repo.getBlockedTagNames(serverId: 'e621'), isNot(contains('gore')));
  });

  test('去重键含作用域：同名标签的全局条目与站点条目可以共存', () async {
    // 只按名字去重的话，「先全局屏蔽 cat，再想只在 A 站屏蔽 cat」会被静默
    // 吞掉——用户以为加上了，实际什么都没发生。
    final repo = BooruTagsBlockerRepo();
    await repo.pushAll(tags: ['cat']);
    await repo.pushAll(serverId: 'a', tags: ['cat']);
    await repo.pushAll(serverId: 'b', tags: ['cat']);

    final tags = repo.getAll().values.toList();
    expect(tags, hasLength(3), reason: '三个不同作用域各一条');
    expect(
      tags.map((t) => '${t.serverId}|${t.name}').toSet(),
      {'|cat', 'a|cat', 'b|cat'},
    );

    // 同一个 (作用域, 名字) 再推一次不产生重复
    await repo.pushAll(serverId: 'a', tags: ['cat']);
    expect(repo.getAll(), hasLength(3));
  });

  test('老格式（裸标签 + 下标键）能读出、能删、并在写入后升级', () async {
    // 老格式：数组里直接是 BooruTag 的 JSON，没有 _key。
    await box.put(
      'blocked_tags',
      jsonEncode([
        const BooruTag(serverId: '', name: 'old1').toJson(),
        const BooruTag(serverId: '', name: 'old2').toJson(),
      ]),
    );
    final repo = BooruTagsBlockerRepo();
    final all = repo.getAll();
    expect(all.values.map((t) => t.name).toSet(), {'old1', 'old2'});

    // 老数据的键按下标补齐（1 基），所以按键删除必须能删掉
    final keyOld1 =
        all.entries.firstWhere((e) => e.value.name == 'old1').key;
    await repo.delete(keyOld1);
    expect(repo.getAll().values.map((t) => t.name).toList(), ['old2']);

    // 写入后应是带 _key 的新格式
    final raw = jsonDecode(box.get('blocked_tags') as String) as Map;
    final items = raw['items'] as List;
    expect(items, hasLength(1));
    expect((items.single as Map)['_key'], isNotNull);
  });

  test('并发 pushAll 不丢条目（各自读-改-写会互相覆盖）', () async {
    final repo = BooruTagsBlockerRepo();
    await Future.wait([
      repo.pushAll(tags: ['t1', 't2']),
      repo.pushAll(tags: ['t3']),
      repo.pushAll(tags: ['t4', 't5']),
    ]);
    expect(repo.getAll().values.map((t) => t.name).toSet(),
        {'t1', 't2', 't3', 't4', 't5'});
  });
}
