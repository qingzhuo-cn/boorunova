import 'dart:io';

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/data/repository/server/credential_store.dart';
import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/server/entity/server_preferences.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/util/download_paths.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/screens/server/server_editor_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// 站点级偏好（§6.4）的守卫。
///
/// 三块最容易出错的地方：
/// 1. **安全模式不能被站点设置放宽**——否则「按站点配置」就是绕过 Play
///    合规默认的后门；
/// 2. 子目录的**路径越权**：`../` 或绝对路径会把文件写到应用目录之外；
/// 3. 改偏好**不该动凭据**（一次多余的写入/复核，或者更糟：误清空）。
BooruServer _server({
  String id = 's1',
  ServerPreferences preferences = const ServerPreferences(),
  String? apiKey,
}) =>
    BooruServer(
      id: id,
      name: 'site',
      baseUrl: 'https://site.test',
      type: BooruType.danbooru,
      apiKey: apiKey,
      createdAt: DateTime(2026, 1, 1),
      preferences: preferences,
    );

void main() {
  group('模型：宽容解析与消毒', () {
    test('未知取值按「未设置」处理，而不是显示一个不存在的档位', () {
      final prefs = ServerPreferences.fromJson(const {
        'visibleRating': 'x-rated',
        'downloadQuality': 'ultra',
      });
      expect(prefs.visibleRating, isNull);
      expect(prefs.downloadQuality, isNull);
      expect(prefs.isEmpty, isTrue);
    });

    test('已知取值正常解析', () {
      final prefs = ServerPreferences.fromJson(const {
        'visibleRating': 'q',
        'downloadQuality': 'sample',
        'downloadSubdir': 'dan',
      });
      expect(prefs.visibleRating, 'q');
      expect(prefs.downloadQuality, 'sample');
      expect(prefs.downloadSubdir, 'dan');
      expect(prefs.isNotEmpty, isTrue);
    });

    test('空偏好不写任何键（老记录的形态）', () {
      expect(const ServerPreferences().toJson(), isEmpty);
    });

    test('copyWith 的 clear 标志才真的能清空（null 表示「不改」）', () {
      const prefs = ServerPreferences(visibleRating: 'e', downloadQuality: 'sample');
      expect(prefs.copyWith().visibleRating, 'e');
      expect(prefs.copyWith(clearVisibleRating: true).visibleRating, isNull);
      expect(prefs.copyWith(clearDownloadQuality: true).downloadQuality, isNull);
      expect(prefs.copyWith(clearVisibleRating: true).downloadQuality, 'sample');
    });
  });

  group('子目录消毒（路径越权）', () {
    test('任何输入都不可能留下分隔符、.. 或纯点（越权不可能发生）', () {
      // 不变量比逐个举例更值钱：消毒的作用是让「拼出的路径」永远待在
      // 下载目录里面，所以真正要钉的是这条性质。
      for (final raw in <String>[
        '/etc',
        '..',
        '../..',
        '/',
        '...',
        r'C:\Windows',
        '.',
        'a/b',
        r'a\..\b',
        '  ../x  ',
        'x' * 100, // ignore: prefer_const_literals_to_create_immutables
      ]) {
        final safe = sanitizeSubdirName(raw);
        expect(safe.contains('/'), isFalse, reason: raw);
        expect(safe.contains(r'\'), isFalse, reason: raw);
        expect(safe.contains('..'), isFalse, reason: raw);
        expect(safe == '.', isFalse, reason: raw);
      }
    });

    test('纯点/纯斜杠输入退化成空，绝对路径被相对化后取第一层', () {
      // 「退化成空」= 用全局目录；这是最安全的结果。
      for (final unusable in const ['..', '../..', '/', '...', '.']) {
        expect(sanitizeSubdirName(unusable), '', reason: unusable);
      }
      // 绝对路径剥掉前导斜杠后就是一个安全的相对名（UI 侧会因为它与输入不
      // 一致而报错提示，不会静默存下别的东西）
      expect(sanitizeSubdirName('/etc'), 'etc');
      expect(sanitizeSubdirName('a/b'), 'a');
    });

    test('只取第一层，剥掉首尾斜杠与反斜杠', () {
      expect(sanitizeSubdirName(' danbooru '), 'danbooru');
      expect(sanitizeSubdirName('/danbooru/'), 'danbooru');
      expect(sanitizeSubdirName(r'a\b'), 'a');
      expect(sanitizeSubdirName('a/b'), 'a');
    });

    test('非法字符替换、超长截断，绝不抛错', () {
      expect(sanitizeSubdirName('a b*c'), 'a_b_c');
      expect(sanitizeSubdirName('中文站'), '中文站');
      expect(sanitizeSubdirName('x' * 100).length, 40);
    });

    test('模型存进来的值必然已经消毒过', () {
      final prefs = ServerPreferences.fromJson(const {'downloadSubdir': '../evil'});
      expect(prefs.downloadSubdir, '');
      expect(
        const ServerPreferences().copyWith(downloadSubdir: 'a/b').downloadSubdir,
        'a',
      );
    });
  });

  group('生效值：站点偏好 vs 全局 vs 安全模式', () {
    test('用户当次显式选的评级优先', () {
      expect(
        effectiveRatingForServer(
          settings: const AppSettings(safeMode: false),
          preferences: const ServerPreferences(visibleRating: 's'),
          chosen: 'e',
        ),
        'e',
      );
    });

    test('安全模式**不能**被站点偏好放宽（合规红线）', () {
      expect(
        effectiveRatingForServer(
          settings: const AppSettings(safeMode: true),
          preferences: const ServerPreferences(visibleRating: 'e'),
        ) as Object?,
        's',
        reason: '站点偏好写 e 也不能在安全模式下生效，否则就是绕过默认的后门',
      );
    });

    test('安全模式关闭时站点偏好生效', () {
      expect(
        effectiveRatingForServer(
          settings: const AppSettings(safeMode: false),
          preferences: const ServerPreferences(visibleRating: 'q'),
        ),
        'q',
      );
    });

    test('什么都没设 → 跟随全局（安全模式关则无评级）', () {
      expect(
        effectiveRatingForServer(
          settings: const AppSettings(safeMode: false),
          preferences: const ServerPreferences(),
        ),
        isNull,
      );
      expect(
        effectiveRatingForServer(
          settings: const AppSettings(safeMode: true),
          preferences: const ServerPreferences(),
        ),
        's',
      );
    });

    test('画质：站点覆盖优先，否则跟随全局', () {
      const global = AppSettings(downloadQuality: 'original');
      expect(downloadQualityFor(global, const ServerPreferences()), 'original');
      expect(
        downloadQualityFor(global, const ServerPreferences(downloadQuality: 'sample')),
        'sample',
      );
      const sampleGlobal = AppSettings(downloadQuality: 'sample');
      expect(
        downloadQualityFor(sampleGlobal, const ServerPreferences(downloadQuality: 'original')),
        'original',
        reason: '站点想存原图，就不该被全局的省流量设置压住',
      );
    });
  });

  group('偏好落盘：不碰凭据', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('boorunova_prefs');
      Hive.init(tempDir.path);
      await Hive.openBox(HiveSetup.settingsBoxName);
      await Hive.openBox(HiveSetup.serversBoxName);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      tempDir.deleteSync(recursive: true);
    });

    test('savePreferences 写进记录，且完全不动凭据存储', () async {
      final store = InMemoryCredentialStore();
      UserServerRepo.useCredentialStore(store);
      final repo = UserServerRepo();
      await repo.save(_server(apiKey: 'KEEP'));
      final before = store.entries['s1']!.apiKey;

      await repo.savePreferences('s1', const ServerPreferences(
        visibleRating: 'q',
        downloadSubdir: 'dan',
      ));

      expect(store.entries['s1']!.apiKey, before,
          reason: '改偏好不该重写凭据，更不该清掉它');
      final loaded = repo.getById('s1')!;
      expect(loaded.preferences.visibleRating, 'q');
      expect(loaded.preferences.downloadSubdir, 'dan');
      expect(loaded.apiKey, 'KEEP', reason: '读取路径仍要带凭据');
    });

    test('偏好随记录落盘，凭据依然不出现在 Hive 里', () async {
      UserServerRepo.useCredentialStore(InMemoryCredentialStore());
      final repo = UserServerRepo();
      await repo.save(_server(
        apiKey: 'SECRET',
        preferences: const ServerPreferences(visibleRating: 's'),
      ));

      final raw = HiveSetup.serversBox.get('s1') as String;
      expect(raw.contains('SECRET'), isFalse);
      expect(raw.contains('visibleRating'), isTrue,
          reason: '偏好不是机密，应当随记录落盘');
    });

    test('编辑器路径（save）不会丢掉已有偏好', () async {
      UserServerRepo.useCredentialStore(InMemoryCredentialStore());
      final repo = UserServerRepo();
      await repo.savePreferences('s1', const ServerPreferences(downloadSubdir: 'x'));
      // 站点此前不存在 → savePreferences 无操作；先建再改
      await repo.save(_server());
      await repo.savePreferences('s1', const ServerPreferences(downloadSubdir: 'x'));

      await repo.save(repo.getById('s1')!.copyWith(name: 'renamed'));

      expect(repo.getById('s1')!.preferences.downloadSubdir, 'x');
      expect(repo.getById('s1')!.name, 'renamed');
    });

    test('备份含偏好、不含凭据', () async {
      final server = _server(
        apiKey: 'SECRET',
        preferences: const ServerPreferences(
          visibleRating: 'q',
          downloadQuality: 'sample',
          downloadSubdir: 'dan',
        ),
      );
      final backup = server.toBackupJson();
      expect(backup.containsKey('apiKey'), isFalse);
      expect(backup['preferences'], isA<Map>());
      final restored = BooruServer.fromJson(backup);
      expect(restored.preferences.visibleRating, 'q');
      expect(restored.preferences.downloadSubdir, 'dan');
    });
  });

  group('下载目录拼接', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('boorunova_subdir');
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('子目录会被创建并用上', () async {
      final dir = await resolveDownloadDir(tempDir.path, subdir: 'danbooru');
      expect(dir.path, endsWith('danbooru'));
      expect(dir.existsSync(), isTrue);
    });

    test('非法子目录退回基目录（不失败、也不越权）', () async {
      final dir = await resolveDownloadDir(tempDir.path, subdir: '../etc');
      expect(dir.path, tempDir.path);
    });

    test('空子目录就是基目录本身', () async {
      final dir = await resolveDownloadDir(tempDir.path);
      expect(dir.path, tempDir.path);
    });
  });

  group('编辑器路径不得弄丢站点偏好（回归）', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('boorunova_edit_prefs');
      Hive.init(tempDir.path);
      await Hive.openBox(HiveSetup.settingsBoxName);
      await Hive.openBox(HiveSetup.serversBoxName);
      UserServerRepo.useCredentialStore(InMemoryCredentialStore());
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      tempDir.deleteSync(recursive: true);
    });

    test('按表单覆盖时，id / 创建时间 / 偏好都保留', () {
      // 之前编辑页是 create() + copyWith(id:)：不在表单里的字段会被重置，
      // 用户改一个地址就会丢掉站点偏好与创建时间。
      final original = BooruServer(
        id: 's1',
        name: 'old',
        baseUrl: 'https://old.test',
        type: BooruType.danbooru,
        createdAt: DateTime(2020, 5, 5),
        preferences: const ServerPreferences(
          visibleRating: 'q',
          downloadSubdir: 'dan',
        ),
      );

      final edited = original.withFormValues(
        name: 'new',
        baseUrl: 'https://new.test',
        type: BooruType.e621,
      );

      expect(edited.id, 's1');
      expect(edited.name, 'new');
      expect(edited.baseUrl, 'https://new.test');
      expect(edited.type, BooruType.e621);
      expect(edited.createdAt, DateTime(2020, 5, 5),
          reason: '创建时间不该被「编辑一下」改掉');
      expect(edited.preferences.visibleRating, 'q',
          reason: '站点偏好不在表单里，编辑后必须原样保留');
      expect(edited.preferences.downloadSubdir, 'dan');
    });

    test('表单清空凭据时确实能清掉（null 是合法输入）', () {
      final original = _server(apiKey: 'OLD');
      final edited = original.withFormValues(
        name: original.name,
        baseUrl: original.baseUrl,
        type: original.type,
      );
      expect(edited.apiKey, isNull,
          reason: 'copyWith 的 null 表示不改，所以编辑路径不能用它来清凭据');
    });

    test('走一遍仓库：编辑后偏好在库里还在', () async {
      final repo = UserServerRepo();
      await repo.save(_server(
        preferences: const ServerPreferences(visibleRating: 'e'),
      ));

      final current = repo.getById('s1')!;
      await repo.save(current.withFormValues(
        name: 'renamed',
        baseUrl: 'https://moved.test',
        type: BooruType.e621,
      ));

      final reloaded = repo.getById('s1')!;
      expect(reloaded.name, 'renamed');
      expect(reloaded.preferences.visibleRating, 'e');
    });
  });

  group('编辑器保存路径（回归：不得弄丢偏好）', () {
    test('editing 时以已有实体为起点：偏好与创建时间保留', () {
      // 真实 bug：编辑页曾经用 BooruServer.create(...) + copyWith(id:) 重建，
      // 不在表单里的字段被重置——改个地址就丢掉站点偏好。
      final existing = BooruServer(
        id: 's1',
        name: 'old',
        baseUrl: 'https://old.test',
        type: BooruType.danbooru,
        createdAt: DateTime(2020, 5, 5),
        preferences: const ServerPreferences(
          visibleRating: 'q',
          downloadQuality: 'sample',
          downloadSubdir: 'dan',
        ),
      );

      final saved = buildServerForSave(
        existing: existing,
        name: 'new',
        baseUrl: 'https://new.test',
        type: BooruType.e621,
      );

      expect(saved.id, 's1');
      expect(saved.name, 'new');
      expect(saved.baseUrl, 'https://new.test');
      expect(saved.type, BooruType.e621);
      expect(saved.createdAt, DateTime(2020, 5, 5));
      expect(saved.preferences.visibleRating, 'q');
      expect(saved.preferences.downloadQuality, 'sample');
      expect(saved.preferences.downloadSubdir, 'dan');
    });

    test('新增时就是新实体（默认无偏好）', () {
      final saved = buildServerForSave(
        name: 'n',
        baseUrl: 'https://n.test',
        type: BooruType.danbooru,
      );
      expect(saved.preferences.isEmpty, isTrue);
      expect(saved.id, isNotEmpty);
    });

    test('表单清空凭据能真的清掉（copyWith 做不到）', () {
      final existing = _server(apiKey: 'OLD', preferences: const ServerPreferences());
      final saved = buildServerForSave(
        existing: existing,
        name: existing.name,
        baseUrl: existing.baseUrl,
        type: existing.type,
      );
      expect(saved.apiKey, isNull,
          reason: 'null 是合法的「清空」输入，不能用 copyWith 的 null=不改 语义');
    });
  });

  group('站点不存在 / 导入合并的边界', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('boorunova_prefs_edge');
      Hive.init(tempDir.path);
      await Hive.openBox(HiveSetup.settingsBoxName);
      await Hive.openBox(HiveSetup.serversBoxName);
      UserServerRepo.useCredentialStore(InMemoryCredentialStore());
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      tempDir.deleteSync(recursive: true);
    });

    test('对已删除的站点写偏好：静默无操作，不抛错也不复活它', () async {
      final repo = UserServerRepo();
      await repo.savePreferences('ghost', const ServerPreferences(visibleRating: 'e'));

      expect(repo.getAll(), isEmpty);
      expect(HiveSetup.serversBox.get('ghost'), isNull);
    });

    test('导入带偏好的站点：偏好落库，凭据仍不被触碰', () async {
      final store = InMemoryCredentialStore();
      UserServerRepo.useCredentialStore(store);
      final repo = UserServerRepo();
      // 本地已有一个带 Key 的同 id 站点（备份导入会跳过它，这里直接验通道语义）
      await repo.save(_server(apiKey: 'KEEP'));

      await repo.saveImported(_server(
        preferences: const ServerPreferences(downloadSubdir: 'imported'),
      ));

      expect(store.entries['s1']!.apiKey, 'KEEP');
      expect(repo.getById('s1')!.preferences.downloadSubdir, 'imported');
    });

    test('偏好在 JSON 往返后完全一致（含清空后的形态）', () {
      const full = ServerPreferences(
        visibleRating: 'e',
        downloadQuality: 'sample',
        downloadSubdir: 'x',
      );
      expect(ServerPreferences.fromJson(full.toJson()), full);
      const empty = ServerPreferences();
      expect(ServerPreferences.fromJson(empty.toJson()), empty);
      expect(
        ServerPreferences.fromJson(const {}),
        const ServerPreferences(),
        reason: '老记录没有 preferences 键时就是「全部跟随全局」',
      );
    });
  });

  group('搜索页「全部」的语义（回归：不能落回站点默认）', () {
    test('选「全部」+ 站点默认安全档 → 不过滤（而不是被悄悄过滤）', () {
      expect(
        effectiveRatingForServer(
          settings: const AppSettings(safeMode: false),
          preferences: const ServerPreferences(visibleRating: 's'),
          chosen: kRatingAny,
        ),
        isNull,
        reason: '用户明确要「全部」，却拿到站点默认的安全档 = 选项骗人',
      );
    });

    test('选「全部」+ 安全模式开启 → 仍然只取安全档（合规优先）', () {
      expect(
        effectiveRatingForServer(
          settings: const AppSettings(safeMode: true),
          preferences: const ServerPreferences(),
          chosen: kRatingAny,
        ),
        's',
      );
    });

    test('没选（null）时才是「用默认」：站点偏好生效', () {
      expect(
        effectiveRatingForServer(
          settings: const AppSettings(safeMode: false),
          preferences: const ServerPreferences(visibleRating: 'e'),
        ),
        'e',
      );
    });
  });

  group('预览画质（§6.4 拆分预览与下载）', () {
    test('站点覆盖优先于全局', () {
      const global = AppSettings(previewQuality: 'sample');
      expect(previewQualityFor(global, const ServerPreferences()), 'sample');
      expect(
        previewQualityFor(
          global,
          const ServerPreferences(previewQuality: 'original'),
        ),
        'original',
        reason: '站点想预览原图，不该被全局的省流量设置压住',
      );
      expect(
        previewQualityFor(
          const AppSettings(previewQuality: 'original'),
          const ServerPreferences(previewQuality: 'sample'),
        ),
        'sample',
      );
    });

    test('全局默认是 sample（与此前 mediaUrlOf 的行为一致）', () {
      expect(const AppSettings().previewQuality, 'sample');
    });

    test('previewUrlOf：要原图且存在原图时给原图', () {
      const post = PostSummary(
        id: '1',
        serverId: 's',
        thumbnailUrl: 't.jpg',
        sampleUrl: 'sample.jpg',
        originalUrl: 'original.jpg',
        tags: [],
        aspectRatio: 1,
        width: 1,
        height: 1,
        rating: 's',
        score: 0,
      );
      expect(previewUrlOf(post, preferOriginal: true), 'original.jpg');
      expect(previewUrlOf(post, preferOriginal: false), 'sample.jpg');
      expect(mediaUrlOf(post), 'sample.jpg',
          reason: 'mediaUrlOf 永远优先 sample，所以「预览原图」必须走 previewUrlOf');
    });

    test('previewUrlOf：没有原图时退回 sample（不给出空地址）', () {
      const post = PostSummary(
        id: '1',
        serverId: 's',
        thumbnailUrl: 't.jpg',
        sampleUrl: 'sample.jpg',
        originalUrl: '',
        tags: [],
        aspectRatio: 1,
        width: 1,
        height: 1,
        rating: 's',
        score: 0,
      );
      expect(previewUrlOf(post, preferOriginal: true), 'sample.jpg');
    });

    test('偏好往返与宽容解析', () {
      const prefs = ServerPreferences(
        previewQuality: 'original',
        defaultSort: 'score',
      );
      expect(ServerPreferences.fromJson(prefs.toJson()), prefs);
      final bad = ServerPreferences.fromJson(const {
        'previewQuality': 'ultra',
        'defaultSort': 'order:score',
      });
      expect(bad.previewQuality, isNull, reason: '未知取值按未设置处理');
      expect(bad.defaultSort, isNull,
          reason: '偏好里存语义键，不接受元标签写法');
      expect(bad.isEmpty, isTrue);
    });

    test('clear 标志能清空新字段', () {
      const prefs = ServerPreferences(previewQuality: 'original', defaultSort: 'date');
      expect(prefs.copyWith(clearPreviewQuality: true).previewQuality, isNull);
      expect(prefs.copyWith(clearPreviewQuality: true).defaultSort, 'date');
      expect(prefs.copyWith(clearDefaultSort: true).defaultSort, isNull);
    });
  });

  group('站点默认排序（§6.4）', () {
    test('语义键 → 元标签的映射只有一处', () {
      expect(sortMetaTag('score'), 'order:score');
      expect(sortMetaTag('date'), 'order:date');
      expect(sortMetaTag('rating'), 'order:rating');
      expect(sortMetaTag(null), '');
      expect(sortMetaTag('nonsense'), '');
    });

    test('站点设了默认排序就用它，否则沿用搜索页当前选择', () {
      expect(
        effectiveSortForServer(
          preferences: const ServerPreferences(defaultSort: 'date'),
          current: 'order:score',
        ),
        'order:date',
      );
      expect(
        effectiveSortForServer(
          preferences: const ServerPreferences(),
          current: 'order:score',
        ),
        'order:score',
        reason: '没设默认时不该覆盖用户/页面已有的选择',
      );
      expect(
        effectiveSortForServer(
          preferences: const ServerPreferences(),
          current: '',
        ),
        '',
      );
    });
  });
}
