// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ViewerSettingsPage extends ConsumerWidget {
  const ViewerSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(T.viewerEntry)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SectionHeader(title: T.sectionSwipe),
          SwitchListTile(
            title: Text(T.horizontalSwipe),
            subtitle: Text(T.horizontalSwipeSub),
            value: settings.viewerSwipeMode,
            onChanged: (v) async {
              await ref.read(settingsProvider.notifier).setViewerSwipeMode(v);
            },
          ),
          const Divider(),
          SectionHeader(title: T.sectionSlideshow),
          ListTile(
            title: Text(T.autoInterval),
            subtitle: Text('${settings.slideshowInterval} ${T.seconds}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: T.decrease,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: settings.slideshowInterval > 1
                      ? () => ref.read(settingsProvider.notifier).setSlideshowInterval(settings.slideshowInterval - 1)
                      : null,
                ),
                Text('${settings.slideshowInterval}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(
                  tooltip: T.increase,
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
