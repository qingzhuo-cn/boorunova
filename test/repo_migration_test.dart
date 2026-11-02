import 'dart:convert';
import 'dart:io';

import 'package:boorunova/data/repository/hosts/entity/host_entry.dart';
import 'package:boorunova/data/repository/hosts/user_hosts_repo.dart';
import 'package:boorunova/data/repository/search_history/search_history_repo.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/database/json_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// 搜索历史 / hosts 迁到 JsonListStore（OPT 4.1）后的守卫。
///
/// 这两处迁移最容易出的不是崩溃，而是**静默丢数据**：老格式是裸数组，
/// 而 JsonListStore 只认 Map 元素——不做一次原地转换，用户的历史会在
/// 第一次读取时凭空消失，并在下一次写入时被固化。
void main() {
  late Directory tempDir;
  late Box box;

  setUp(() async {
    JsonListStore.resetForTest();
    SearchHistoryRepo.resetForTest();
    tempDir = Directory.systemTemp.createTempSync('boorunova_repo_migration');
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

  group('SearchHistoryRepo 老格式迁移', () {
    test('裸字符串数组（老格式）读得出来，且不被当成空历史', () async {
      await box.put('search_history', jsonEncode(['old1', 'old2']));
      final repo = SearchHistoryRepo();
      expect(repo.getAll(), ['old1', 'old2']);
    });

    test('老格式下 add 不会把已有历史整键写没', () async {
      await box.put('search_history', jsonEncode(['old1', 'old2']));
      final repo = SearchHistoryRepo();
      await repo.add('new');
      expect(repo.getAll(), ['new', 'old1', 'old2']);
    });

    test('上限 20 且重复查询去重到最前', () async {
      final repo = SearchHistoryRepo();
      for (var i = 0; i < 25; i++) {
        await repo.add('q$i');
      }
      final all = repo.getAll();
      expect(all, hasLength(20));
      expect(all.first, 'q24');
      await repo.add('q10');
      expect(repo.getAll().first, 'q10');
      expect(repo.getAll().where((q) => q == 'q10'), hasLength(1));
    });

    test('并发 add 不丢更新（此前读-改-写会互相覆盖）', () async {
      final repo = SearchHistoryRepo();
      await Future.wait([
        for (var i = 0; i < 12; i++) repo.add('c$i'),
      ]);
      final all = repo.getAll();
      expect(all, hasLength(12));
      expect(all.toSet(), hasLength(12));
    });

    test('清除后为空，且不会复活老数据', () async {
      await box.put('search_history', jsonEncode(['old1']));
      final repo = SearchHistoryRepo();
      expect(repo.getAll(), ['old1']);
      await repo.clear();
      expect(repo.getAll(), isEmpty);
    });
  });

  group('UserHostsRepo 迁移与校验', () {
    test('裸数组老格式（List<Map>）读得出来', () async {
      await box.put(
        'hosts',
        jsonEncode([
          const HostEntry(domain: 'a.test', ip: '1.2.3.4').toJson(),
        ]),
      );
      final repo = UserHostsRepo();
      expect(repo.getAll(), hasLength(1));
      expect(repo.getAll().single.domain, 'a.test');
    });

    test('同域名 add 覆盖而不是堆积，且写入串行', () async {
      final repo = UserHostsRepo();
      await Future.wait([
        repo.add(const HostEntry(domain: 'a.test', ip: '1.1.1.1')),
        repo.add(const HostEntry(domain: 'b.test', ip: '2.2.2.2')),
        repo.add(const HostEntry(domain: 'a.test', ip: '3.3.3.3')),
      ]);
      final all = repo.getAll();
      expect(all, hasLength(2));
      expect(repo.getByDomain('a.test')?.ip, '3.3.3.3');
    });

    test('非法条目（单标签域名 / 非 IP）不落盘', () async {
      final repo = UserHostsRepo();
      await repo.add(const HostEntry(domain: 'com', ip: '1.2.3.4'));
      await repo.add(const HostEntry(domain: 'a.test', ip: 'not-an-ip'));
      expect(repo.getAll(), isEmpty);
      await repo.add(const HostEntry(domain: 'a.test', ip: '1.2.3.4'));
      await repo.replaceAll(const [
        HostEntry(domain: 'ok.test', ip: '5.6.7.8'),
        HostEntry(domain: 'com', ip: '1.2.3.4'),
      ]);
      expect(repo.getAll(), hasLength(1));
      expect(repo.getAll().single.domain, 'ok.test');
    });
  });
}
