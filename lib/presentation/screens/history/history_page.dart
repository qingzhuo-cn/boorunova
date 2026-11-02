// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/history/user_history_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:boorunova/presentation/widgets/common/rating_badge.dart';
import 'package:boorunova/presentation/widgets/common/relative_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(userHistoryRepoProvider);
    final entries = repo.getAll();

    return Scaffold(
      appBar: AppBar(
        title: Text(T.history),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: T.clearHistory,
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(T.clearHistoryTitle),
                    content: Text(T.clearHistoryContent),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(T.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(T.clear),
                      ),
                    ],
                  ),
                );
                if (confirmed ?? false) {
                  await repo.clear();
                  ref.invalidate(userHistoryRepoProvider);
                }
              },
            ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.history,
                title: T.noHistory,
                hint: T.historyHint,
                action: FilledButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(T.browseNow),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final post = entry.toPostSummary();
                return ListTile(
                  // 历史此前不可点，是一条死数据：存了缩略图/大图/标签却
                  // 无法回到那张图。现在整行进入查看器，与首页入口同构。
                  onTap: () => context.push(
                    '/post/${entry.postId}',
                    extra: <String, dynamic>{
                      'posts': entries
                          .map((e) => e.toPostSummary())
                          .toList(growable: false),
                      'initialIndex': index,
                    },
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Hero(
                      tag: 'post_${entry.serverId}_${entry.postId}',
                      child: Image.network(
                        entry.thumbnailUrl,
                        width: 48,
                        height: 48,
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
                  ),
                  title: Text(
                    '${entry.width}x${entry.height}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    formatRelativeTime(entry.viewedAt),
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.rating.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          color: ratingColor(entry.rating),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        tooltip: T.share,
                        onPressed: () {
                          final url = permalinkOf(post);
                          if (url.isNotEmpty) Share.share(url);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: T.deleteAction,
                        onPressed: () async {
                          await repo.remove(entry.postId,
                              serverId: entry.serverId);
                          ref.invalidate(userHistoryRepoProvider);
                        },
                      ),
                    ],
                  ),
                  dense: true,
                );
              },
            ),
    );
  }
}
