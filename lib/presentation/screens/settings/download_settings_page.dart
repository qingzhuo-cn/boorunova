// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/foundation/util/batch_ops.dart';
import 'package:boorunova/foundation/util/download_paths.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart' show SectionHeader;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class DownloadSettingsPage extends ConsumerStatefulWidget {
  const DownloadSettingsPage({super.key});
  @override
  ConsumerState<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends ConsumerState<DownloadSettingsPage> {
  String _defaultPath = '';

  @override
  void initState() {
    super.initState();
    _loadPath();
  }

  Future<void> _loadPath() async {
    final dir = await getTemporaryDirectory();
    if (mounted) setState(() => _defaultPath = dir.path);
  }

  Future<void> _pickPath() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;
    // 选中的目录必须先证明可写再保存：scoped storage 下公共目录
    // （如 /storage/emulated/0/Download）能选中却写不进去，保存后每次下载
    // 都在写盘时失败。这里直接拒绝，让用户当场换一个目录。
    if (!await isWritableDirectory(result)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.downloadDirNotWritable)),
      );
      return;
    }
    if (!mounted) return;
    await ref.read(settingsProvider.notifier).setDownloadPath(result);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(T.downloadSettingsTitle)),
      body: ListView(children: [
        SectionHeader(title: T.sectionQuality),
        // 预览与下载分开：常见组合是「预览用 sample 省流量、下载存原图」
        ListTile(
          title: Text(T.previewQuality),
          subtitle: Text(T.previewQualitySub,
              style: const TextStyle(fontSize: 11)),
          trailing: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'sample', label: Text(T.qualitySample, style: const TextStyle(fontSize: 12))),
              ButtonSegment(value: 'original', label: Text(T.qualityOriginal, style: const TextStyle(fontSize: 12))),
            ],
            selected: {settings.previewQuality},
            onSelectionChanged: (v) => ref.read(settingsProvider.notifier).setPreviewQuality(v.first),
          ),
        ),
        ListTile(
          title: Text(T.downloadQuality),
          trailing: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'sample', label: Text(T.qualitySample, style: const TextStyle(fontSize: 12))),
              ButtonSegment(value: 'original', label: Text(T.qualityOriginal, style: const TextStyle(fontSize: 12))),
            ],
            selected: {settings.downloadQuality},
            onSelectionChanged: (v) => ref.read(settingsProvider.notifier).setDownloadQuality(v.first),
          ),
        ),
        // 并发数：1 = 串行最省流量/最稳，6 = 最快但更吃带宽与相册写入
        ListTile(
          title: Text(T.downloadConcurrency),
          subtitle: Text(
            T.downloadConcurrencyValue(settings.downloadConcurrency),
            style: const TextStyle(fontSize: 11),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Slider(
            value: settings.downloadConcurrency.toDouble(),
            min: minDownloadConcurrency.toDouble(),
            max: maxDownloadConcurrency.toDouble(),
            divisions: maxDownloadConcurrency - minDownloadConcurrency,
            label: '${settings.downloadConcurrency}',
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setDownloadConcurrency(v.round()),
          ),
        ),
        SectionHeader(title: T.sectionPath),
        ListTile(
          title: Text(T.downloadPath),
          subtitle: Text(
            settings.downloadPath.isNotEmpty
                ? settings.downloadPath
                : '${T.defaultPathPrefix}$_defaultPath',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: const Icon(Icons.folder_open),
          onTap: _pickPath,
        ),
        if (settings.downloadPath.isNotEmpty)
          ListTile(
            title: Text(T.resetDefaultPath),
            trailing: const Icon(Icons.restore),
            onTap: () => ref.read(settingsProvider.notifier).setDownloadPath(''),
          ),
      ]),
    );
  }
}
