// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:convert';
import 'dart:io';

import 'package:boorunova/data/repository/backup/backup_codec.dart';
import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/data/repository/favorites/user_favorite_repo.dart';
import 'package:boorunova/data/repository/history/user_history_repo.dart';
import 'package:boorunova/data/repository/hosts/user_hosts_repo.dart';
import 'package:boorunova/data/repository/search_history/search_history_repo.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/data/repository/tags_blocker/entity/booru_tag.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/tags_blocker_state.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart' show SectionHeader;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DataBackupPage extends ConsumerWidget {
  const DataBackupPage({super.key});

  /// 导出：写到**临时目录**再交给系统分享面板。
  ///
  /// 此前落在 getApplicationDocumentsDirectory()（Android 上是
  /// /data/user/0/<pkg>/app_flutter），用户不接 ADB 根本拿不到那个文件——
  /// 「导出成功」对人来说等于什么都没发生。
  Future<void> _exportAndShare(WidgetRef ref) async {
    final payload = buildBackupPayload(
      settings: ref.read(settingsProvider).toJson(),
      servers: ref.read(userServerRepoProvider).getAll(),
      blockedTags: ref.read(tagsBlockerRepoProvider).getAll().values.toList(),
      favorites: ref.read(userFavoritesRepoProvider).getAll(),
      searchHistory: ref.read(searchHistoryRepoProvider).getAll(),
      downloads: ref.read(userDownloadsRepoProvider).getAll(),
      history: ref.read(userHistoryRepoProvider).getAll(),
      hosts: ref.read(userHostsRepoProvider).getAll(),
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/boorunova_backup_'
        '${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload));
    await Share.shareXFiles([XFile(file.path)], subject: 'BooruNova backup');
  }

  /// 逐段导入。
  ///
  /// 每段独立统计成功/跳过：单条坏记录只跳过它自己，不再让整段（乃至整个
  /// 导入）中断，也不再用一句「导入失败」盖掉已经写进去的部分。
  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    try {
      final decoded =
          jsonDecode(await File(result.files.first.path!).readAsString());
      if (decoded is! Map) throw const FormatException('not a backup object');
      final json = Map<String, dynamic>.from(decoded);
      final rawData = json['data'];
      if (rawData is! Map) throw const FormatException('missing data section');
      final data = Map<String, dynamic>.from(rawData);

      if (!isBackupVersionSupported(json['version'])) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(T.isEn
                ? 'Backup is newer than this app supports (v$kBackupSchemaVersion)'
                : T.backupVersionTooNew(kBackupSchemaVersion)),
          ));
        }
        return;
      }

      // 导入前确认：明确说明「合并什么、覆盖什么」，而不是点一下就把
      // 当前设置与搜索历史换掉。
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(T.importConfirmTitle),
          content: Text(T.importConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(T.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(T.confirmAction),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final summary = <String>[];
      List<dynamic> section(String key) =>
          data[key] is List ? data[key] as List : const [];

      // ---- 服务器：按 id 合并
      if (data[kBackupSectionServers] is List) {
        final repo = ref.read(userServerRepoProvider);
        final known = repo.getAll().map((s) => s.id).toSet();
        final stat =
            BackupMerger.servers(repo.getAll().toList(), section(kBackupSectionServers));
        for (final server in stat.items) {
          if (known.contains(server.id)) continue;
          // saveImported：备份不含凭据，导入绝不能有清空凭据的副作用
          await repo.saveImported(server);
        }
        ref.invalidate(userServerRepoProvider);
        summary.add('${T.servers} ${stat.ok}/${stat.total}');
      }

      // ---- 黑名单：合并（同名去重由仓库负责）
      if (data[kBackupSectionBlockedTags] is List) {
        final blocker = ref.read(tagsBlockerRepoProvider);
        final stat = BackupMerger.parse<BooruTag>(
            section(kBackupSectionBlockedTags), BooruTag.fromJson);
        for (final tag in stat.items) {
          await blocker.push(tag);
        }
        ref.invalidate(tagsBlockerRepoProvider);
        ref.invalidate(tagsBlockerStateProvider);
        summary.add('${T.blacklist} ${stat.ok}/${stat.total}');
      }

      // ---- 收藏：按 serverId|id 合并
      if (data[kBackupSectionFavorites] is List) {
        final repo = ref.read(userFavoritesRepoProvider);
        final stat = BackupMerger.favorites(
            [...repo.getAll()], section(kBackupSectionFavorites));
        await repo.saveAll(stat.items);
        ref.invalidate(userFavoritesRepoProvider);
        summary.add('${T.favorites} ${stat.ok}/${stat.total}');
      }

      // ---- 下载记录：按 serverId|postId 合并
      if (data[kBackupSectionDownloads] is List) {
        final repo = ref.read(userDownloadsRepoProvider);
        final stat = BackupMerger.downloads(
            [...repo.getAll()], section(kBackupSectionDownloads));
        await repo.saveAll(stat.items);
        ref.invalidate(userDownloadsRepoProvider);
        summary.add('${T.downloadHistory} ${stat.ok}/${stat.total}');
      }

      // ---- 浏览历史：按 serverId|postId 合并，保留较新的一条
      if (data[kBackupSectionHistory] is List) {
        final repo = ref.read(userHistoryRepoProvider);
        final stat = BackupMerger.history(repo.getAll().toList(),
            section(kBackupSectionHistory),
            max: UserHistoryRepo.maxEntries);
        await repo.replaceAll(stat.items);
        ref.invalidate(userHistoryRepoProvider);
        summary.add('${T.browsingHistory} ${stat.ok}/${stat.total}');
      }

      // ---- hosts：按 domain 合并
      if (data[kBackupSectionHosts] is List) {
        final repo = ref.read(userHostsRepoProvider);
        final stat = BackupMerger.hosts(
            repo.getAll(), section(kBackupSectionHosts));
        await repo.replaceAll(stat.items);
        ref.invalidate(userHostsRepoProvider);
        summary.add('${T.hosts} ${stat.ok}/${stat.total}');
      }

      // ---- 搜索历史：合并（现有在前 + 导入去重追加，保留 20 条）
      if (data[kBackupSectionSearchHistory] is List) {
        final repo = ref.read(searchHistoryRepoProvider);
        final stat = BackupMerger.searchHistory(
            repo.getAll(), section(kBackupSectionSearchHistory));
        await repo.replaceAll(stat.items);
        ref.invalidate(searchHistoryRepoProvider);
        summary.add('${T.searchHistoryEntry} ${stat.ok}');
      }

      // ---- 设置：覆盖语义（刻意保留，确认弹窗里已写明）
      if (data[kBackupSectionSettings] is Map) {
        await ref.read(settingsProvider.notifier).restore(AppSettings.fromJson(
            Map<String, dynamic>.from(data[kBackupSectionSettings] as Map)));
        ref.invalidate(settingsProvider);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(summary.isEmpty
              ? T.backupImported
              : '${T.backupImported}：${summary.join('、')}'),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${T.importFailed}：${T.friendlyError(e.toString())}')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(userServerRepoProvider).getAll();
    final blocked = ref.watch(tagsBlockerRepoProvider).getAll();
    final favorites = ref.watch(userFavoritesRepoProvider).getAll().length;
    final history = ref.watch(searchHistoryRepoProvider).getAll().length;
    final downloads = ref.watch(userDownloadsRepoProvider).getAll().length;
    final viewHistory = ref.watch(userHistoryRepoProvider).getAll().length;
    final hosts = ref.watch(userHostsRepoProvider).getAll().length;

    return Scaffold(
      appBar: AppBar(title: Text(T.backupTitle)),
      body: ListView(children: [
        SectionHeader(title: T.backupContentHeader),
        ListTile(
            title: Text(T.servers),
            trailing: Text('${servers.length}$T.serversCountUnit')),
        ListTile(
            title: Text(T.blacklist),
            trailing: Text('${blocked.length}${T.recordsUnit}')),
        ListTile(
            title: Text(T.favorites),
            trailing: Text('$favorites${T.recordsUnit}')),
        ListTile(
            title: Text(T.browsingHistory),
            trailing: Text('$viewHistory${T.recordsUnit}')),
        ListTile(
            title: Text(T.downloadHistory),
            trailing: Text('$downloads${T.recordsUnit}')),
        ListTile(
            title: Text(T.searchHistoryEntry),
            trailing: Text('$history${T.recordsUnit}')),
        ListTile(
            title: Text(T.hosts),
            trailing: Text('$hosts${T.hostsRules.trim()}')),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.file_upload_outlined),
          title: Text(T.exportBackup),
          subtitle: Text(T.exportBackupSub),
          onTap: () async {
            try {
              await _exportAndShare(ref);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(T.backupShared)));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${T.exportFailed}：${T.friendlyError(e.toString())}')));
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: Text(T.importBackup),
          subtitle: Text(T.importBackupSub),
          onTap: () => _importData(context, ref),
        ),
      ]),
    );
  }
}
