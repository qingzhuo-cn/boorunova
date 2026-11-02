// SPDX-License-Identifier: AGPL-3.0-or-later
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

/// 探索页：热门 / 最新 / 随机 三种浏览方式。
/// 通过 searchPosts 加排序元标签实现，不支持的排序由站点自行兜底。
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // 标签随当前语言在 build 时求值，因此不能是编译期常量。
  List<({String label, String query})> get _tabs => [
        (label: T.exploreHot, query: 'order:score'),
        (label: T.exploreLatest, query: 'order:id_desc'),
        (label: T.exploreRandom, query: 'order:random'),
      ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(T.explore),
        bottom: TabBar(
          controller: _tabController,
          tabs: [for (final t in _tabs) Tab(text: t.label)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final t in _tabs) _ExploreTab(key: ValueKey(t.query), query: t.query),
        ],
      ),
    );
  }
}

class _ExploreTab extends ConsumerStatefulWidget {
  const _ExploreTab({super.key, required this.query});

  final String query;

  @override
  ConsumerState<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends ConsumerState<_ExploreTab>
    with AutomaticKeepAliveClientMixin {
  /// 单页条数。探索不是「翻到第几页」，只按声明上限拉，超出交给翻页。
  static const int _pageSize = 60;

  final _scrollController = ScrollController();
  List<PostSummary> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
      // 排序元标签不是所有引擎都认：实测 safebooru（gelbooru DAPI）上
      // `order:id_desc` 命中 0 条，`order:score`/`order:random` 直接报错。
      // 所以排序查询为空时退回默认排序再取一页——宁可"排序没生效"，
      // 也不要给用户一个空白页。
      // 安全模式（Play 版首启默认开启）同样约束探索页：这里不走
      // page_state，必须自己把评级带上，否则「首启只显示安全档」在探索页失效。
      final rating = effectiveRatingForServer(
        settings: ref.read(settingsProvider),
        preferences: ref.read(userServerRepoProvider).preferencesOf(
              ref.read(booruPageStateProvider).serverId,
            ),
      );
      var result = await repo.searchPosts(
        BooruQuery(tags: widget.query, limit: _pageSize, rating: rating),
      );
      if (result.posts.isEmpty && widget.query.isNotEmpty) {
        result = await repo.searchPosts(
            BooruQuery(tags: '', limit: _pageSize, rating: rating));
      }
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

  /// 翻页。此前探索页只有一页（limit 60 拉完就没了），没有任何加载更多的入口。
  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final repo = ref.read(booruPageStateProvider.notifier).repository;
    if (repo == null) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final result = await repo.searchPosts(BooruQuery(
        tags: widget.query,
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
        // 与 page_state 同款熔断：这一页有内容但去重后没有新的，继续翻就是无限爬页
        _hasMore = result.hasMore && appended.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      // 翻页失败不清空已有内容，也不自动重试（滚动会持续触发）
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 安全模式闸门与首页同口径：否则首页拦住了、探索页照样能刷到限制级内容。
    if (safeModeBlocksBrowsing(
      safeMode: ref.watch(settingsProvider).safeMode,
      capabilities: ref.watch(activeCapabilitiesProvider),
    )) {
      return SafeModeBlockedView(
        onSwitchServer: () => context.push('/servers'),
        onOpenSettings: () => context.push('/settings/content-source'),
      );
    }
    // 站点切换后必须重拉：否则 A 站的内容会一直留在页面上
    ref.listen<String?>(
      booruPageStateProvider.select((s) => s.serverId),
      (prev, next) {
        if (prev != next) _load();
      },
    );
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
          icon: Icons.image_not_supported_outlined,
          title: _posts.isEmpty ? T.noContent : T.allPostsBlocked,
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
        ],
      ),
    );
  }
}
