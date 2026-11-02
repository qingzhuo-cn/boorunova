// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart' show SectionHeader;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchSettingsPage extends ConsumerWidget {
  const SearchSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = ref.watch(
      settingsProvider.select((s) => s.tagSuggestionLimit),
    );
    return Scaffold(
      appBar: AppBar(title: Text(T.searchEntry)),
      body: ListView(children: [
        SectionHeader(title: T.sectionTagSuggest),
        ListTile(
          title: Text(T.suggestionCount),
          subtitle: Text('$limit${T.countUnit}'),
          trailing: SizedBox(
            width: 140,
            child: Slider(
              value: limit.toDouble(),
              min: minTagSuggestionLimit.toDouble(),
              max: maxTagSuggestionLimit.toDouble(),
              divisions: maxTagSuggestionLimit - minTagSuggestionLimit,
              label: '$limit',
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .setTagSuggestionLimit(v.round()),
            ),
          ),
        ),
      ]),
    );
  }
}
