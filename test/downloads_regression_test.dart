import 'dart:io';

import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/util/download_paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

DownloadEntry _entry(String id) => DownloadEntry(
      postId: id,
      imageUrl: 'https://example.test/$id.jpg',
      localPath: '/tmp/$id.jpg',
      downloadedAt: DateTime.now(),
    );

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('boorunova_download_test');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveSetup.settingsBoxName);
    await Hive.openBox(HiveSetup.serversBoxName);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    tempDir.deleteSync(recursive: true);
  });

  test('concurrent history writes retain every entry', () async {
    final repo = UserDownloadsRepo();
    await Future.wait([
      repo.add(_entry('1')),
      UserDownloadsRepo().add(_entry('2')),
      UserDownloadsRepo().add(_entry('3')),
    ]);

    // 无序全等而不是 containsAll：后者对「多出一条重复记录」也会通过，
    // 而重复条目正是这段并发写要防的回归。
    final ids = repo.getAll().map((e) => e.postId).toList()..sort();
    expect(ids, <String>['1', '2', '3']);
  });

  test('namespaces prevent same post id collisions across sites', () {
    final first = uniqueFileName(
      'https://one.test/images/42.jpg',
      postId: '42',
      namespace: 'one',
    );
    final second = uniqueFileName(
      'https://two.test/images/42.jpg',
      postId: '42',
      namespace: 'two',
    );

    expect(first, isNot(second));
  });
}
