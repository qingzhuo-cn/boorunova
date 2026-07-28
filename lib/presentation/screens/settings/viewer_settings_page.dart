import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ViewerSettingsPage extends ConsumerWidget {
  const ViewerSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('图片查看器')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader(title: '滑动'),
          SwitchListTile(
            title: const Text('水平滑动'),
            subtitle: const Text('关闭则使用垂直滑动切换图片'),
            value: settings.viewerSwipeMode,
            onChanged: (v) async {
              await ref.read(settingsProvider.notifier).setViewerSwipeMode(v);
            },
          ),
          const Divider(),
          const _SectionHeader(title: '幻灯片'),
          ListTile(
            title: const Text('自动播放间隔'),
            subtitle: Text('${settings.slideshowInterval} 秒'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: settings.slideshowInterval > 1
                      ? () => ref.read(settingsProvider.notifier).setSlideshowInterval(settings.slideshowInterval - 1)
                      : null,
                ),
                Text('${settings.slideshowInterval}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: settings.slideshowInterval < 60
                      ? () => ref.read(settingsProvider.notifier).setSlideshowInterval(settings.slideshowInterval + 1)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
