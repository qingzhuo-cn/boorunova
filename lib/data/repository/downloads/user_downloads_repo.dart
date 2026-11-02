// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'dart:io';

import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/database/json_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userDownloadsRepoProvider = Provider<UserDownloadsRepo>((ref) {
  return UserDownloadsRepo();
});

class DownloadEntry {
  const DownloadEntry({
    required this.postId,
    required this.imageUrl,
    required this.localPath,
    required this.downloadedAt,
    this.width,
    this.height,
    this.serverId = '',
  });

  factory DownloadEntry.fromJson(Map<String, dynamic> json) => DownloadEntry(
        postId: json['postId'] as String,
        imageUrl: json['imageUrl'] as String,
        localPath: json['localPath'] as String,
        downloadedAt: DateTime.parse(json['downloadedAt'] as String),
        width: json['width'] as int?,
        height: json['height'] as int?,
        serverId: json['serverId']?.toString() ?? '',
      );

  final String postId;
  final String imageUrl;
  final String localPath;
  final DateTime downloadedAt;
  final int? width;
  final int? height;

  /// 所属站点。postId 在不同站点会重复，仅按 postId 删除会误伤同名条目。
  final String serverId;

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'imageUrl': imageUrl,
        'localPath': localPath,
        'downloadedAt': downloadedAt.toIso8601String(),
        'width': width,
        'height': height,
        'serverId': serverId,
      };
}

class UserDownloadsRepo {
  static const _key = 'downloads';

  /// 记录条数上限。超出后丢弃最旧的记录（文件不动——用户的文件不该被
  /// 一个"记录上限"悄悄删掉；孤儿文件由用户自己或系统清理决定）。
  static const int maxEntries = 500;

  static JsonListStore get _store => JsonListStore(HiveSetup.settingsBox, _key);

  List<DownloadEntry> getAll() => _store
      .read()
      .map((m) {
        try {
          return DownloadEntry.fromJson(m);
        } catch (_) {
          return null;
        }
      })
      .whereType<DownloadEntry>()
      .toList();

  /// 新增一条下载记录。
  ///
  /// 按 (serverId, postId) 去重：同一帖重复下载此前会堆积多条记录，而文件名
  /// 相同、互相覆盖，结果是"同一张图好几条记录，路径都一样"。
  Future<void> add(DownloadEntry entry) {
    return _store.update((items) {
      final key = _dedupeKey(entry.serverId, entry.postId);
      final next = items
          .where((m) =>
              _dedupeKey('${m['serverId'] ?? ''}', '${m['postId'] ?? ''}') != key)
          .toList();
      next.insert(0, entry.toJson());
      if (next.length > maxEntries) {
        next.removeRange(maxEntries, next.length);
      }
      return next;
    });
  }

  /// 按 postId + serverId 精确定位删除。传入 serverId 时只删该站点的记录，
  /// 避免不同站点的同名 post 互相误删；传 null 则删除所有站点下该 id。
  ///
  /// [deleteLocalFile] 为 true 时，连带删除记录指向的**本机下载文件**
  /// （`localPath`）。默认 false：记录只是索引，用户没要求就不动磁盘上的
  /// 东西。这里只删 BooruNova 自己写在下载目录里的那份，Gal 写进系统相册
  /// 的副本不受影响（也不该由这里删）——UI 必须把这点告诉用户。
  Future<void> remove(
    String postId, {
    String? serverId,
    bool deleteLocalFile = false,
  }) async {
    // 先取出待删记录：_store.update 之后匹配项就从存储里消失了，拿不到路径。
    final matched = deleteLocalFile
        ? getAll()
            .where((e) =>
                e.postId == postId &&
                (serverId == null || e.serverId == serverId))
            .toList()
        : const <DownloadEntry>[];
    await _store.update((items) {
      return items.where((m) {
        if ('${m['postId'] ?? ''}' != postId) return true;
        if (serverId == null) return false;
        return '${m['serverId'] ?? ''}' != serverId;
      }).toList();
    });
    await _deleteFiles(matched);
  }

  /// 清空全部记录。[deleteLocalFiles] 为 true 时连带删除所有记录指向的
  /// 本机文件；语义与 [remove] 相同——相册副本不动。
  Future<void> clear({bool deleteLocalFiles = false}) async {
    final matched = deleteLocalFiles ? getAll() : const <DownloadEntry>[];
    await _store.clear();
    await _deleteFiles(matched);
  }

  /// 逐个删除本机文件。单个文件被占用/已不存在不能让整段清理中断，
  /// 空路径直接跳过（记录可能来自旧版本或导入备份）。
  Future<void> _deleteFiles(List<DownloadEntry> entries) async {
    for (final entry in entries) {
      final path = entry.localPath;
      if (path.isEmpty) continue;
      try {
        final file = File(path);
        // ignore: avoid_slow_async_io
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // 文件可能已被系统清理或被其他进程占用：删不掉就算了，
        // 记录已经移除，不应该因为一个文件失败而回滚。
      }
    }
  }

  Future<void> saveAll(List<DownloadEntry> entries) {
    return _store.write(entries.map((e) => e.toJson()).toList());
  }

  int get count => getAll().length;

  static String _dedupeKey(String serverId, String postId) =>
      '$serverId|$postId';
}
