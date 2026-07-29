import 'package:boorunova/presentation/screens/home/search/search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchSettingsPage extends ConsumerWidget {
  const SearchSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = ref.watch(tagSuggestionLimitProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('搜索设置')),
      body: ListView(children: [
        ListTile(
          title: const Text('建议标签数量'),
          subtitle: Text('$limit 个'),
          trailing: SizedBox(
            width: 140,
            child: Slider(
              value: limit.toDouble(), min: 4, max: 20, divisions: 16,
              label: '$limit',
              onChanged: (v) => ref.read(tagSuggestionLimitProvider.notifier).state = v.round(),
            ),
          ),
        ),
      ]),
    );
  }
}
