// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(settingsProvider).language;
    final theme = Theme.of(context);

    Widget tile(String code, IconData icon, String name, String subtitle) {
      // 'system' 不能用 startsWith：它既不以 zh 也不以 en 开头，但
      // 'en' 之前的实现用 startsWith 是为了兼容 'en-US' 这类历史值。
      final selected = code == kLanguageSystem
          ? language == kLanguageSystem
          : language.startsWith(code);
      return ListTile(
        leading: Icon(icon,
            color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
        title: Text(name),
        subtitle: Text(subtitle),
        trailing: selected
            ? Icon(Icons.check, color: theme.colorScheme.primary)
            : null,
        onTap: () {
          ref.read(settingsProvider.notifier).setLanguage(code);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(T.language)),
      body: ListView(children: [
        tile('zh', Icons.language, T.langZhName,
            T.isEn ? 'Chinese (Simplified)' : T.currentLanguage),
        tile('en', Icons.abc, T.langEnName,
            T.isEn ? T.currentLanguage : 'English (US)'),
        // 跟随系统（OPT §5.1）：此前只有手动 zh/en，系统语言是英文的用户
        // 装完还是中文，得自己去设置里翻一遍。
        tile(kLanguageSystem, Icons.settings_suggest_outlined, T.langSystemName,
            T.langSystemSub),
      ]),
    );
  }
}
