// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/engine/registry.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/provider/tags_blocker_state.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:boorunova/presentation/widgets/common/safe_mode_blocked.dart';
import 'package:boorunova/presentation/widgets/timeline/timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 图集详情页：以 `pool:<id>` 查询展示该图集下的帖子。
///
/// 分页是必须的：danbooru 的 `pool:` 查询单页上限 100 条，此前只拉一页就
/// 结束，超过 100 张的图集被静默截断（用户以为图集就这么大）。
class PoolDetailPage extends ConsumerStatefulWidget {
  const PoolDetailPage({
    super.key,
    required this.poolId,
    this.poolName = '',
  });

  final String poolId;
  final String poolName;

  @override
  ConsumerState<PoolDetailPage> createState() => _PoolDetailPageState();
}

class _PoolDetailPageState extends ConsumerState<PoolDetailPage> {
  /// 单页条数：取站点普遍认的上限（danbooru `pool:` 单页 100）。
  static const int _pageSize = 100;

  final _scrollController = ScrollController();
  List<PostSummary> _posts = [];
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
    if (pos.pixels >= pos.maxScrollExtent - 400) _loadMore();
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
      // 安全模式同样约束图集（不走 page_state，评级要自己带）
      final result = await repo.searchPosts(BooruQuery(
        tags: 'pool:${widget.poolId}',
        limit: _pageSize,
        rating: effectiveRatingForServer(
          settings: ref.read(settingsProvider),
          preferences: ref.read(userServerRepoProvider).preferencesOf(
                ref.read(booruPageStateProvider).serverId,
              ),
        ),
      ));
      if (!mounted) return;
      setState(() {
        _posts = result.posts;
        _loading = false;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = T.friendlyError(e);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final repo = ref.read(booruPageStateProvider.notifier).repository;
    if (repo == null) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final result = await repo.searchPosts(BooruQuery(
        tags: 'pool:${widget.poolId}',
        page: next,
        limit: _pageSize,
        rating: effectiveRatingForServer(
          settings: ref.read(settingsProvider),
          preferences: ref.read(userServerRepoProvider).preferencesOf(
                ref.read(booruPageStateProvider).serverId,
              ),
        ),
      ));
      if (!mounted) return;
      final seen = _posts.map(postKeyOf).toSet();
      final appended =
          result.posts.where((p) => seen.add(postKeyOf(p))).toList();
      setState(() {
        _posts = [..._posts, ...appended];
        _page = next;
        _loadingMore = false;
        // 有内容但去重后没有新的 → 熔断，避免无限爬页
        _hasMore = result.hasMore && appended.isNotEmpty;
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
    // 站点切换后重拉：图集属于站点，跨站点的 pool id 没有意义
    ref.listen<String?>(
      booruPageStateProvider.select((s) => s.serverId),
      (prev, next) {
        if (prev != next) _load();
      },
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.poolName.isNotEmpty ? widget.poolName : T.pools),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // 与首页/探索同口径的安全模式闸门
    if (safeModeBlocksBrowsing(
      safeMode: ref.watch(settingsProvider).safeMode,
      capabilities: ref.watch(activeCapabilitiesProvider),
    )) {
      return SafeModeBlockedView(
        onSwitchServer: () => context.push('/servers'),
        onOpenSettings: () => context.push('/settings/content-source'),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: EmptyState(
          icon: Icons.error_outline,
          title: _error!,
          action: OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: Text(T.retry),
          ),
        ),
      );
    }
    // 黑名单过滤与首页同一口径
    final posts = filterBlockedPosts(_posts, ref.watch(tagsBlockerStateProvider));
    if (posts.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.collections_bookmark_outlined,
          title: _posts.isEmpty ? T.poolEmpty : T.allPostsBlocked,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          Timeline(
            posts: posts,
            isLoading: _loadingMore,
            enablePeekPreview: true,
            onPostTap: (index) {
              context.push('/post/${posts[index].id}',
                  extra: <String, dynamic>{
                    'posts': posts,
                    'initialIndex': index,
                  });
            },
          ),
          if (_hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: _loadMore,
                    icon: const Icon(Icons.expand_more, size: 18),
                    label: Text(T.loadMore),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
