import 'package:boorunova/presentation/provider/tags_blocker_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BlacklistPage extends ConsumerWidget {
  const BlacklistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsBlockerStateProvider);
    final controller = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('已屏蔽标签')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: '添加屏蔽标签',
              hintText: '输入标签名，多个用空格分隔',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    final tags = text.split(RegExp(r'\s+'));
                    ref.read(tagsBlockerStateProvider.notifier).pushAll(tags: tags);
                    controller.clear();
                  }
                },
              ),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                ref.read(tagsBlockerStateProvider.notifier).pushAll(tags: value.split(RegExp(r'\s+')));
                controller.clear();
              }
            },
          ),
          const SizedBox(height: 16),
          if (tags.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Icon(Icons.block, size: 48,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text('暂无屏蔽标签',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                  ],
                ),
              ),
            ),
          for (final entry in tags.entries)
            ListTile(
              title: Text(entry.value.name),
              leading: const Icon(Icons.block, size: 20),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  ref.read(tagsBlockerStateProvider.notifier).delete(entry.key);
                },
              ),
              dense: true,
            ),
        ],
      ),
    );
  }
}
