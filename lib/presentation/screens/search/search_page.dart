import 'dart:async';

import 'package:boorunova/data/repository/search_history/search_history_repo.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final trendingTagsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final repo = ref.read(booruPageStateProvider.notifier).repository;
  if (repo == null) return [];
  return repo.fetchTrendingTags();
});

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String query) {
    if (query.trim().isNotEmpty) {
      ref.read(searchHistoryRepoProvider).add(query.trim());
    }
    context.pop(query.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchHistory = ref.watch(searchHistoryRepoProvider).getAll();
    final trendingTags = ref.watch(trendingTagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索标签...',
            border: InputBorder.none,
            isDense: true,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _submit,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _submit(_controller.text),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          if (searchHistory.isNotEmpty) ...[
            Text('搜索历史',
                style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: searchHistory.map((q) => ActionChip(
                label: Text(q, style: const TextStyle(fontSize: 13)),
                onPressed: () => _submit(q),
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('清除历史', style: TextStyle(fontSize: 12)),
              onPressed: () {
                ref.read(searchHistoryRepoProvider).clear();
                ref.invalidate(searchHistoryRepoProvider);
              },
            ),
            const Divider(height: 24),
          ],
          Text('热门标签',
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          trendingTags.when(
            data: (tags) {
              if (tags.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('当前站点暂无热门标签', style: TextStyle(color: Colors.grey)),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 6,
                children: tags.map((t) {
                  final colorIndex = t.hashCode % _tagColors.length;
                  return ActionChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tag, size: 14, color: _tagColors[colorIndex]),
                        const SizedBox(width: 4),
                        Text(t, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    backgroundColor: _tagColors[colorIndex].withOpacity(0.08),
                    side: BorderSide(color: _tagColors[colorIndex].withOpacity(0.3)),
                    onPressed: () => _submit(t),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

const _tagColors = [
  Colors.blue,
  Colors.red,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.pink,
  Colors.indigo,
  Colors.amber,
  Colors.cyan,
];
