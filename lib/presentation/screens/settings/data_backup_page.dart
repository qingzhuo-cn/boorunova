import 'dart:convert';
import 'dart:io';

import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/data/repository/favorites/user_favorite_repo.dart';
import 'package:boorunova/data/repository/search_history/search_history_repo.dart';
import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/data/repository/tags_blocker/booru_tags_blocker_repo.dart';
import 'package:boorunova/data/repository/tags_blocker/entity/booru_tag.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/tags_blocker_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class DataBackupPage extends ConsumerWidget {
  const DataBackupPage({super.key});

  Future<String> _exportData(WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    final servers = ref.read(userServerRepoProvider).getAll();
    final blocked = ref.read(tagsBlockerRepoProvider).getAll();
    final favorites = ref.read(userFavoritesRepoProvider).getAll();
    final history = ref.read(searchHistoryRepoProvider).getAll();
    final downloads = ref.read(userDownloadsRepoProvider).getAll();

    final data = {
      'version': 1,
      'timestamp': DateTime.now().toIso8601String(),
      'data': {
        'settings': settings.toJson(),
        'servers': servers.map((s) => s.toJson()).toList(),
        'blockedTags': blocked.values.map((t) => t.toJson()).toList(),
        'favorites': favorites.map((f) => f.toJson()).toList(),
        'searchHistory': history,
        'downloads': downloads.map((d) => d.toJson()).toList(),
      },
    };

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/boorunova_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file.path;
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    try {
      final file = File(result.files.first.path!);
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;

      // Import servers
      if (data['servers'] != null) {
        final list = data['servers'] as List;
        final repo = ref.read(userServerRepoProvider);
        final existing = repo.getAll().toList();
        for (final item in list) {
          final server = BooruServer.fromJson(Map<String, dynamic>.from(item as Map));
          if (!existing.any((e) => e.id == server.id)) {
            await repo.save(server);
          }
        }
        ref.invalidate(userServerRepoProvider);
      }

      // Import blocked tags
      if (data['blockedTags'] != null) {
        final list = data['blockedTags'] as List;
        final blocker = ref.read(tagsBlockerRepoProvider);
        for (final item in list) {
          final tag = BooruTag.fromJson(Map<String, dynamic>.from(item as Map));
          await blocker.push(tag);
        }
        ref.invalidate(tagsBlockerRepoProvider);
        ref.invalidate(tagsBlockerStateProvider);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('备份已导入')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $e')));
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

    return Scaffold(
      appBar: AppBar(title: const Text('数据备份恢复')),
      body: ListView(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('备份内容', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)),
        ),
        ListTile(title: const Text('服务器'), trailing: Text('${servers.length} 个')),
        ListTile(title: const Text('屏蔽标签'), trailing: Text('${blocked.length} 条')),
        ListTile(title: const Text('收藏'), trailing: Text('$favorites 条')),
        ListTile(title: const Text('搜索历史'), trailing: Text('$history 条')),
        ListTile(title: const Text('下载记录'), trailing: Text('$downloads 条')),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.file_upload_outlined),
          title: const Text('导出备份'),
          subtitle: const Text('保存为 JSON 文件'),
          onTap: () async {
            try {
              final path = await _exportData(ref);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导出: $path')));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: const Text('导入备份'),
          subtitle: const Text('从 JSON 文件恢复'),
          onTap: () => _importData(context, ref),
        ),
      ]),
    );
  }
}
