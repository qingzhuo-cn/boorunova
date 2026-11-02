// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/app_theme.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _colorValues = [0xFF1976D2, 0xFF2E7D32, 0xFFE65100, 0xFF6A1B9A, 0xFFAD1457, 0xFF00838F];

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(T.appearance)),
      body: ListView(children: [
        SectionHeader(title: T.themeMode),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            _chip(T.modeSystem, AppThemeMode.system, Icons.brightness_auto, s.themeMode, ref),
            _chip(T.modeLight, AppThemeMode.light, Icons.light_mode, s.themeMode, ref),
            _chip(T.modeDark, AppThemeMode.dark, Icons.dark_mode, s.themeMode, ref),
            _chip(T.modeMidnight, AppThemeMode.midnight, Icons.nights_stay, s.themeMode, ref),
          ]),
        ),
        // 「跟随系统 + 系统深色」与「显式深色」观感不同是刻意设计（见
        // AppTheme.darkFor 的注释），这里把它说明出来，不让用户当成 bug。
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            T.themeModeSystemNote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        SectionHeader(title: T.accentColor),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 12, runSpacing: 12,
            children: _colorValues.map((c) {
              final sel = s.accentColor == c;
              return GestureDetector(
                onTap: () => ref.read(settingsProvider.notifier).setAccentColor(c),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(color: sel ? Theme.of(context).colorScheme.onSurface : Colors.transparent, width: 2)),
                  child: sel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                ),
              );
            }).toList(),
          ),
        ),
        SwitchListTile(
          title: Text(T.reduceAnimations),
          subtitle: Text(T.reduceAnimationsSub),
          value: s.reduceAnimations,
          onChanged: (v) => ref.read(settingsProvider.notifier).setReduceAnimations(v),
        ),
      ]),
    );
  }
}

Widget _chip(String label, AppThemeMode mode, IconData icon, AppThemeMode current, WidgetRef ref) {
  return ChoiceChip(
    label: Text(label), selected: current == mode, avatar: Icon(icon, size: 16),
    // 只写 settings：主题的唯一来源，双写会导致备份恢复后必须重启才生效
    onSelected: (_) => ref.read(settingsProvider.notifier).setThemeMode(mode),
  );
}
