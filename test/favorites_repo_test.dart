import 'dart:io';

import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:boorunova/data/repository/favorites/user_favorite_repo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

BooruPost _post(String id, {String serverId = 'danbooru'}) => BooruPost(
      id: id,
      serverId: serverId,
      thumbnailUrl: 't',
      sampleUrl: 's',
      originalUrl: 'o',
      tags: const ['tag'],
      aspectRatio: 1.0,
      width: 100,
      height: 100,
      rating: 's',
      score: 1,
    );

void main() {
  late Directory tempDir;

  setUp(() async {
    // 绕过 path_provider，直接指向临时目录
    tempDir = Directory.systemTemp.createTempSync('boorunova_fav_test');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
    await Hive.openBox('servers');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    tempDir.deleteSync(recursive: true);
  });

  group('UserFavoritesRepo', () {
    test('toggle 添加后 isFavorite 为 true，再 toggle 移除', () async {
      final repo = UserFavoritesRepo();
      final post = _post('100');

      expect(repo.isFavorite('100', serverId: 'danbooru'), isFalse);

      await repo.toggle(post);
      expect(repo.isFavorite('100', serverId: 'danbooru'), isTrue);
      expect(repo.count, 1);

      await repo.toggle(post);
      expect(repo.isFavorite('100', serverId: 'danbooru'), isFalse);
      expect(repo.count, 0);
    });

    test('跨站点隔离：同 id 不同 serverId 不冲突', () async {
      final repo = UserFavoritesRepo();
      await repo.toggle(_post('42', serverId: 'danbooru'));

      expect(repo.isFavorite('42', serverId: 'danbooru'), isTrue);
      expect(repo.isFavorite('42', serverId: 'e621'), isFalse);
    });

    test('remove 只删指定站点条目', () async {
      final repo = UserFavoritesRepo();
      await repo.toggle(_post('7', serverId: 'danbooru'));
      await repo.toggle(_post('7', serverId: 'e621'));

      await repo.remove('7', serverId: 'danbooru');

      expect(repo.isFavorite('7', serverId: 'danbooru'), isFalse);
      expect(repo.isFavorite('7', serverId: 'e621'), isTrue);
    });

    test('getAll 返回不可变视图，修改会抛异常', () async {
      final repo = UserFavoritesRepo();
      await repo.toggle(_post('1'));

      final all = repo.getAll();
      expect(all, hasLength(1));
      expect(() => all.add(_post('2')), throwsUnsupportedError);
    });

    test('saveAll 整体覆盖并持久化', () async {
      final repo = UserFavoritesRepo();
      await repo.toggle(_post('old'));

      await repo.saveAll([_post('new1'), _post('new2')]);

      expect(repo.count, 2);
      expect(repo.isFavorite('old', serverId: 'danbooru'), isFalse);
      expect(repo.isFavorite('new1', serverId: 'danbooru'), isTrue);
      expect(repo.isFavorite('new2', serverId: 'danbooru'), isTrue);
    });

    test('新实例从 Hive 惰性重载（invalidate 后数据不丢）', () async {
      final repo1 = UserFavoritesRepo();
      await repo1.toggle(_post('persisted'));

      // 模拟 ref.invalidate：新实例（空缓存）首次访问应从 Hive 读回
      final repo2 = UserFavoritesRepo();
      expect(repo2.isFavorite('persisted', serverId: 'danbooru'), isTrue);
      expect(repo2.count, 1);
    });
  });
}
