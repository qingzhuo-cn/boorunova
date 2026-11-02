// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 图集列表页：展示当前站点支持的图集（Pool）。
/// 不支持的站点 fetchPools 返回空，显示空态。
class PoolsPage extends ConsumerStatefulWidget {
  const PoolsPage({super.key});

  @override
  ConsumerState<PoolsPage> createState() => _PoolsPageState();
}

class _PoolsPageState extends ConsumerState<PoolsPage> {
  /// 单页条数。fetchPools 没有 hasMore 口径，用"满页即可能还有"判断。
  static const int _pageSize = 20;

  final _scrollController = ScrollController();
  List<BooruPool> _pools = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    final repo = ref.read(booruPageStateProvider.notifier).repository;
    if (repo == null) {
      setState(() {
        _loading = false;
        _error = T.noServerSelected;
      });
      return;
    }
    try {
      final pools = await repo.fetchPools(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _pools = pools;
        _loading = false;
        _hasMore = pools.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = T.friendlyError(e);
      });
    }
  }

  /// 翻页。此前图集列表只有第一页，图集多的站点看不到后面的。
  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final repo = ref.read(booruPageStateProvider.notifier).repository;
    if (repo == null) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final pools = await repo.fetchPools(page: next, limit: _pageSize);
      if (!mounted) return;
      final seen = _pools.map((p) => p.id).toSet();
      final appended = pools.where((p) => seen.add(p.id)).toList();
      setState(() {
        _pools = [..._pools, ...appended];
        _page = next;
        _loadingMore = false;
        // 满页但没有新条目 → 站点在重复返回同一页，停止爬页
        _hasMore = pools.length >= _pageSize && appended.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 站点切换后重拉：图集是站点级资源
    ref.listen<String?>(
      booruPageStateProvider.select((s) => s.serverId),
      (prev, next) {
        if (prev != next) _load();
      },
    );
    return Scaffold(
      appBar: AppBar(title: Text(T.pools)),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: _error!,
        action: TextButton(onPressed: _load, child: Text(T.retry)),
      );
    }
    if (_pools.isEmpty) {
      return EmptyState(
        icon: Icons.collections_outlined,
        title: T.poolsUnsupported,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        // 末尾多一格用于「正在加载更多」的指示
        itemCount: _pools.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _pools.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final pool = _pools[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  theme.colorScheme.primaryContainer.withOpacity(0.5),
              child: Icon(Icons.collections_outlined,
                  color: theme.colorScheme.primary, size: 20),
            ),
            title: Text(
              pool.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: pool.description.isNotEmpty
                ? Text(
                    pool.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  )
                : null,
            trailing: Text(
              '${pool.postCount} ${T.poolCountUnit}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5)),
            ),
            onTap: () => context.push('/pools/${pool.id}',
                extra: {'name': pool.displayName}),
          );
        },
      ),
    );
  }
}
