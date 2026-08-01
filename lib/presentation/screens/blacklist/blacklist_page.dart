import 'package:boorunova/presentation/provider/tags_blocker_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BlacklistPage extends ConsumerStatefulWidget {
  const BlacklistPage({super.key});

  @override
  ConsumerState<BlacklistPage> createState() => _BlacklistPageState();
}

class _BlacklistPageState extends ConsumerState<BlacklistPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTags(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    ref.read(tagsBlockerStateProvider.notifier).pushAll(tags: trimmed.split(RegExp(r'\s+')));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsBlockerStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('已屏蔽标签')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: '添加屏蔽标签',
              hintText: '输入标签名，多个用空格分隔',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _addTags(_controller.text),
              ),
            ),
            onSubmitted: _addTags,
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
