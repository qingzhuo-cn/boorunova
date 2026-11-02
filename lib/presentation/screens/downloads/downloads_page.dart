// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:io';

import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:boorunova/presentation/widgets/common/clear_confirm_dialog.dart';
import 'package:boorunova/presentation/widgets/common/relative_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';


class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(userDownloadsRepoProvider);
    final entries = repo.getAll();

    return Scaffold(
      appBar: AppBar(
        title: Text(T.downloads),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: T.clearDownloadHistory,
              onPressed: () async {
                final confirmation = await _confirmDelete(
                  context,
                  title: T.clearDownloadHistoryTitle,
                  confirmLabel: T.clear,
                );
                if (!confirmation.confirmed) return;
                await repo.clear(
                    deleteLocalFiles: confirmation.deleteLocalFiles);
                ref.invalidate(userDownloadsRepoProvider);
              },
            ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.download_outlined,
                title: T.noDownloadsYet,
                hint: T.downloadsHint,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  // 此前整行不可点，localPath 存了却从不使用：下载记录
                  // 只能删不能看。现在点开直接预览本地文件。
                  onTap: () => _preview(context, entry),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      entry.imageUrl,
                      width: 48,
                      height: 48,
                      // 48dp 的格子按原图全尺寸解码会白白吃掉内存（批量下载
                      // 记录多时尤其明显）：按物理像素解码，同文件 _preview 已修过。
                      cacheWidth:
                          (48 * MediaQuery.devicePixelRatioOf(context)).round(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.broken_image, size: 24),
                      ),
                    ),
                  ),
                  title: Text(
                    _fileNameOf(entry),
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    formatRelativeTime(entry.downloadedAt),
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        tooltip: T.openFile,
                        onPressed: () => _openExternally(context, entry),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        tooltip: T.share,
                        onPressed: () => _share(context, entry),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: T.deleteAction,
                        onPressed: () => _remove(context, ref, repo, entry),
                      ),
                    ],
                  ),
                  dense: true,
                );
              },
            ),
    );
  }

  /// 删除下载记录前的确认，顺带让用户决定是否清理本机文件。
  ///
  /// 删除确认：走全应用统一的 [confirmClearDialog]（带「同时删除本机文件」
  /// 勾选项）。
  ///
  /// 修复前 remove/clear 只删记录：记录指向的本机文件（下载目录里那一份）
  /// 永远留在磁盘上成为孤儿文件，而 UI 连一个清理入口都没给。这里删的只是
  /// app 下载目录里的文件；Gal 写进系统相册的那份没有被、也没有能力在这里
  /// 删除——文案里已写明「相册里的文件不会被删除」。
  Future<ClearConfirmation> _confirmDelete(
    BuildContext context, {
    required String title,
    required String confirmLabel,
  }) =>
      confirmClearDialog(
        context,
        title: title,
        content: T.clearDownloadHistoryContent,
        confirmLabel: confirmLabel,
        withFileOption: true,
      );

  /// 优先展示落盘后的真实文件名；文件已被系统清理时退回 URL 尾段。
  String _fileNameOf(DownloadEntry entry) {
    final path = entry.localPath;
    if (path.isEmpty) return entry.imageUrl.split('/').last;
    final slash = path.lastIndexOf(RegExp(r'[/\\]'));
    return slash >= 0 ? path.substring(slash + 1) : path;
  }

  /// 预览下载记录。落盘文件优先；文件已被系统清理时退回远端图，
  /// 而不是弹一个坏掉的空框。
  ///
  /// 文件探测放在 showDialog 之前，弹窗本身不再跨 async 边界使用 context。
  Future<void> _preview(BuildContext context, DownloadEntry entry) async {
    var useLocal = false;
    final path = entry.localPath;
    if (path.isNotEmpty) {
      // ignore: avoid_slow_async_io
      useLocal = await File(path).exists();
    }
    if (!context.mounted) return;
    // 原图动辄 6000×5000——不设 cacheWidth 就按原始像素解码（ARGB 约 120MB），
    // 低内存设备点开预览直接 OOM。预览按屏幕宽度 2 倍解码足够看清，再放大
    // 交给 InteractiveViewer。瀑布流早已这么做（timeline 的 decodeWidth），
    // 这里此前漏了。
    final decodeWidth = (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context) *
            2)
        .round();
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          maxScale: 4,
          child: useLocal
              ? Image.file(
                  File(path),
                  cacheWidth: decodeWidth,
                  errorBuilder: (_, __, ___) => const _PreviewFallback(),
                )
              : Image.network(
                  entry.imageUrl,
                  cacheWidth: decodeWidth,
                  errorBuilder: (_, __, ___) => const _PreviewFallback(),
                ),
        ),
      ),
    );
  }

  void _share(BuildContext context, DownloadEntry entry) {
    final file = File(entry.localPath);
    if (entry.localPath.isNotEmpty && file.existsSync()) {
      Share.shareXFiles(
        [XFile(entry.localPath)],
        text: entry.imageUrl,
      );
      return;
    }
    Share.share(entry.imageUrl);
  }

  /// 用系统其他应用打开本地文件。走 share 而不是 url_launcher：
  /// Android 上 file: URI 需要 FileProvider 授权才能被第三方应用接收，
  /// 直接 launch 会静默失败；分享面板有系统兜底，成功率更高。
  void _openExternally(BuildContext context, DownloadEntry entry) {
    final path = entry.localPath;
    if (path.isEmpty) {
      Share.share(entry.imageUrl);
      return;
    }
    Share.shareXFiles([XFile(path)], text: entry.imageUrl);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref,
      UserDownloadsRepo repo, DownloadEntry entry) async {
    // messenger 在任何 await 之前取好，后面不再碰 context。
    final messenger = ScaffoldMessenger.of(context);
    final confirmation = await _confirmDelete(
      context,
      title: T.deleteAction,
      confirmLabel: T.deleteAction,
    );
    if (!confirmation.confirmed) return;
    await repo.remove(entry.postId,
        serverId: entry.serverId,
        deleteLocalFile: confirmation.deleteLocalFiles);
    ref.invalidate(userDownloadsRepoProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(T.removedFromDownloads)),
    );
  }


}

/// 预览失败占位：本地文件和远端图都可能已经不可用。
class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, size: 48),
          const SizedBox(height: 12),
          Text(
            T.fileUnavailable,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
