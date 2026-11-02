// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'dart:io';

import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/data/repository/history/user_history_repo.dart';
import 'package:boorunova/foundation/util/image_cache_manager.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart' show SectionHeader;
import 'package:boorunova/presentation/widgets/common/clear_confirm_dialog.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class DataStoragePage extends StatefulWidget {
  const DataStoragePage({super.key});
  @override
  State<DataStoragePage> createState() => _DataStoragePageState();
}

class _DataStoragePageState extends State<DataStoragePage> {
  String _cacheSize = '';

  /// 磁盘图片缓存的占用（字节）。独立于 [_cacheSize]：后者是「整个应用临时
  /// 目录」，前者只是 extended_image 的图片缓存那一块。
  late final Future<int> _diskCacheBytes =
      ImageCacheManager.currentBytes();

  @override
  void initState() {
    super.initState();
    _cacheSize = T.calculating;
    _calcCache();
  }

  Future<Directory?> _appTempDir() async {
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return null;
    }
  }

  Future<void> _calcCache() async {
    try {
      final temp = await _appTempDir();
      int size = 0;
      if (temp != null && temp.existsSync()) {
        await for (final e in temp.list()) {
          if (e is File) size += await e.length();
        }
      }
      if (!mounted) return;
      setState(() => _cacheSize = '${(size / 1048576).toStringAsFixed(1)} MB');
    } catch (_) {
      if (!mounted) return;
      setState(() => _cacheSize = T.unknown);
    }
  }

  /// 下载记录引用的文件路径集合。
  ///
  /// 清理缓存必须跳过它们：默认下载目录一旦是缓存目录（历史行为），
  /// 点一次「清除缓存」就会把用户下载的文件删光，而下载记录还指着它们，
  /// 界面显示"文件仍在"、点开却什么都没有。
  Set<String> _referencedFiles() {
    try {
      return UserDownloadsRepo()
          .getAll()
          .map((e) => e.localPath)
          .where((p) => p.isNotEmpty)
          .toSet();
    } catch (_) {
      // 读不到记录时宁可不删：删错文件不可逆，留一点缓存还有救
      return const {};
    }
  }

  Future<void> _clearCache() async {
    try {
      final temp = await _appTempDir();
      final protected = _referencedFiles();
      int count = 0;
      int skipped = 0;
      if (temp != null && temp.existsSync()) {
        await for (final e in temp.list()) {
          if (e is! File) continue;
          if (protected.contains(e.path)) {
            skipped++;
            continue;
          }
          await e.delete();
          count++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${T.clearedCacheFiles}$count${T.tempFiles}'
              '${skipped > 0 ? '（$skipped ${T.downloadHistory}）' : ''}',
            ),
          ),
        );
        await _calcCache();
      }
    } catch (_) {}
  }

  /// 清空前的确认对话框（全应用统一实现，见 [confirmClearDialog]）。
  ///
  /// 清除浏览历史与下载记录都不可撤销，而这里此前点一下就直接清空，和别处
  /// 的口径不一致；下载记录现在还会问「是否连带删除本机文件」——与下载页
  /// 的同一个动作保持同一破坏力。
  Future<ClearConfirmation> _confirmClear({
    required String title,
    required String content,
    bool withFileOption = false,
  }) =>
      confirmClearDialog(
        context,
        title: title,
        content: content,
        withFileOption: withFileOption,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(T.dataAndStorage)),
      body: ListView(children: [
        SectionHeader(title: T.sectionCache),
        ListTile(
          leading: const Icon(Icons.storage),
          title: Text(T.cache),
          subtitle: _cacheSize == T.calculating
              ? Row(children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(T.calculating, style: Theme.of(context).textTheme.bodySmall),
                ])
              : Text(_cacheSize),
          trailing: TextButton(onPressed: _clearCache, child: Text(T.clearAction)),
        ),
        Consumer(
          builder: (context, ref, _) {
            final cache = PaintingBinding.instance.imageCache;
            final imgBytes = cache.currentSizeBytes;
            final mb = (imgBytes / 1048576).toStringAsFixed(1);
            return ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(T.imageCache),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(T.memoryCacheUsage(
                    mb,
                    ImageCacheManager.memoryCacheMaxImages,
                    (ImageCacheManager.memoryCacheMaxBytes / 1048576)
                        .round(),
                  )),
                  // 磁盘缓存占用 + 自动上限（OPT §2.2）：此前只显示内存占用，
                  // 用户看不到「磁盘上到底堆了多少」
                  FutureBuilder<int>(
                    future: _diskCacheBytes,
                    builder: (context, snapshot) {
                      final bytes = snapshot.data;
                      if (bytes == null) return const SizedBox.shrink();
                      final diskMb = (bytes / 1048576).toStringAsFixed(1);
                      final capMb =
                          (ImageCacheManager.defaultMaxBytes / 1048576).round();
                      return Text(
                        T.diskCacheUsage(diskMb, capMb),
                        style: const TextStyle(fontSize: 11),
                      );
                    },
                  ),
                ],
              ),
              trailing: TextButton(
                onPressed: () {
                  cache.clear();
                  cache.clearLiveImages();
                  clearDiskCachedImages();
                  setState(() {});
                },
                child: Text(T.clearAction),
              ),
            );
          },
        ),
        SectionHeader(title: T.sectionRecords),
        Consumer(
          builder: (context, ref, _) {
            final historyCount = ref.watch(userHistoryRepoProvider).count;
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(T.browsingHistory),
              subtitle: Text('$historyCount ${T.recordsUnit}'),
              trailing: TextButton(
                onPressed: () async {
                  final confirmation = await _confirmClear(
                    title: T.clearHistoryTitle,
                    content: T.clearHistoryContent,
                  );
                  if (!confirmation.confirmed) return;
                  if (!mounted) return;
                  await ref.read(userHistoryRepoProvider).clear();
                  if (!mounted) return;
                  ref.invalidate(userHistoryRepoProvider);
                },
                child: Text(T.clearAction),
              ),
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final downloadCount = ref.watch(userDownloadsRepoProvider).count;
            return ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(T.downloadHistory),
              subtitle: Text('$downloadCount ${T.recordsUnit}'),
              trailing: TextButton(
                onPressed: () async {
                  final confirmation = await _confirmClear(
                    title: T.clearDownloadHistoryTitle,
                    content: T.clearDownloadHistoryContent,
                    withFileOption: true,
                  );
                  if (!confirmation.confirmed) return;
                  if (!mounted) return;
                  await ref.read(userDownloadsRepoProvider).clear(
                      deleteLocalFiles: confirmation.deleteLocalFiles);
                  if (!mounted) return;
                  ref.invalidate(userDownloadsRepoProvider);
                },
                child: Text(T.clearAction),
              ),
            );
          },
        ),
      ]),
    );
  }
}
