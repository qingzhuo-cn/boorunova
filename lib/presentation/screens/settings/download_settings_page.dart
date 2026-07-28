import 'dart:io';
import 'package:boorunova/presentation/provider/app_settings.dart';
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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('下载设置')),
      body: ListView(children: [
        ListTile(
          title: const Text('下载质量'),
          trailing: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'sample', label: Text('预览', style: TextStyle(fontSize: 12))),
              ButtonSegment(value: 'original', label: Text('原图', style: TextStyle(fontSize: 12))),
            ],
            selected: {settings.downloadQuality},
            onSelectionChanged: (v) => ref.read(settingsProvider.notifier).setDownloadQuality(v.first),
          ),
        ),
        ListTile(
          title: const Text('下载路径'),
          subtitle: Text(settings.downloadPath.isNotEmpty ? settings.downloadPath : '默认: $_defaultPath', style: const TextStyle(fontSize: 11)),
        ),
      ]),
    );
  }
}
