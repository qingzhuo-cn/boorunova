// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:io';

// 只用直接依赖：cacheImageFolderName 由 extended_image 再导出，
// 不为了一个常量把传递依赖（extended_image_library / path）提到 pubspec。
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// 磁盘图片缓存的一条记录。
@immutable
class CacheEntry {
  const CacheEntry({
    required this.path,
    required this.bytes,
    required this.accessed,
    required this.modified,
  });

  final String path;
  final int bytes;
  final DateTime accessed;
  final DateTime modified;

  /// 最近的「使用」时间，用于 LRU 排序。
  ///
  /// 优先 `accessed`，但很多 Android 设备以 noatime 挂载，atime 会等于或早于
  /// mtime——那样纯按 atime 排会退化成任意顺序。取两者较大值作为近似：
  /// 「刚下载的」一定比「更早下载的」新，顺序仍然合理。
  DateTime get lastUsed => accessed.isAfter(modified) ? accessed : modified;
}

/// 淘汰计划：该删哪些、能释放多少。
@immutable
class CacheEvictionPlan {
  const CacheEvictionPlan({required this.toDelete, required this.freedBytes});

  final List<CacheEntry> toDelete;
  final int freedBytes;
}

/// 纯策略：超出 [maxBytes] 时，从**最久未使用**的开始删，直到降回上限以内。
///
/// 抽成纯函数是为了能穷举边界：不超上限时一个都不删、正好等于上限不删、
/// 超一点点删最旧的一个、全部都很旧时删到够为止。文件系统那层只负责
/// 「列出来」和「按计划删掉」。
CacheEvictionPlan planEviction(
  List<CacheEntry> entries, {
  required int maxBytes,
}) {
  var total = 0;
  for (final e in entries) {
    total += e.bytes;
  }
  if (total <= maxBytes || entries.isEmpty) {
    return const CacheEvictionPlan(toDelete: [], freedBytes: 0);
  }

  // 最旧的排前面。同样新旧的按路径排序，保证行为可复现（测试才稳定）。
  final ordered = [...entries]..sort((a, b) {
      final byTime = a.lastUsed.compareTo(b.lastUsed);
      return byTime != 0 ? byTime : a.path.compareTo(b.path);
    });

  final toDelete = <CacheEntry>[];
  var freed = 0;
  for (final entry in ordered) {
    if (total - freed <= maxBytes) break;
    toDelete.add(entry);
    freed += entry.bytes;
  }
  return CacheEvictionPlan(toDelete: toDelete, freedBytes: freed);
}

/// 磁盘图片缓存的自动治理（OPT §2.2）。
///
/// 缓存位于系统**临时**目录（`<temp>/cacheimage`，extended_image 的默认位置），
/// 删掉只是下次重新下载，不涉及任何用户数据——所以可以放心按体积做 LRU。
/// 这也正是下载目录当初不用临时目录的原因（见 download_paths.dart）。
class ImageCacheManager {
  ImageCacheManager._();

  // -------------------------------------------------------------------------
  // 内存缓存（OPT §2.1）
  // -------------------------------------------------------------------------

  /// 内存里最多缓存多少张**解码后**的图。
  ///
  /// Flutter 默认 1000 张 / 100MB。大瀑布流一屏就是 20–40 张，按显示宽度解码
  /// 后每张 0.3–4MB，默认上限下长会话会把内存推到很高。收紧到 200 张约等于
  /// 「回滚几屏仍然秒开」，再往上收益很小、代价是内存。
  static const int memoryCacheMaxImages = 200;

  /// 内存上限：64MB（默认 100MB）。
  ///
  /// 与 [memoryCacheMaxImages] 是两个独立的闸：张数挡住「很多小图」，
  /// 字节数挡住「少数超大图」，两个都要设才有意义。
  static const int memoryCacheMaxBytes = 64 * 1024 * 1024;

  /// 收紧内存图片缓存上限。**必须在 runApp 之前调用**一次。
  ///
  /// 系统内存告急时 Flutter 自己会 evict，这里只是把「平时能涨到多大」钉住，
  /// 让长会话的内存可预测。设置页的「清理缓存」入口保留（手动兜底）。
  static void configureMemoryCache({
    int maxImages = memoryCacheMaxImages,
    int maxBytes = memoryCacheMaxBytes,
  }) {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = maxImages;
    cache.maximumSizeBytes = maxBytes;
  }

  /// 自动清理的默认上限：512MB。
  ///
  /// 取值的理由：手机上一张缩略图 ~50–200KB，512MB 大约是几千张的量级；
  /// 低于它就一直在无界增长，高于它则会把用户常看的图反复重下。
  static const int defaultMaxBytes = 512 * 1024 * 1024;

  /// 缓存目录（生产路径）。取不到临时目录时返回 null。
  static Future<Directory?> cacheDirectory() async {
    try {
      final temp = await getTemporaryDirectory();
      return Directory('${temp.path}${Platform.pathSeparator}'
          '$cacheImageFolderName');
    } catch (_) {
      return null;
    }
  }

  /// 列出缓存条目。
  static Future<List<CacheEntry>> entries({Directory? directory}) async {
    final dir = directory ?? await cacheDirectory();
    if (dir == null || !dir.existsSync()) return const [];
    final result = <CacheEntry>[];
    try {
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        try {
          final stat = entity.statSync();
          result.add(CacheEntry(
            path: entity.path,
            bytes: stat.size,
            accessed: stat.accessed,
            modified: stat.modified,
          ));
        } catch (_) {
          // 单条读不到 stat（并发删除）跳过，不影响整体治理
        }
      }
    } catch (_) {
      return result;
    }
    return result;
  }

  /// 当前占用字节数。
  static Future<int> currentBytes({Directory? directory}) async {
    final all = await entries(directory: directory);
    var total = 0;
    for (final e in all) {
      total += e.bytes;
    }
    return total;
  }

  /// 按体积执行 LRU 清理。返回实际删除的条目数与释放的字节数。
  static Future<CacheEvictionPlan> enforceLimit({
    int maxBytes = defaultMaxBytes,
    Directory? directory,
  }) async {
    final all = await entries(directory: directory);
    final plan = planEviction(all, maxBytes: maxBytes);
    final deleted = <CacheEntry>[];
    var freed = 0;
    for (final entry in plan.toDelete) {
      try {
        final file = File(entry.path);
        if (file.existsSync()) await file.delete();
        deleted.add(entry);
        freed += entry.bytes;
      } catch (_) {
        // 删不掉（并发占用）就跳过：这是缓存，下次启动还会再治理一遍
      }
    }
    return CacheEvictionPlan(toDelete: deleted, freedBytes: freed);
  }
}
