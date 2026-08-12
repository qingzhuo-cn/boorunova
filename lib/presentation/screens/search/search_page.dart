import 'dart:async';

import 'package:boorunova/data/repository/search_history/search_history_repo.dart';
import 'package:boorunova/presentation/provider/booru/tag_suggestions.dart';
import 'package:boorunova/presentation/provider/booru/trending_tags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initialQuery = ''});

  /// 进入搜索页时预填的查询词，用于在已有搜索基础上编辑。
  final String initialQuery;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _lastQuery = '';
  String _sort = '';
  String? _rating;

  static const _sortOptions = [
    ('相关度', ''),
    ('分数', 'order:score'),
    ('日期', 'order:date'),
    ('分级', 'order:rating'),
  ];
  static const _ratingOptions = [
    ('全部', null),
    ('安全', 's'),
    ('可疑', 'q'),
    ('限制级', 'e'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) {
      _controller.text = widget.initialQuery;
      _lastQuery = widget.initialQuery;
      // 光标移到末尾，方便继续编辑
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.initialQuery.length),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    ref.read(searchHistoryRepoProvider).add(q);
    final parts = <String>[
      if (q.isNotEmpty) q,
      if (_sort.isNotEmpty) _sort,
      if (_rating != null) 'rating:$_rating',
    ];
    context.pop(parts.join(' '));
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() => _lastQuery = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _lastQuery = q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchHistory = ref.watch(searchHistoryRepoProvider).getAll();
    final suggestions = _lastQuery.isNotEmpty
        ? ref.watch(tagSuggestionProvider(_lastQuery))
        : const AsyncData<List<String>>([]);
    final trendingAsync = ref.watch(trendingTagsProvider);

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
                onChanged: _onChanged,
                onSubmitted: _submit,
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  _onChanged('');
                },
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.sort,
              color: _sort.isNotEmpty ? theme.colorScheme.primary : null,
            ),
            tooltip: '排序',
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => [
              for (final (label, value) in _sortOptions)
                PopupMenuItem(
                  value: value,
                  child: Row(
                    children: [
                      if (_sort == value)
                        Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(label, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
          PopupMenuButton<String?>(
            icon: Icon(
              Icons.filter_alt,
              color: _rating != null ? theme.colorScheme.primary : null,
            ),
            tooltip: '分级',
            onSelected: (v) => setState(() => _rating = v),
            itemBuilder: (_) => [
              for (final (label, value) in _ratingOptions)
                PopupMenuItem(
                  value: value,
                  child: Row(
                    children: [
                      if (_rating == value)
                        Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(label, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _lastQuery.isNotEmpty
                ? _buildSuggestions(theme, suggestions)
                : _buildOverview(theme, searchHistory, trendingAsync),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => _submit(_controller.text),
                icon: const Icon(Icons.search),
                label: Text(
                  _controller.text.trim().isEmpty ? '搜索' : '搜索「${_controller.text.trim()}」',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(ThemeData theme, AsyncValue<List<String>> suggestions) {
    return suggestions.when(
      data: (tags) {
        if (tags.isEmpty) {
          return Center(
            child: Text('没有匹配的标签', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          );
        }
        return ListView.builder(
          itemCount: tags.length,
          itemBuilder: (context, i) => ListTile(
            dense: true,
            leading: Icon(Icons.tag, size: 18, color: theme.colorScheme.primary),
            title: Text(tags[i], style: const TextStyle(fontSize: 15)),
            trailing: const Icon(Icons.arrow_upward, size: 16, color: Colors.grey),
            onTap: () => _submit(tags[i]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text('建议加载失败', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      ),
    );
  }

  Widget _buildOverview(
    ThemeData theme,
    List<String> searchHistory,
    AsyncValue<List<String>> trendingAsync,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (searchHistory.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text('最近搜索',
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
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
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: searchHistory.map((q) => InputChip(
              label: Text(q, style: const TextStyle(fontSize: 13)),
              onDeleted: () {
                ref.read(searchHistoryRepoProvider).remove(q);
                ref.invalidate(searchHistoryRepoProvider);
                setState(() {});
              },
              onPressed: () => _submit(q),
              visualDensity: VisualDensity.compact,
            )).toList(),
          ),
          const SizedBox(height: 20),
        ],
        Text('热门标签',
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 12),
        trendingAsync.when(
          data: (tags) {
            if (tags.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: Text('当前站点暂无热门标签',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((t) {
                final ci = t.hashCode.abs() % _tagColors.length;
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
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text('热门标签加载失败',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
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
