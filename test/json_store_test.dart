import 'dart:convert';
import 'dart:io';

import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/database/json_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tempDir;
  late Box box;

  setUp(() async {
    JsonListStore.resetForTest();
    tempDir = Directory.systemTemp.createTempSync('boorunova_json_store');
    Hive.init(tempDir.path);
    box = await Hive.openBox(HiveSetup.settingsBoxName);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    tempDir.deleteSync(recursive: true);
  });

  JsonListStore store([String key = 'k']) => JsonListStore(box, key);

  group('JsonListStore', () {
    test('写入是带版本的封套，读到裸数组（v1）也能升级', () async {
      await store().write([
        {'id': '1'},
      ]);
      final raw = jsonDecode(box.get('k') as String) as Map<String, dynamic>;
      expect(raw['_v'], JsonListStore.schemaVersion);
      expect((raw['items'] as List).length, 1);

      // 老数据：裸数组
      await box.put('k', jsonEncode([
        {'id': 'old'},
      ]));
      expect(store().read().single['id'], 'old');

      // 写一次即升级为封套，且内容不丢
      await store().write(store().read());
      final upgraded = jsonDecode(box.get('k') as String) as Map<String, dynamic>;
      expect(upgraded['_v'], JsonListStore.schemaVersion);
      expect(((upgraded['items'] as List).single as Map)['id'], 'old');
    });

    test('损坏值被隔离留证，且本进程拒绝再覆盖写入', () async {
      await box.put('k', '{ 这不是 JSON');

      expect(store().read(), isEmpty);
      // 原始值必须还在（改名到 __corrupt），这是"损坏不等于丢数据"的全部意义
      expect(box.get('k__corrupt'), '{ 这不是 JSON');
      expect(box.get('k'), isNull);
      expect(store().corrupted, isTrue);

      // 拒绝写入：已隔离的数据不该被一次 add 直接抹掉
      expect(() => store().write([{'id': 'new'}]), throwsStateError);
    });

    test('单条畸形元素跳过，其余照常读出', () async {
      await box.put(
        'k',
        jsonEncode({
          '_v': 2,
          'items': [
            {'id': 'ok1'},
            'not-a-map',
            {'id': 'ok2'},
          ],
        }),
      );
      expect(store().read().map((e) => e['id']), ['ok1', 'ok2']);
      expect(store().corrupted, isFalse);
    });

    test('版本比自己新时不动数据（防降级写坏）', () async {
      final future = jsonEncode({
        '_v': JsonListStore.schemaVersion + 1,
        'items': [
          {'id': 'from-newer-app'},
        ],
      });
      await box.put('k', future);

      expect(store().read(), isEmpty);
      expect(store().corrupted, isTrue);
      expect(box.get('k__corrupt'), future);
      expect(() => store().write([{'id': 'x'}]), throwsStateError);
    });

    test('并发 update 不丢更新（此前各自读-改-写会互相覆盖）', () async {
      final s = store();
      await s.write(const []);

      // 20 个并发追加：每个事务在队列里读到的是上一个事务写完的值
      await Future.wait([
        for (var i = 0; i < 20; i++)
          s.update((items) => [...items, {'id': '$i'}]),
      ]);

      final ids = s.read().map((e) => e['id']).toSet();
      expect(ids.length, 20, reason: '并发写入不该互相覆盖');
    });

    test('队列不会因为一次失败而卡死', () async {
      final s = store();
      await s.write([
        {'id': 'base'},
      ]);
      await s.update((items) => [...items, {'id': 'a'}]);
      // 一次抛错的事务
      await expectLater(
        s.update((items) => throw StateError('boom')),
        throwsStateError,
      );
      // 后续写入仍然能进行
      await s.update((items) => [...items, {'id': 'b'}]);
      expect(s.read().map((e) => e['id']), containsAll(['base', 'a', 'b']));
    });
  });
}
