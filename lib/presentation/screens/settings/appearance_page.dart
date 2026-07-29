import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _colorValues = [0xFF1976D2, 0xFF2E7D32, 0xFFE65100, 0xFF6A1B9A, 0xFFAD1457, 0xFF00838F];

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: ListView(children: [
        _header('主题模式'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('系统', AppThemeMode.system, Icons.brightness_auto, s.themeMode, ref),
            _chip('浅色', AppThemeMode.light, Icons.light_mode, s.themeMode, ref),
            _chip('深色', AppThemeMode.dark, Icons.dark_mode, s.themeMode, ref),
            _chip('午夜', AppThemeMode.midnight, Icons.nights_stay, s.themeMode, ref),
          ]),
        ),
        _header('主题色'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 12, runSpacing: 12,
            children: _colorValues.map((c) {
              final sel = s.accentColor == c;
              return GestureDetector(
                onTap: () => ref.read(settingsProvider.notifier).setAccentColor(c),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 2)),
                  child: sel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                ),
              );
            }).toList(),
          ),
        ),
        SwitchListTile(
          title: const Text('减少动画'),
          subtitle: const Text('提升低端设备流畅度'),
          value: s.reduceAnimations,
          onChanged: (v) => ref.read(settingsProvider.notifier).setReduceAnimations(v),
        ),
      ]),
    );
  }
}

Widget _header(String t) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)),
  );
}

Widget _chip(String label, AppThemeMode mode, IconData icon, AppThemeMode current, WidgetRef ref) {
  return ChoiceChip(
    label: Text(label), selected: current == mode, avatar: Icon(icon, size: 16),
    onSelected: (_) {
      ref.read(settingsProvider.notifier).setThemeMode(mode);
      ref.read(appThemeModeProvider.notifier).state = mode;
    },
  );
}
