// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:async';

import 'package:boorunova/boorus/engine/registry.dart';
import 'package:boorunova/data/repository/search_history/search_history_repo.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/provider/booru/tag_suggestions.dart';
import 'package:boorunova/presentation/provider/booru/trending_tags.dart';
import 'package:boorunova/presentation/screens/search/search_submission.dart';
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

  // 标签随当前语言在 build 时求值，因此不能是编译期常量。
  List<(String, String)> get _sortOptions => [
        (T.sortRelevance, ''),
        (T.sortScore, 'order:score'),
        (T.sortDate, 'order:date'),
        (T.sortRating, 'order:rating'),
      ];
  List<(String, String?)> get _ratingOptions => [
        // 用哨兵而不是 null：「全部」= 显式不过滤（见 kRatingAny）
        (T.all, kRatingAny),
        (T.safe, 's'),
        (T.questionable, 'q'),
        (T.explicit, 'e'),
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
    // 站点默认排序（§6.4）：打开页面时预选它。
    //
    // 用 read 而不是 watch，且只在这里取一次：这是「打开时的一次性初值」，
    // 用户在页内改了排序不该被站点偏好覆盖回去。
    _sort = effectiveSortForServer(
      preferences: ref
          .read(userServerRepoProvider)
          .preferencesOf(ref.read(booruPageStateProvider).serverId),
      current: _sort,
    );

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
    ];
    // 评级不再拼成 `rating:<短码>` 标签：那样会绕过引擎映射，在
    // gelbooru/rule34/safebooru 上筛出空列表（实测 rating:s → 0 条）。
    // 改为结构化回传，由 BooruQuery.rating 走各引擎自己的映射。
    context.pop<SearchSubmission>(
      (query: parts.join(' ').trim(), rating: _rating),
    );
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() => _lastQuery = '');
      return;
    }
    // 立即重建一次：清除按钮的显隐（第 134 行读 _controller.text）和底部
    // 「搜索「xxx」」按钮文案都直接依赖 controller 内容，而 controller
    // 变化本身不会触发重建。修复前它们要等 300ms debounce 到期才刷新，
    // 用户快速输入/删除时会看到按钮文案和清除图标明显滞后。
    // 注意：这里只做 O(1) 的局部重建，_lastQuery（驱动标签建议网络请求）
    // 仍然走 debounce，避免每个按键都打一次接口。
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _lastQuery = q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchHistory = ref.watch(searchHistoryRepoProvider).getAll();
    final serverId =
        ref.watch(booruPageStateProvider.select((s) => s.serverId ?? ''));
    final suggestions = _lastQuery.isNotEmpty
        ? ref.watch(
            tagSuggestionProvider((serverId: serverId, query: _lastQuery)))
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
              tooltip: T.backAction,
              onPressed: () => context.pop(''),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: T.searchTagHint,
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
                tooltip: T.clear,
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
            tooltip: T.sortBy,
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
          // 站点不支持按评级过滤时不显示这个入口：选了也不生效，用户会以为
          // 「安全筛选」已经打开，实际拿到的是限制级内容（能力声明驱动）。
          if (ref.watch(activeCapabilitiesProvider).ratingFilter)
            PopupMenuButton<String?>(
            icon: Icon(
              Icons.filter_alt,
              color: _rating != null ? theme.colorScheme.primary : null,
            ),
            tooltip: T.rating,
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
                  _controller.text.trim().isEmpty
                      ? T.searchAction
                      : T.searchFor(_controller.text.trim()),
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
            child: Text(T.noMatchingTags, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          );
        }
        return ListView.builder(
          itemCount: tags.length,
          itemBuilder: (context, i) => ListTile(
            dense: true,
            leading: Icon(Icons.tag, size: 18, color: theme.colorScheme.primary),
            title: Text(tags[i], style: const TextStyle(fontSize: 15)),
            trailing: Icon(Icons.arrow_upward, size: 16, color: theme.colorScheme.onSurfaceVariant),
            onTap: () => _submit(tags[i]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(T.suggestionsFailed, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
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
              Text(T.recentSearches,
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ref.read(searchHistoryRepoProvider).clear();
                  ref.invalidate(searchHistoryRepoProvider);
                  setState(() {});
                },
                child: Text(T.clear, style: const TextStyle(fontSize: 13)),
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
        Text(T.trendingTags,
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 12),
        trendingAsync.when(
          data: (tags) {
            if (tags.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: Text(T.noTrendingTags,
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
              child: Text(T.trendingTagsFailed,
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
