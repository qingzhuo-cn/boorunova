import 'dart:convert';
import 'dart:io';

import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/data/repository/server/credential_store.dart';
import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// 写入成功但读不回来的存储（个别设备的 Keystore 会这样静默失败）。
class _SilentStore implements CredentialStore {
  @override
  Future<ServerCredentials?> read(String serverId) async => null;

  @override
  Future<void> write(String serverId, ServerCredentials credentials) async {}

  @override
  Future<void> delete(String serverId) async {}

  @override
  Future<Set<String>> ids() async => const {};
}

/// 完全不可用的存储（设备策略 / 密钥失效）。
class _BrokenStore implements CredentialStore {
  @override
  Future<ServerCredentials?> read(String serverId) async =>
      throw StateError('keystore unavailable');

  @override
  Future<void> write(String serverId, ServerCredentials credentials) async =>
      throw StateError('keystore unavailable');

  @override
  Future<void> delete(String serverId) async {}

  @override
  Future<Set<String>> ids() async => throw StateError('keystore unavailable');
}

BooruServer _server({
  required String id,
  String? apiKey,
  String? login,
}) =>
    BooruServer(
      id: id,
      name: 'site-$id',
      baseUrl: 'https://$id.test',
      type: BooruType.danbooru,
      apiKey: apiKey,
      login: login,
      createdAt: DateTime(2026, 1, 1),
    );

String _legacyRecord({
  required String id,
  String? apiKey,
  String? login,
}) =>
    jsonEncode({
      'id': id,
      'name': 'site-$id',
      'baseUrl': 'https://$id.test',
      'type': BooruType.danbooru.value,
      if (apiKey != null) 'apiKey': apiKey,
      if (login != null) 'login': login,
      'createdAt': DateTime(2026, 1, 1).toIso8601String(),
    });

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('boorunova_credentials');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveSetup.settingsBoxName);
    await Hive.openBox(HiveSetup.serversBoxName);
    // 默认用内存实现：用例自己决定要不要换平台实现
    UserServerRepo.useCredentialStore(InMemoryCredentialStore());
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    tempDir.deleteSync(recursive: true);
  });

  group('SecureCredentialStore（平台安全存储）', () {
    setUp(() {
      FlutterSecureStoragePlatform.instance =
          TestFlutterSecureStoragePlatform({});
    });

    test('写入后能读回，且按站点隔离', () async {
      final store = SecureCredentialStore();
      await store.write(
          'a', const ServerCredentials(login: 'u1', apiKey: 'k1'));
      await store.write(
          'b', const ServerCredentials(login: 'u2', apiKey: 'k2'));

      expect((await store.read('a'))!.apiKey, 'k1');
      expect((await store.read('a'))!.login, 'u1');
      expect((await store.read('b'))!.apiKey, 'k2');
      expect(await store.read('c'), isNull, reason: '没写过就是 null');
    });

    test('删除会清掉两个键，不留残留机密', () async {
      final data = <String, String>{};
      FlutterSecureStoragePlatform.instance =
          TestFlutterSecureStoragePlatform(data);
      final store = SecureCredentialStore();
      await store.write(
          'a', const ServerCredentials(login: 'u1', apiKey: 'k1'));
      expect(data, isNotEmpty);

      await store.delete('a');

      expect(await store.read('a'), isNull);
      expect(data, isEmpty);
    });
  });

  group('保存不再把凭据写进 Hive', () {
    test('save() 落盘的 JSON 不含 apiKey / login，但读取仍能拿到', () async {
      final store = InMemoryCredentialStore();
      UserServerRepo.useCredentialStore(store);
      final repo = UserServerRepo();

      await repo.save(_server(
        id: 's1',
        apiKey: 'SECRET-KEY',
        login: 'SECRET-USER',
      ));

      final raw = HiveSetup.serversBox.get('s1') as String;
      expect(raw.contains('SECRET-KEY'), isFalse,
          reason: 'API Key 不能出现在 Hive 明文里（加固的全部意义）');
      expect(raw.contains('SECRET-USER'), isFalse);
      expect(raw.contains('apiKey'), isFalse);

      expect(store.entries['s1']!.apiKey, 'SECRET-KEY',
          reason: '凭据应当进了安全存储');

      // 读取路径（同步）必须还能拿到凭据，否则第一次请求会未认证
      expect(repo.getAll().single.apiKey, 'SECRET-KEY');
      expect(repo.getById('s1')!.login, 'SECRET-USER');
    });

    test('清空凭据保存 → 安全存储与内存镜像一并清除', () async {
      final store = InMemoryCredentialStore();
      UserServerRepo.useCredentialStore(store);
      final repo = UserServerRepo();

      await repo.save(_server(
        id: 's1',
        apiKey: 'K',
      ));
      expect(store.entries, isNotEmpty);

      await repo.save(_server(id: 's1'));

      expect(store.entries, isEmpty);
      expect(repo.getAll().single.apiKey, isNull);
    });

    test('删除站点会连安全存储里的凭据一起删', () async {
      final store = InMemoryCredentialStore();
      UserServerRepo.useCredentialStore(store);
      final repo = UserServerRepo();
      await repo.save(_server(id: 's1', apiKey: 'K'));

      await repo.delete('s1');

      expect(store.entries, isEmpty,
          reason: '站点删了却留着它的 API Key = 永久残留机密');
      expect(repo.getAll(), isEmpty);
    });

    test('备份导出继续不含凭据', () async {
      final server = _server(id: 's1', apiKey: 'K', login: 'U');
      final backup = server.toBackupJson();
      expect(backup.containsKey('apiKey'), isFalse);
      expect(backup.containsKey('login'), isFalse);
      // 落盘出口同理：连键都不出现，而不是写成 null
      expect(server.toStoredJson().containsKey('apiKey'), isFalse);
      expect(server.toStoredJson().containsKey('login'), isFalse);
    });
  });

  group('一次性迁移：旧明文 → 安全存储', () {
    test('搬进安全存储、从 Hive 抹掉，读取仍然可用', () async {
      await HiveSetup.serversBox.put(
          's1', _legacyRecord(id: 's1', apiKey: 'OLD-KEY', login: 'OLD-USER'));
      final store = InMemoryCredentialStore();
      UserServerRepo.useCredentialStore(store);

      await UserServerRepo.initCredentials();

      expect(store.entries['s1']!.apiKey, 'OLD-KEY');
      final raw = HiveSetup.serversBox.get('s1') as String;
      expect(raw.contains('OLD-KEY'), isFalse, reason: '迁移后明文必须抹掉');
      expect(raw.contains('OLD-USER'), isFalse);

      final servers = UserServerRepo().getAll();
      expect(servers.single.apiKey, 'OLD-KEY',
          reason: '迁移不能让用户丢掉自己的 Key');
      expect(servers.single.login, 'OLD-USER');
    });

    test('迁移只做一次：第二次启动不再改动', () async {
      await HiveSetup.serversBox.put(
          's1', _legacyRecord(id: 's1', apiKey: 'OLD-KEY'));
      final store = InMemoryCredentialStore();
      UserServerRepo.useCredentialStore(store);

      await UserServerRepo.initCredentials();
      final afterFirst = HiveSetup.serversBox.get('s1') as String;
      await UserServerRepo.initCredentials();
      final afterSecond = HiveSetup.serversBox.get('s1') as String;

      expect(afterSecond, afterFirst);
      expect(store.entries['s1']!.apiKey, 'OLD-KEY');
    });

    test('安全存储写不进去时**不**抹掉明文（否则直接丢 Key）', () async {
      await HiveSetup.serversBox.put(
          's1', _legacyRecord(id: 's1', apiKey: 'OLD-KEY'));
      UserServerRepo.useCredentialStore(_SilentStore());

      await UserServerRepo.initCredentials();

      final raw = HiveSetup.serversBox.get('s1') as String;
      expect(raw.contains('OLD-KEY'), isTrue,
          reason: '写不进安全存储就必须保留原状——抹掉等于丢数据');
      expect(UserServerRepo().getAll().single.apiKey, 'OLD-KEY');
    });

    test('安全存储整个不可用时不崩、也不动明文', () async {
      await HiveSetup.serversBox.put(
          's1', _legacyRecord(id: 's1', apiKey: 'OLD-KEY'));
      UserServerRepo.useCredentialStore(_BrokenStore());

      await UserServerRepo.initCredentials();

      final raw = HiveSetup.serversBox.get('s1') as String;
      expect(raw.contains('OLD-KEY'), isTrue);
    });

    test('没有旧明文的站点：从安全存储读进镜像即止', () async {
      final store = InMemoryCredentialStore();
      await store.write('s1', const ServerCredentials(apiKey: 'K'));
      await HiveSetup.serversBox.put(
          's1', _legacyRecord(id: 's1'));
      UserServerRepo.useCredentialStore(store);

      await UserServerRepo.initCredentials();

      expect(UserServerRepo().getAll().single.apiKey, 'K');
    });
  });

  group('孤儿凭据清理（只在 box 损坏隔离后做）', () {
    test('隔离发生后：没有对应服务器的凭据被清掉，在用的保留', () async {
      final store = InMemoryCredentialStore();
      await store.write('s1', const ServerCredentials(apiKey: 'KEEP'));
      await store.write('gone', const ServerCredentials(apiKey: 'ORPHAN'));
      await HiveSetup.serversBox.put(
          's1', _legacyRecord(id: 's1'));
      UserServerRepo.useCredentialStore(store);
      HiveSetup.recoveredFromCorruption = true;
      addTearDown(() => HiveSetup.recoveredFromCorruption = false);

      await UserServerRepo.initCredentials();

      expect(store.entries.containsKey('gone'), isFalse,
          reason: '服务器没了，密文不该继续躺在安全存储里');
      expect(store.entries['s1']!.apiKey, 'KEEP');
      expect(UserServerRepo().getAll().single.apiKey, 'KEEP');
    });

    test('没发生隔离时**不**清理：宁可留孤儿也不能误删凭据', () async {
      // `_rawAll()` 会跳过单条损坏的记录。若把它当成「已删除」就去清理，
      // 用户会静默失去自己的 API Key。
      final store = InMemoryCredentialStore();
      await store.write('gone', const ServerCredentials(apiKey: 'ORPHAN'));
      UserServerRepo.useCredentialStore(store);
      HiveSetup.recoveredFromCorruption = false;

      await UserServerRepo.initCredentials();

      expect(store.entries.containsKey('gone'), isTrue,
          reason: '没有隔离信号时不得清理孤儿凭据');
    });
  });

  group('保存失败要能被调用方看见', () {
    test('安全存储写不进去时 save() 返回 false（站点本身仍然保存）', () async {
      UserServerRepo.useCredentialStore(_SilentStore());
      final repo = UserServerRepo();

      final persisted = await repo.save(
          _server(id: 's1', apiKey: 'K'));

      expect(persisted, isFalse, reason: '要让 UI 能提示「本次会话有效」');
      expect(repo.getAll().single.apiKey, 'K',
          reason: '本次会话内仍然可用');
    });

    test('正常写入时返回 true', () async {
      UserServerRepo.useCredentialStore(InMemoryCredentialStore());
      expect(await UserServerRepo().save(_server(id: 's1', apiKey: 'K')),
          isTrue);
    });

    test('没有凭据的站点也算成功（不需要安全存储）', () async {
      UserServerRepo.useCredentialStore(_BrokenStore());
      expect(await UserServerRepo().save(_server(id: 's1')), isTrue);
    });
  });

  group('导入备份不得动到凭据', () {
    test('saveImported 保留已有凭据（哪怕实体里没有凭据字段）', () async {
      final store = InMemoryCredentialStore();
      await store.write('s1', const ServerCredentials(apiKey: 'KEEP'));
      UserServerRepo.useCredentialStore(store);
      final repo = UserServerRepo();

      // 备份里的实体不含凭据 → 走导入通道
      await repo.saveImported(_server(id: 's1'));

      expect(store.entries['s1']!.apiKey, 'KEEP',
          reason: '导入一次备份不该让用户丢掉 API Key');
      expect(repo.getAll().single.apiKey, 'KEEP');
    });

    test('对照：save() 传空凭据是「用户清空了」的语义，会删掉', () async {
      final store = InMemoryCredentialStore();
      await store.write('s1', const ServerCredentials(apiKey: 'KEEP'));
      UserServerRepo.useCredentialStore(store);
      final repo = UserServerRepo();

      await repo.save(_server(id: 's1'));

      expect(store.entries.containsKey('s1'), isFalse);
    });
  });
}
