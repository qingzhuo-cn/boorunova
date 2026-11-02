import 'dart:io';

import 'package:boorunova/foundation/util/image_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// 磁盘图片缓存的自动 LRU（OPT §2.2）。
///
/// 策略与文件系统分开测：策略那层穷举边界（不超/正好/超一点/超很多），
/// 文件系统那层用真临时目录验「删的是最旧的、删完确实在上限以内」。
CacheEntry _entry(String name, int bytes, int ageSeconds) {
  final stamp = DateTime(2026, 1, 1).add(Duration(seconds: ageSeconds));
  return CacheEntry(
    path: name,
    bytes: bytes,
    accessed: stamp,
    modified: stamp,
  );
}

void main() {
  group('淘汰策略（纯函数）', () {
    test('不超上限：一个都不删', () {
      final plan = planEviction(
        [_entry('a', 100, 0), _entry('b', 100, 1)],
        maxBytes: 1000,
      );
      expect(plan.toDelete, isEmpty);
      expect(plan.freedBytes, 0);
    });

    test('正好等于上限：不删（边界不越界）', () {
      final plan = planEviction(
        [_entry('a', 400, 0), _entry('b', 600, 1)],
        maxBytes: 1000,
      );
      expect(plan.toDelete, isEmpty);
    });

    test('超一点点：只删最旧的那一个', () {
      final plan = planEviction(
        [_entry('old', 300, 0), _entry('mid', 300, 10), _entry('new', 500, 20)],
        maxBytes: 1000,
      );
      expect(plan.toDelete.map((e) => e.path), ['old']);
      expect(plan.freedBytes, 300);
    });

    test('超很多：按最久未使用依次删到够了就停', () {
      final plan = planEviction(
        [
          for (var i = 0; i < 10; i++) _entry('f$i', 100, i),
        ],
        maxBytes: 250,
      );
      // 总共 1000，要降到 250 → 至少删 750（8 条），不能多删
      expect(plan.freedBytes, greaterThanOrEqualTo(750));
      expect(plan.toDelete.length, 8);
      expect(plan.toDelete.first.path, 'f0', reason: '先删最旧的');
      expect(plan.toDelete.map((e) => e.path), isNot(contains('f9')));
    });

    test('空列表不炸', () {
      expect(planEviction(const [], maxBytes: 10).toDelete, isEmpty);
    });

    test('时间相同也稳定（按路径兜底排序，测试不会随机红）', () {
      final plan = planEviction(
        [_entry('b', 100, 5), _entry('a', 100, 5)],
        maxBytes: 100,
      );
      expect(plan.toDelete.first.path, 'a');
    });

    test('accessed 不可信时退回 modified（noatime 设备）', () {
      final entry = CacheEntry(
        path: 'x',
        bytes: 1,
        accessed: DateTime(2020),
        modified: DateTime(2026),
      );
      expect(entry.lastUsed, DateTime(2026));
    });
  });

  group('真实目录清理', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('boorunova_cache');
    });

    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    /// 写一个缓存文件。
    ///
    /// 不手动改 mtime：Dart 改不了 atime，而真实设备上「最近使用」以 atime 为准。
    /// 这里靠**写入顺序**制造时间差（写文件时 atime≈now），于是「先写的更旧」，
    /// 与生产环境的语义一致。
    File write(String name, int bytes) {
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      file.writeAsBytesSync(List<int>.filled(bytes, 0));
      return file;
    }

    test('真目录上按最近使用时间淘汰：先写的最先删', () async {
      write('a.jpg', 600);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      write('b.jpg', 600);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      write('c.jpg', 600);

      final plan = await ImageCacheManager.enforceLimit(
        maxBytes: 1200,
        directory: dir,
      );

      expect(plan.toDelete, hasLength(1), reason: '删一条就够，不能多删');
      expect(plan.toDelete.single.path, endsWith('a.jpg'),
          reason: '先写入（= 最久未使用）的那条先删');
      expect(
        await ImageCacheManager.currentBytes(directory: dir),
        lessThanOrEqualTo(1200),
      );
      expect(File('${dir.path}${Platform.pathSeparator}c.jpg').existsSync(), isTrue,
          reason: '最新的必须留下');
    });

    test('没超上限时不动文件', () async {
      write('a.jpg', 100);
      final plan = await ImageCacheManager.enforceLimit(
        maxBytes: 10 * 1024 * 1024,
        directory: dir,
      );
      expect(plan.toDelete, isEmpty);
      expect(dir.listSync(), hasLength(1));
    });

    test('目录不存在时安全返回（首次启动）', () async {
      final missing = Directory('${dir.path}${Platform.pathSeparator}nope');
      final plan = await ImageCacheManager.enforceLimit(
        maxBytes: 0,
        directory: missing,
      );
      expect(plan.toDelete, isEmpty);
    });
  });
}
