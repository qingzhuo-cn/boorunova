import 'dart:async';

import 'package:boorunova/data/repository/search_history/search_history_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SortOption {
  relevance(T.sortRelevance, null),
  score(T.sortScore, 'score'),
  date(T.sortDate, 'date'),
  rating(T.sortRating, 'rating');

  const SortOption(this.label, this.queryValue);
  final String label;
  final String? queryValue;
}

final gridColumnsProvider = StateProvider<int>((ref) => 3);

final tagSuggestionProvider =
    FutureProvider.autoDispose.family<List<String>, String>(
  (ref, query) async {
    if (query.length < 1) return [];
    final repo = ref.read(booruPageStateProvider.notifier).repository;
    if (repo == null) return [];
    return repo.suggestTags(query, limit: 12);
  },
);

class HomeSearchBar extends ConsumerStatefulWidget {
  const HomeSearchBar({
    super.key,
    required this.hintText,
    required this.onSubmitted,
    this.leading,
    this.collapsed = false,
    this.onScrollToTop,
    this.currentQuery = '',
  });

  final String hintText;
  final ValueChanged<String> onSubmitted;
  final Widget? leading;
  final bool collapsed;
  final VoidCallback? onScrollToTop;
  final String currentQuery;

  @override
  ConsumerState<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends ConsumerState<HomeSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isOpen = false;
  SortOption _sort = SortOption.relevance;
  String? _ratingFilter;
  Timer? _debounce;
  String _lastQuery = '';
  bool _showSearchHistory = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.currentQuery;
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _controller.text.isEmpty) {
        setState(() => _showSearchHistory = true);
      } else {
        setState(() => _showSearchHistory = false);
      }
    });
  }

  @override
  void didUpdateWidget(HomeSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentQuery != oldWidget.currentQuery && !_isOpen) {
      _controller.text = widget.currentQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _submit() {
    _focusNode.unfocus();
    final query = _controller.text.trim();
    final sortQuery = _sort.queryValue;
    final effectiveQuery = [
      if (query.isNotEmpty) query,
      if (sortQuery != null) 'order:$sortQuery',
      if (_ratingFilter != null) 'rating:$_ratingFilter',
    ].join(' ');

    if (query.isNotEmpty) {
      ref.read(searchHistoryRepoProvider).add(query);
    }

    widget.onSubmitted(effectiveQuery);
  }

  void _clearFilters() {
    setState(() {
      _sort = SortOption.relevance;
      _ratingFilter = null;
    });
    _submit();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _showSearchHistory = value.isEmpty && _focusNode.hasFocus;
      if (value.length >= 1) _lastQuery = value;
    });

    if (value.length < 1) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (value != _lastQuery) {
        setState(() => _lastQuery = value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters = _sort != SortOption.relevance || _ratingFilter != null;
    final suggestions = _lastQuery.length >= 1
        ? ref.watch(tagSuggestionProvider(_lastQuery))
        : const AsyncData<List<String>>([]);
    final searchHistory =
        _showSearchHistory ? ref.watch(searchHistoryRepoProvider).getAll() : <String>[];

    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: AnimatedContainer(
                duration: Duration(milliseconds: ref.watch(settingsProvider).reduceAnimations ? 0 : 300),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (widget.leading != null)
                      widget.leading!,
                    IconButton(
                      icon: Icon(_isOpen ? Icons.arrow_back_rounded : Icons.search),
                      onPressed: () {
                        setState(() {
                          _isOpen = !_isOpen;
                          if (_isOpen) {
                            _controller.text = widget.currentQuery;
                          } else {
                            _controller.clear();
                            widget.onSubmitted('');
                          }
                        });
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: _isOpen,
                        readOnly: !_isOpen,
                        decoration: InputDecoration(
                          hintText: _isOpen
                              ? widget.hintText
                              : (widget.currentQuery.isNotEmpty
                                  ? widget.currentQuery
                                  : T.tapToSearch),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onTap: () {
                          if (!_isOpen) {
                            _controller.text = widget.currentQuery;
                            setState(() => _isOpen = true);
                          }
                        },
                        onChanged: _onSearchChanged,
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    if (_isOpen && hasFilters)
                      IconButton(
                        icon: const Icon(Icons.clear_all),
                        tooltip: T.clearFilters,
                        onPressed: _clearFilters,
                      ),
                    if (_isOpen)
                      IconButton(
                        icon: const Icon(Icons.tune),
                        tooltip: T.filters,
                        onPressed: () => _showFilterSheet(context),
                      ),
                    if (!_isOpen && widget.collapsed)
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_upward_rounded),
                          onPressed: widget.onScrollToTop,
                        ),
                      ),
                    if (!_isOpen && !widget.collapsed)
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () {
                            final next = ref.read(gridColumnsProvider) >= 6 ? 2 : ref.read(gridColumnsProvider) + 1;
                            ref.read(gridColumnsProvider.notifier).state = next;
                          },
                          child: Text('${ref.watch(gridColumnsProvider)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_isOpen && (_lastQuery.length >= 1 || searchHistory.isNotEmpty))
          Positioned(
            bottom: 56,
            left: 8,
            right: 8,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isOpen && _lastQuery.length >= 1)
                      suggestions.when(
                        data: (tags) {
                          if (tags.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('推荐标签', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: tags.map((t) => ActionChip(
                                  label: Text(t, style: const TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.zero,
                                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                                  onPressed: () {
                                    _controller.text = t;
                                    _controller.selection = TextSelection.fromPosition(
                                      TextPosition(offset: t.length),
                                    );
                                    setState(() => _lastQuery = '');
                                  },
                                )).toList(),
                              ),
                            ],
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.all(8),
                          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    if (searchHistory.isNotEmpty && _lastQuery.length < 2) ...[
                      if (_lastQuery.length >= 1 && (suggestions.asData?.value.isNotEmpty ?? false))
                        const Divider(height: 8),
                      Row(
                        children: [
                          Text('历史搜索', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              ref.read(searchHistoryRepoProvider).clear();
                              setState(() {});
                            },
                            child: const Text(T.clear, style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: searchHistory.map((q) => InputChip(
                          label: Text(q, style: const TextStyle(fontSize: 11)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () {
                            ref.read(searchHistoryRepoProvider).remove(q);
                            setState(() {});
                          },
                          onPressed: () {
                            _controller.text = q;
                            _controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: q.length),
                            );
                            setState(() => _showSearchHistory = false);
                          },
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        if (hasFilters)
          Positioned(
            bottom: 56,
            left: 16,
            right: 16,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (_sort != SortOption.relevance)
                  _FilterChip(
                    label: '${T.sortColon}${_sort.label}',
                    onRemove: () {
                      setState(() => _sort = SortOption.relevance);
                      _submit();
                    },
                  ),
                if (_ratingFilter != null)
                  _FilterChip(
                    label: '${T.ratingColon}${_ratingFilter!.toUpperCase()}',
                    onRemove: () {
                      setState(() => _ratingFilter = null);
                      _submit();
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(T.sortBy,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: SortOption.values.map((opt) {
                return ChoiceChip(
                  label: Text(opt.label),
                  selected: _sort == opt,
                  onSelected: (_) {
                    setState(() => _sort = opt);
                    _submit();
                    Navigator.of(ctx).pop();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(T.ratingFilter,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _ratingChip(context, ctx, T.all, null),
                _ratingChip(context, ctx, T.safe, 's'),
                _ratingChip(context, ctx, T.questionable, 'q'),
                _ratingChip(context, ctx, T.explicit, 'e'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingChip(
    BuildContext context,
    BuildContext sheetContext,
    String label,
    String? value,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: _ratingFilter == value,
      onSelected: (_) {
        setState(() => _ratingFilter = value);
        _submit();
        Navigator.of(sheetContext).pop();
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onRemove,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      ),
    );
  }
}
