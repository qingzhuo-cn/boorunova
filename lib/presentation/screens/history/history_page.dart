import 'package:boorunova/data/repository/history/user_history_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(userHistoryRepoProvider);
    final entries = repo.getAll();

    return Scaffold(
      appBar: AppBar(
        title: const Text(T.history),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: T.clearHistory,
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text(T.clearHistoryTitle),
                    content: const Text(T.clearHistoryContent),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text(T.cancel)),
                      FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text(T.clear)),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    T.noHistory,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
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
                  title: Text(
                    '${entry.width}x${entry.height}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    _formatDate(entry.viewedAt),
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Text(
                    entry.rating.toUpperCase(),
                    style: const TextStyle(fontSize: 11),
                  ),
                  dense: true,
                );
              },
            ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return T.justNow;
    if (diff.inHours < 1) return '${diff.inMinutes}${T.minutesAgo}';
    if (diff.inDays < 1) return '${diff.inHours}${T.hoursAgo}';
    return '${diff.inDays}${T.daysAgo}';
  }
}
