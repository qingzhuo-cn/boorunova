import 'dart:io';
import 'dart:typed_data';

import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// H2 的守卫：settings box 损坏时，**不能**把已经打开的 servers box 一起关掉。
///
/// 旧实现 catch 里调 `Hive.close()`——它会关掉所有已注册的 box，而
/// `_openBoxes` 先开 servers 再开 settings：settings 损坏时 servers 被连带
/// 关闭且永不重开，此后每次取 serversBox 都抛 "Box not found"，
/// 而 init() 又不抛错、降级页也不出现，用户面对的是「服务器列表整个会话全坏」。
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('boorunova_hive_recovery');
    HiveSetup.resetForTest();
    try {
      await Hive.close();
    } catch (_) {}
  });

  tearDown(() async {
    try {
      await Hive.close();
    } catch (_) {}
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  String file(String name) =>
      '${tempDir.path}${Platform.pathSeparator}$name';

  /// 造一个 hive 必然打不开的字节序列：8 字节的"合法帧头"——
  /// 长度=8（通过 readFrame 的 frameLength/availableBytes 检查）、
  /// 后 4 字节是该长度字段的 CRC32（通过校验），于是进入 readKey()，
  /// 但帧内可用字节为 0 → RangeError。
  ///
  /// 注意：单纯往文件里写随机字节**不会**让 openBox 抛错——crashRecovery:true
  /// 会把它们当成损坏帧截断到 offset 0 并恢复成功，那样就测不到 catch 分支。
  Uint8List unreadableBoxBytes() {
    final bytes = Uint8List(8);
    bytes[0] = 8; // frameLength = 8，小端
    final crc = _crc32(bytes.sublist(0, 4));
    bytes[4] = crc & 0xff;
    bytes[5] = (crc >> 8) & 0xff;
    bytes[6] = (crc >> 16) & 0xff;
    bytes[7] = (crc >> 24) & 0xff;
    return bytes;
  }

  /// 先造一个带数据的 servers.hive，再把 settings.hive 打坏。
  Future<void> seedCorruptSettings() async {
    Hive.init(tempDir.path);
    final servers = await Hive.openBox(HiveSetup.serversBoxName);
    await servers.put('s1', 'v1');
    await Hive.close();

    File(file('settings.hive')).writeAsBytesSync(unreadableBoxBytes());
  }

  test('settings 损坏时 servers box 仍可读写，且标记已恢复', () async {
    await seedCorruptSettings();

    await HiveSetup.init(dirPath: tempDir.path);

    expect(HiveSetup.recoveredFromCorruption, isTrue,
        reason: '损坏必须被标记，UI 才能提示用户');
    // 旧实现在这里抛 HiveError('Box not found')
    expect(HiveSetup.serversBox.get('s1'), 'v1',
        reason: '健康的 box 不该被连带关闭，数据也不能丢');
    await HiveSetup.serversBox.put('s2', 'v2');
    expect(HiveSetup.serversBox.get('s2'), 'v2');
    // 损坏的 box 重建后可用
    await HiveSetup.settingsBox.put('k', 1);
    expect(HiveSetup.settingsBox.get('k'), 1);
  });

  test('损坏文件被留证（改名或复制），不直接删除', () async {
    await seedCorruptSettings();

    await HiveSetup.init(dirPath: tempDir.path);

    final quarantined = tempDir
        .listSync()
        .map((e) => e.path)
        .where((p) => p.contains('.corrupt.'))
        .toList();
    expect(quarantined, isNotEmpty, reason: '损坏文件必须保留证据');
    expect(quarantined.any((p) => p.contains('settings.hive.corrupt.')), isTrue);
  });

  test('两个 box 都健康时不标记恢复', () async {
    Hive.init(tempDir.path);
    await Hive.openBox(HiveSetup.serversBoxName);
    await Hive.openBox(HiveSetup.settingsBoxName);
    await Hive.close();

    await HiveSetup.init(dirPath: tempDir.path);

    expect(HiveSetup.recoveredFromCorruption, isFalse);
    expect(HiveSetup.serversBox.isOpen, isTrue);
    expect(HiveSetup.settingsBox.isOpen, isTrue);
  });
}

/// hive 的 Crc32（IEEE，反射，初值/终值取反）——这里自己实现一份，
/// 避免依赖包的内部私有 API。
int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
