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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String query) {
    final q = query.trim();
    if (q.isNotEmpty) ref.read(searchHistoryRepoProvider).add(q);
    context.pop(q);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchHistory = ref.watch(searchHistoryRepoProvider).getAll();
    final trendingTagsAsync = ref.watch(trendingTagsProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(''),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: const InputDecoration(
                  hintText: '搜索标签...',
                  border: InputBorder.none,
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                onSubmitted: _submit,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() {});
              },
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (searchHistory.isEmpty)
            const SizedBox(height: 120),
          if (searchHistory.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text('最近搜索', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(searchHistoryRepoProvider).clear();
                    ref.invalidate(searchHistoryRepoProvider);
                    setState(() {});
                  },
                  child: const Text('清除', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...searchHistory.map((q) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.history, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  title: Text(q, style: const TextStyle(fontSize: 15)),
                  trailing: IconButton(
                    icon: Icon(Icons.close, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                    onPressed: () {
                      ref.read(searchHistoryRepoProvider).remove(q);
                      ref.invalidate(searchHistoryRepoProvider);
                      setState(() {});
                    },
                  ),
                  onTap: () => _submit(q),
                )),
          ],
          const SizedBox(height: 24),
          Text('热门标签', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 12),
          trendingTagsAsync.when(
            data: (tags) {
              if (tags.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Text('当前站点暂无热门标签', style: TextStyle(color: Colors.grey)),
                  ),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((t) {
                  final ci = t.hashCode % _tagColors.length;
                  return GestureDetector(
                    onTap: () => _submit(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _tagColors[ci].withOpacity(0.1),
                        border: Border.all(color: _tagColors[ci].withOpacity(0.35)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tag, size: 14, color: _tagColors[ci]),
                          const SizedBox(width: 6),
                          Text(t, style: TextStyle(fontSize: 13, color: _tagColors[ci])),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: Padding(padding: EdgeInsets.only(top: 32), child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 32),
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
  Colors.brown,
  Colors.blueGrey,
];
