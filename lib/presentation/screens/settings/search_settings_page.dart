import 'package:boorunova/presentation/screens/home/search/search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchSettingsPage extends ConsumerWidget {
  const SearchSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cols = ref.watch(gridColumnsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('搜索设置')),
      body: ListView(children: [
        ListTile(
          title: const Text('建议标签数量'),
          subtitle: Text('当前: $cols 个'),
          trailing: SizedBox(
            width: 120,
            child: Slider(
              value: cols.toDouble(), min: 4, max: 20, divisions: 16,
              label: '$cols',
              onChanged: (v) => ref.read(gridColumnsProvider.notifier).state = v.round(),
            ),
          ),
        ),
      ]),
    );
  }
}
