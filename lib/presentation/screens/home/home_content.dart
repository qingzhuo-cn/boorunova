// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/engine/registry.dart';
import 'package:boorunova/data/repository/favorites/user_favorite_repo.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/foundation/util/batch_ops.dart';
import 'package:boorunova/foundation/util/download_queue.dart';
import 'package:boorunova/foundation/util/image_downloader.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/booru/batch_selection.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/provider/tags_blocker_state.dart';
import 'package:boorunova/presentation/screens/home/search/search_bar.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:boorunova/presentation/widgets/common/download_feedback.dart';
import 'package:boorunova/presentation/widgets/common/glass.dart';
import 'package:boorunova/presentation/widgets/common/safe_mode_blocked.dart';
import 'package:boorunova/presentation/widgets/timeline/timeline.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

/// 底层异常 → 面向用户的提示的映射已提升到 [T.friendlyError]：
/// 此前它是本文件的私有函数，探索/图集等页面只能把英文栈直接丢给用户。

class HomeContent extends ConsumerStatefulWidget {
  const HomeContent({super.key, this.favicon});

  final Widget? favicon;

  @override
  ConsumerState<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<HomeContent> {
  bool _batchDownloading = false;
  String? _batchProgress;
  bool _searchCollapsed = false;
  final _scrollController = ScrollController();

  /// 批量下载的取消令牌。BatchOps 早就支持全链路取消，但调用点从来不传，
  /// 于是「离开页面」只是 UI 停了，后台还在继续拉几十个文件。
  CancelToken? _batchCancelToken;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 首帧之后再问「要不要续跑上次没下完的」（OPT §3.3）：initState 里弹
    // 对话框会撞上「还没挂到树上」。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeResumePendingDownloads();
    });
  }

  /// 上次没下完的条目（落盘在 [DownloadQueueStore]）。
  ///
  /// 只问一次（[consumeResumePromptSlot]）：首页会随导航重建，逐次都问
  /// 会变成骚扰。
  ///
  /// 修复前进度只在内存：被杀进程或中途退出后，用户回来既没有提示也没有
  /// 续跑入口。这里问一句；选「继续」就按存下来的 URL 重跑（配合断点续传，
  /// 已下好的部分会接着下），选「忽略」则清空，不再打扰。
  Future<void> _maybeResumePendingDownloads() async {
    List<PendingDownload> pending;
    try {
      pending = await DownloadQueueStore().pending();
    } catch (_) {
      return; // 读不出来就当没有，不影响使用
    }
    if (pending.isEmpty || !mounted || _batchDownloading) return;
    // 每次运行只问一次：首页会随导航重建，逐次都问会变成骚扰。
    // 失败的条目仍留在队列里（下次启动还能续跑），由 7 天保鲜期兜底。
    if (!consumeResumePromptSlot()) return;

    final resume = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(T.resumeDownloadsTitle),
        content: Text(T.resumeDownloadsBody(pending.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(T.ignoreAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(T.resumeAction),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (resume != true) {
      await DownloadQueueStore().clear();
      return;
    }
    await _runBatchItems(
      urls: [for (final item in pending) item.url],
      ids: [for (final item in pending) item.postId],
      namespaces: [for (final item in pending) item.namespace],
    );
  }

  @override
  void dispose() {
    // 页面销毁即取消未完成的批量下载，避免后台继续跑。
    // 取消原因是**内部**字符串（不进 UI：取消路径统一显示 T.downloadFailed），
    // 用 ASCII 免得被「硬编码中文」扫描误报。
    _batchCancelToken?.cancel('page disposed');
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final collapsed = pos.pixels > 60;
    if (collapsed != _searchCollapsed) {
      setState(() => _searchCollapsed = collapsed);
    }
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref.read(booruPageStateProvider.notifier).loadMore();
    }
  }

  void _checkFillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final pageState = ref.read(booruPageStateProvider);
      if (pageState.isLoading || !pageState.hasMore) return;
      if (pos.maxScrollExtent <= pos.viewportDimension + 100) {
        ref.read(booruPageStateProvider.notifier).loadMore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 切换站点后滚动回顶，避免停留在旧内容中间
    ref.listen<String?>(
      booruPageStateProvider.select((s) => s.serverId),
      (prev, next) {
        if (prev == next) return;
        // 切站必须清空批量选择：选中键是 serverId/postId，不清空的话
        // B 站顶部还显示 A 站的「已选 N」，批量操作也对着已经不存在的帖子。
        ref.read(batchSelectionProvider.notifier).clear();
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      },
    );
    final pageState = ref.watch(booruPageStateProvider);
    final currentQuery = ref.read(booruPageStateProvider.notifier).currentQuery;
    final gridCols = ref.watch(settingsProvider).gridColumns;
    final selectedIds = ref.watch(batchSelectionProvider);
    final selectionNotifier = ref.read(batchSelectionProvider.notifier);
    final isSelectionMode = selectedIds.isNotEmpty;
    // 与探索/图集共用同一套过滤口径
    final filteredPosts = filterBlockedPosts(
      pageState.posts,
      ref.watch(tagsBlockerStateProvider),
    );

    // 整页帖子都被黑名单屏蔽时不能停在空态：_checkFillViewport 此前要求
    // filteredPosts 非空，于是「全部屏蔽」永远等不到下一页，用户面对的是
    // 一句「没有找到帖子」的死局。
    final allBlocked = pageState.posts.isNotEmpty && filteredPosts.isEmpty;
    if (!pageState.isLoading &&
        pageState.hasMore &&
        (filteredPosts.isNotEmpty || allBlocked)) {
      _checkFillViewport();
    }

    // 安全模式 + 当前引擎不支持按评级过滤 = 无法履行安全口径。
    // 不能假装过滤了继续浏览：那等于把 Play 版首启的「只显示安全档」变成空话。
    final settings = ref.watch(settingsProvider);
    if (safeModeBlocksBrowsing(
      safeMode: settings.safeMode,
      capabilities: ref.watch(activeCapabilitiesProvider),
    )) {
      return SafeModeBlockedView(
        onSwitchServer: () => context.push('/servers'),
        onOpenSettings: () => context.push('/settings/content-source'),
      );
    }

    // Stack 布局：瀑布流铺满全屏，玻璃搜索栏悬浮在内容上方
    return Stack(
      children: [
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: () async {
              selectionNotifier.clear();
              await ref.read(booruPageStateProvider.notifier).refresh();
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                if (isSelectionMode)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.checklist,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          // 勾选数量用 liveRegion 播报（OPT §5.2）：
                          // 读屏用户逐张勾选时，只有文本变化被朗读才知道「现在选了几张」。
                          Semantics(
                            liveRegion: true,
                            label: T.selectionCountSemantics(
                                selectedIds.length),
                            child: ExcludeSemantics(
                              child: Text(
                                '${selectedIds.length} ${T.selected}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              selectionNotifier
                                  .selectAll(filteredPosts.map(postKeyOf));
                            },
                            child: Text(T.selectAll),
                          ),
                          TextButton(
                            onPressed: selectionNotifier.clear,
                            child: Text(T.clear),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (pageState.isLoading && filteredPosts.isEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (filteredPosts.isEmpty && pageState.error != null)
                  SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.cloud_off,
                      title: T.somethingWentWrong,
                      hint: T.friendlyError(pageState.error!),
                      action: OutlinedButton.icon(
                        onPressed: () =>
                            ref.read(booruPageStateProvider.notifier).refresh(),
                        icon: const Icon(Icons.refresh),
                        label: Text(T.retry),
                      ),
                    ),
                  )
                else if (filteredPosts.isEmpty)
                  SliverFillRemaining(
                    child: allBlocked
                        ? EmptyState(
                            icon: Icons.visibility_off_outlined,
                            title: T.allPostsBlocked,
                            hint: T.allPostsBlockedHint,
                            action: pageState.hasMore
                                ? OutlinedButton.icon(
                                    onPressed: () => ref
                                        .read(booruPageStateProvider.notifier)
                                        .loadMore(),
                                    icon: const Icon(Icons.expand_more),
                                    label: Text(T.loadMore),
                                  )
                                : null,
                          )
                        : EmptyState(
                            icon: Icons.image_search,
                            title: T.noSearchResults,
                            hint: T.tryDifferentSearch,
                          ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                      child: Text('${filteredPosts.length} ${T.results}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                    ),
                  ),
                  SliverPadding(
                    // 底部留白让最后一排内容能滚出悬浮玻璃栏
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 96),
                    sliver: Timeline(
                      key: ValueKey('grid_$gridCols'),
                      crossAxisCount: gridCols,
                      posts: filteredPosts,
                      enablePeekPreview: !isSelectionMode,
                      onFavorite: (index) {
                        final post = filteredPosts[index];
                        final repo = ref.read(userFavoritesRepoProvider);
                        repo.toggle(post.toPost());
                        ref.invalidate(userFavoritesRepoProvider);
                      },
                      isLoading: pageState.isLoading,
                      selectionMode: isSelectionMode,
                      selectedIds: selectedIds,
                      onPostTap: (index) {
                        context.push('/post/${filteredPosts[index].id}',
                            extra: <String, dynamic>{
                              'posts': filteredPosts,
                              'initialIndex': index,
                            });
                      },
                      onLongPress: (index) {
                        selectionNotifier
                            .toggle(postKeyOf(filteredPosts[index]));
                      },
                      onSelectionToggle: (index) {
                        selectionNotifier
                            .toggle(postKeyOf(filteredPosts[index]));
                      },
                    ),
                  ),
                  if (pageState.isLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  // 翻页失败：内容保留，末尾给出显式重试入口。
                  // 之前这里静默吞掉错误，滚动会无限重试坏掉的请求。
                  if (pageState.pagingFailed)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                        child: Column(
                          children: [
                            Text(
                              T.loadMoreFailed,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => ref
                                  .read(booruPageStateProvider.notifier)
                                  .retryLoadMore(),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: Text(T.retryLoadMore),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        // 底部悬浮玻璃搜索栏：内容从玻璃下方滚过，模糊才有实际效果
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: GlassContainer(
            child: HomeSearchBar(
              leading: widget.favicon,
              collapsed: _searchCollapsed,
              currentQuery: currentQuery,
              onScrollToTop: () {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut);
                }
              },
              hintText: T.searchHint,
              onSubmitted: (submission) {
                selectionNotifier.clear();
                // 评级走结构化字段，由引擎映射成该站认识的写法；此前搜索页把
                // `rating:s` 拼进查询串，在 gelbooru/rule34/safebooru 上恒为 0 结果。
                final notifier =
                    ref.read(booruPageStateProvider.notifier);
                notifier.search(
                  submission.query,
                  rating: effectiveRatingForServer(
                    settings: ref.read(settingsProvider),
                    preferences: ref
                        .read(userServerRepoProvider)
                        .preferencesOf(
                            ref.read(booruPageStateProvider).serverId),
                    chosen: submission.rating,
                  ),
                );
              },
            ),
          ),
        ),
        if (isSelectionMode)
          Positioned(
            left: 12,
            right: 12,
            bottom: 84,
            child: GlassContainer(
              borderRadius: BorderRadius.circular(20),
              child: _BatchActionBar(
                selectedIds: selectedIds,
                posts: filteredPosts,
                isDownloading: _batchDownloading,
                progress: _batchProgress,
                onDownload: () => _batchDownload(filteredPosts, selectedIds),
                onFavorite: () =>
                    _batchFavorite(context, filteredPosts, selectedIds),
                onShare: () => _batchShare(filteredPosts, selectedIds),
                onClear: selectionNotifier.clear,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _batchDownload(
      List<PostSummary> posts, Set<String> selectedIds) async {
    final selected =
        posts.where((p) => selectedIds.contains(postKeyOf(p))).toList();
    if (selected.isEmpty) return;
    // 同一时间只允许一批：重复点击会并发两批下载同一批文件
    if (_batchDownloading) return;

    // 与单个下载（post_viewer._download）共用同一套质量选择逻辑：
    // 设置为 sample 时批量也只取 sample，否则用户设了省流量却被
    // 静默地按原图批量下载。
    final settings = ref.read(settingsProvider);
    final repository = ref.read(booruPageStateProvider.notifier).repository;
    // 需要按需解析的帖子（视频站）先解析，否则批量下到的是一批缩略图
    final repo = ref.read(userServerRepoProvider);
    final urls = <String>[];
    for (final p in selected) {
      // 每条按**自己站点的**画质偏好解析：一批里可能跨站点
      urls.add(await resolveDownloadUrl(
        p,
        repository,
        preferSample:
            downloadQualityFor(settings, repo.preferencesOf(p.serverId)) ==
                'sample',
      ));
    }
    final ids = selected.map((p) => p.id).toList();
    final namespaces = selected.map((p) => p.serverId).toList();

    // 先把这一批落盘成「未完成」（OPT §3.3）：中途被杀进程/退出后，下次
    // 启动还能问一句「要继续吗」。落盘失败不影响本次下载。
    try {
      final at = DateTime.now();
      await DownloadQueueStore().add([
        for (var i = 0; i < urls.length; i++)
          PendingDownload(
            url: urls[i],
            postId: ids[i],
            namespace: i < namespaces.length ? namespaces[i] : '',
            addedAt: at,
          ),
      ]);
    } catch (_) {}

    await _runBatchItems(urls: urls, ids: ids, namespaces: namespaces);
  }

  /// 真正跑一批下载并汇报（进度、取消、结果、出队）。
  ///
  /// 抽出来是为了让「恢复上次未完成的下载」复用同一条路径：那条路径的 URL
  /// 是现成的，不需要再解析一遍，但进度/取消/汇报的口径必须一致。
  Future<void> _runBatchItems({
    required List<String> urls,
    required List<String> ids,
    required List<String> namespaces,
  }) async {
    if (_batchDownloading) return;
    final settings = ref.read(settingsProvider);
    final repo = ref.read(userServerRepoProvider);
    final cancelToken = CancelToken();
    _batchCancelToken = cancelToken;
    setState(() => _batchDownloading = true);

    final downloadPath = settings.downloadPath;
    final result = await BatchOps.downloadAll(
      urls,
      ids,
      namespaces: namespaces,
      downloadPath: downloadPath,
      concurrency: settings.downloadConcurrency,
      // 子目录按条目所属站点取：整批可能混着多个站点
      subdirFor: (serverId) => repo.preferencesOf(serverId).downloadSubdir,
      cancelToken: cancelToken,
      onItemProgress: (done, total) {
        if (mounted && _batchDownloading) {
          setState(() => _batchProgress = '$done/$total');
        }
      },
      // 限流提示：让用户知道进度为什么不动、以及会自动继续。
      // 批量下载里多个条目可能同时被限流，提示条自带 duration，
      // 后到的会排队而不是叠在一起。
      onRetryWait: (retryIn) {
        if (mounted) showRateLimitNotice(context, retryIn);
      },
    );
    if (identical(_batchCancelToken, cancelToken)) _batchCancelToken = null;

    // 成功的出队；**失败/取消的留在队列里**，下次启动还能续跑
    try {
      final queue = DownloadQueueStore();
      for (final item in result.items.where((i) => i.success)) {
        await queue.remove(url: item.url, postId: item.postId ?? '');
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _batchDownloading = false;
        _batchProgress = null;
      });
    }

    if (mounted) {
      // 整批都因为相册权限失败时，报数没有意义——直接给可读的授权指引
      final permissionDenied = result.successCount == 0 &&
          result.items.any((i) => i.error == kGalleryPermissionDenied);
      // 挂起超时同理：「成功 0/12」看不出原因，用户不知道重试有用
      final stalled = result.successCount == 0 &&
          result.items.any((i) => i.error == kDownloadStalled);
      // 跳过数与记录失败数要单独说：只报「成功 N/M」会让用户以为失败了
      final extras = <String>[
        if (result.skippedCount > 0)
          '${T.alreadySaved} ${result.skippedCount}${T.countUnit}',
        if (result.warningCount > 0)
          '${T.savedWithoutRecord} ${result.warningCount}${T.countUnit}',
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            permissionDenied
                ? T.galleryPermissionDenied
                : stalled
                    ? T.downloadStalled
                    : '${T.downloadedCount} ${result.successCount}/${result.items.length} ${T.ofImages}'
                    '${extras.isEmpty ? '' : '（${extras.join('，')}）'}',
          ),
          duration:
              Duration(seconds: permissionDenied || stalled || extras.isNotEmpty ? 4 : 2),
        ),
      );
    }
  }

  Future<void> _batchFavorite(BuildContext context, List<PostSummary> posts,
      Set<String> selectedIds) async {
    final selected =
        posts.where((p) => selectedIds.contains(postKeyOf(p))).toList();
    if (selected.isEmpty) return;

    final repo = ref.read(userFavoritesRepoProvider);
    for (final post in selected) {
      if (!repo.isFavorite(post.id, serverId: post.serverId)) {
        await repo.toggle(post.toPost());
      }
    }
    ref.invalidate(userFavoritesRepoProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${T.addedToFavorites} ${selected.length}')),
    );
  }

  void _batchShare(List<PostSummary> posts, Set<String> selectedIds) {
    final selected =
        posts.where((p) => selectedIds.contains(postKeyOf(p))).toList();
    if (selected.isEmpty) return;

    final urls = selected.map(permalinkOf).where((u) => u.isNotEmpty).toList();
    if (urls.isEmpty) return;

    Share.share(urls.join('\n'));
  }
}

class _BatchActionBar extends StatelessWidget {
  const _BatchActionBar({
    required this.selectedIds,
    required this.posts,
    required this.isDownloading,
    required this.onDownload,
    required this.onFavorite,
    required this.onShare,
    required this.onClear,
    this.progress,
  });

  final Set<String> selectedIds;
  final List<PostSummary> posts;
  final bool isDownloading;
  final String? progress;
  final VoidCallback onDownload;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    // 外层由 GlassContainer 提供玻璃质感，这里只负责布局
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            tooltip: T.downloadSelected,
            onPressed: isDownloading ? null : onDownload,
          ),
          if (isDownloading && progress != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(progress!, style: const TextStyle(fontSize: 13)),
            ),
          IconButton(
            icon: const Icon(Icons.favorite_outline),
            tooltip: T.favoriteSelected,
            onPressed: onFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: T.shareSelected,
            onPressed: onShare,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: T.clearSelection,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}
