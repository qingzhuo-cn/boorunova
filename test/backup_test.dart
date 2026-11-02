import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/data/repository/backup/backup_codec.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/data/repository/history/user_history_repo.dart';
import 'package:boorunova/data/repository/hosts/entity/host_entry.dart';
import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/tags_blocker/entity/booru_tag.dart';
import 'package:flutter_test/flutter_test.dart';

/// H6 的守卫：备份的**完整性 / 逐段容错 / 合并语义**。
///
/// 这三件事出错时用户丢的是数据，而且界面上只会显示「导入成功」。
void main() {
  BooruPost post(String id, {String serverId = 's1'}) => BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: 'https://x/$id.jpg',
        sampleUrl: '',
        originalUrl: '',
        tags: const [],
        aspectRatio: 1,
        width: 100,
        height: 100,
        rating: 's',
        score: 0,
      );

  DownloadEntry download(String postId, {String serverId = 's1'}) =>
      DownloadEntry(
        postId: postId,
        imageUrl: 'https://x/$postId.jpg',
        localPath: '/tmp/$postId.jpg',
        downloadedAt: DateTime(2026, 1, 1),
        serverId: serverId,
      );

  HistoryEntry history(String postId,
          {String serverId = 's1', required DateTime at}) =>
      HistoryEntry(
        postId: postId,
        serverId: serverId,
        thumbnailUrl: '',
        sampleUrl: '',
        originalUrl: '',
        tags: const [],
        width: 1,
        height: 1,
        rating: 's',
        score: 0,
        viewedAt: at,
      );

  group('导出封套完整性', () {
    test('八段内容全在，且不含凭据', () {
      final payload = buildBackupPayload(
        settings: const {'themeMode': 'dark'},
        servers: [
          BooruServer(
            id: 'srv1',
            name: 'S',
            baseUrl: 'https://x',
            type: BooruType.danbooru,
            apiKey: 'SECRET',
            createdAt: DateTime(2026),
          ),
        ],
        blockedTags: const [BooruTag(name: 'gore')],
        favorites: [post('1')],
        searchHistory: const ['cat'],
        downloads: [download('1')],
        history: [history('1', at: DateTime(2026))],
        hosts: const [HostEntry(domain: 'x.test', ip: '1.2.3.4')],
      );

      expect(payload['version'], kBackupSchemaVersion);
      final data = payload['data'] as Map<String, dynamic>;
      for (final key in const [
        kBackupSectionSettings,
        kBackupSectionServers,
        kBackupSectionBlockedTags,
        kBackupSectionFavorites,
        kBackupSectionSearchHistory,
        kBackupSectionDownloads,
        kBackupSectionHistory,
        kBackupSectionHosts,
      ]) {
        expect(data.containsKey(key), isTrue, reason: '缺段：$key');
      }
      // 凭据绝不出现在备份里
      expect(payload.toString().contains('SECRET'), isFalse);
    });

    test('黑名单的**站点作用域**随备份往返（不能被压成全局）', () {
      // 作用域是用户配置的一部分：备份/恢复后「只在 A 站屏蔽」必须还是只在
      // A 站。若序列化只写名字，恢复出来就变成全局屏蔽——用户会突然在别的
      // 站点丢内容，而且完全不知道为什么。
      final payload = buildBackupPayload(
        settings: const {},
        servers: const [],
        blockedTags: const [
          BooruTag(name: 'global_tag'),
          BooruTag(serverId: 'srv-a', name: 'scoped_tag'),
        ],
        favorites: const [],
        searchHistory: const [],
        downloads: const [],
        history: const [],
        hosts: const [],
      );

      final data = payload['data'] as Map<String, dynamic>;
      final raw = (data[kBackupSectionBlockedTags] as List).cast<Map>();
      final restored =
          raw.map((m) => BooruTag.fromJson(Map<String, dynamic>.from(m))).toList();

      expect(
        restored.map((t) => '${t.serverId}|${t.name}').toList(),
        ['|global_tag', 'srv-a|scoped_tag'],
        reason: '作用域必须随备份原样往返',
      );
    });

    test('版本过新必须拒绝', () {
      expect(isBackupVersionSupported(kBackupSchemaVersion), isTrue);
      expect(isBackupVersionSupported(kBackupSchemaVersion + 1), isFalse);
      expect(isBackupVersionSupported(null), isTrue, reason: '老备份没有版本字段');
      expect(isBackupVersionSupported('2'), isTrue,
          reason: '非数字按 v1 处理，不做激进拒绝');
    });
  });

  group('逐段容错', () {
    test('单条坏记录只跳过它自己，不中断整段', () {
      final stat = BackupMerger.favorites([
        post('keep'),
      ], [
        post('a').toJson(),
        'not a map',
        <int, dynamic>{1: 'x'}, // 键不是 String，Map.from 会抛
        {'id': 'tolerant'}, // 字段缺失但可宽容取值 → 算成功
        post('b').toJson(),
      ]);
      expect(stat.ok, 3);
      expect(stat.skipped, 2);
      expect(stat.total, 5);
      expect(stat.items.map((p) => p.id), ['keep', 'a', 'tolerant', 'b']);
    });
  });

  group('合并语义', () {
    test('收藏重复导入不翻倍（按 serverId|id）', () {
      final once = BackupMerger.favorites(const [], [post('1').toJson()]);
      final twice =
          BackupMerger.favorites(once.items, [post('1').toJson()]);
      expect(once.items, hasLength(1));
      expect(twice.items, hasLength(1));
    });

    test('不同站点的同号帖子是两条（此前只比 postId 会少导入）', () {
      final stat = BackupMerger.downloads(
        [download('7', serverId: 'a')],
        [download('7', serverId: 'b').toJson()],
      );
      expect(stat.items, hasLength(2));
    });

    test('搜索历史合并：现有条目不丢，重复不重复，保留 20 条', () {
      final existing = ['now1', 'now2'];
      final stat = BackupMerger.searchHistory(existing, [
        'now2',
        'old1',
        42,
        'old2',
      ]);
      expect(stat.items.take(3), ['now1', 'now2', 'old1']);
      expect(stat.items, contains('old2'));
      expect(stat.items.where((q) => q == 'now2'), hasLength(1));
      expect(stat.skipped, 1, reason: '非字符串元素只跳过自己');

      final many = BackupMerger.searchHistory(
          const [], [for (var i = 0; i < 30; i++) 'q$i']);
      expect(many.items, hasLength(20));
    });

    test('浏览历史合并：同帖保留较新的一条，按时间倒序，上限生效', () {
      final older = history('1', at: DateTime(2026, 1, 1));
      final newer = history('1', at: DateTime(2026, 5, 1));
      final stat = BackupMerger.history([newer], [
        older.toJson(),
        history('2', at: DateTime(2026, 3, 1)).toJson(),
      ], max: 200);
      expect(stat.items, hasLength(2));
      expect(stat.items.first.postId, '1');
      expect(stat.items.first.viewedAt, DateTime(2026, 5, 1),
          reason: '导入的旧记录不能覆盖本地较新的那条');

      final capped = BackupMerger.history(
        const [],
        [
          for (var i = 0; i < 5; i++)
            history('$i', at: DateTime(2026, 1, 1 + i)).toJson(),
        ],
        max: 3,
      );
      expect(capped.items, hasLength(3));
      expect(capped.items.first.postId, '4');
    });

    test('hosts 按 domain 合并，导入侧覆盖同域名', () {
      final stat = BackupMerger.hosts(
        const [HostEntry(domain: 'a.test', ip: '1.1.1.1')],
        const [HostEntry(domain: 'A.test', ip: '2.2.2.2')].map((e) => e.toJson()).toList(),
      );
      expect(stat.items, hasLength(1));
      expect(stat.items.single.ip, '2.2.2.2');
    });

    test('服务器按 id 合并，不产生重复条目', () {
      final server = BooruServer(
        id: 'srv1',
        name: 'S',
        baseUrl: 'https://x',
        type: BooruType.danbooru,
        createdAt: DateTime(2026),
      );
      final stat = BackupMerger.servers([server], [server.toJson()]);
      expect(stat.items, hasLength(1));
    });
  });
}
