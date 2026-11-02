// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/data/repository/history/user_history_repo.dart';
import 'package:boorunova/data/repository/search_history/search_history_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:boorunova/presentation/widgets/common/clear_confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PrivacyPage extends ConsumerWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(T.privacyTitle)),
      body: ListView(children: [
        SectionHeader(title: T.sectionDataManage),
        ListTile(
          leading: const Icon(Icons.history),
          title: Text(T.clearSearchHistory),
          subtitle: Text(T.clearSearchHistorySub),
          onTap: () async {
            final confirmation = await confirmClearDialog(
              context,
              title: T.clearSearchHistory,
              content: T.clearSearchHistorySub,
            );
            if (confirmation.confirmed && context.mounted) {
              await ref.read(searchHistoryRepoProvider).clear();
              ref.invalidate(searchHistoryRepoProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(T.searchHistoryCleared)));
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.visibility_outlined),
          title: Text(T.clearViewHistory),
          subtitle: Text(T.clearViewHistorySub),
          onTap: () async {
            final confirmation = await confirmClearDialog(
              context,
              title: T.clearHistoryTitle,
              content: T.clearHistoryContent,
            );
            if (confirmation.confirmed && context.mounted) {
              await ref.read(userHistoryRepoProvider).clear();
              // 必须 invalidate：历史是 static 缓存 + Provider 实例，
              // 不通知的话栈内还在看的浏览历史页会继续显示已删掉的条目。
              ref.invalidate(userHistoryRepoProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(T.viewHistoryCleared)));
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.download_done_outlined),
          title: Text(T.clearDownloadRecords),
          subtitle: Text(T.clearDownloadRecordsSub),
          onTap: () async {
            // 同一个「清除下载记录」动作，在下载页会问「是否连带删除本机
            // 文件」；这里此前直接清空。现在口径一致。
            final confirmation = await confirmClearDialog(
              context,
              title: T.clearDownloadHistoryTitle,
              content: T.clearDownloadHistoryContent,
              withFileOption: true,
            );
            if (confirmation.confirmed && context.mounted) {
              await ref.read(userDownloadsRepoProvider)
                  .clear(deleteLocalFiles: confirmation.deleteLocalFiles);
              // 同理：不 invalidate 的话下载页仍显示已清空的记录。
              ref.invalidate(userDownloadsRepoProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(T.downloadRecordsCleared)));
              }
            }
          },
        ),
        SectionHeader(title: T.sectionPrivacyNote),
        ListTile(
          leading: const Icon(Icons.policy_outlined),
          title: Text(T.contentSourceEntry),
          subtitle: Text(T.contentSourceSub),
          onTap: () => context.push('/settings/content-source'),
        ),
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: Text(T.dataCollection),
          subtitle: Text(T.dataCollectionSub),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: Text(T.networkRequests),
          subtitle: Text(T.networkRequestsSub),
        ),
      ]),
    );
  }
}
