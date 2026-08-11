import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/data/repository/history/user_history_repo.dart';
import 'package:boorunova/data/repository/search_history/search_history_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrivacyPage extends ConsumerWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('隐私')),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text('数据管理', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('清除搜索历史'),
          subtitle: const Text('删除所有搜索关键词记录'),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('清除搜索历史？'),
                content: const Text('将删除所有搜索关键词记录，不可恢复。'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('清除')),
                ],
              ),
            );
            if ((confirmed ?? false) && context.mounted) {
              await ref.read(searchHistoryRepoProvider).clear();
              ref.invalidate(searchHistoryRepoProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('搜索历史已清除')));
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.visibility_outlined),
          title: const Text('清除浏览历史'),
          subtitle: const Text('删除所有浏览记录'),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('清除浏览历史？'),
                content: const Text('将删除所有浏览记录，不可恢复。'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('清除')),
                ],
              ),
            );
            if ((confirmed ?? false) && context.mounted) {
              await ref.read(userHistoryRepoProvider).clear();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('浏览历史已清除')));
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.download_done_outlined),
          title: const Text('清除下载记录'),
          subtitle: const Text('删除下载历史（已保存的图片不受影响）'),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('清除下载记录？'),
                content: const Text('删除下载历史记录，已下载的图片仍保留在相册中。'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('清除')),
                ],
              ),
            );
            if ((confirmed ?? false) && context.mounted) {
              await ref.read(userDownloadsRepoProvider).clear();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('下载记录已清除')));
              }
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
          child: Text('隐私声明', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        ),
        const ListTile(
          leading: Icon(Icons.shield_outlined),
          title: Text('数据收集'),
          subtitle: Text('BooruNova 不会收集或上传任何个人信息。所有数据（设置、收藏、历史记录）仅存储在本地设备中。'),
        ),
        const ListTile(
          leading: Icon(Icons.cloud_off_outlined),
          title: Text('网络请求'),
          subtitle: Text('仅在你主动浏览、搜索和下载时向 Booru 服务器发起请求，不会连接第三方分析或追踪服务。'),
        ),
      ]),
    );
  }
}
