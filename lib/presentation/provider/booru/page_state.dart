// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// copyWith 的哨兵值：区分「调用方没传这个参数」（保留原值）和
/// 「调用方显式传了 null」（清空）。没有哨兵时 `error ?? this.error`
/// 会让 `error: null` 静默失效，导致一次失败后错误文案永久残留。
const Object _unset = Object();

/// BooruPageNotifier.search 在没有选中站点时写入 state 的哨兵错误。
/// UI 层（_friendlyError）据此映射为本地化文案，避免把裸异常串直接
/// 展示给用户，也避免在状态层硬编码语言。
const String kNoServerSelected = 'noServerSelected';

class BooruPageState {
  const BooruPageState({
    this.posts = const [],
    this.isLoading = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
    this.serverId,
    this.pagingFailed = false,
  });

  final List<PostSummary> posts;
  final bool isLoading;

  /// 首屏 / 搜索请求的错误。为 null 表示当前结果有效。
  final String? error;
  final int currentPage;
  final bool hasMore;
  final String? serverId;

  /// 翻页失败标记。与 [error] 分开：翻页失败时已有内容可看，
  /// 不能用首屏错误态盖掉列表，只能在列表末尾给出「重试」。
  final bool pagingFailed;

  BooruPageState copyWith({
    List<PostSummary>? posts,
    bool? isLoading,
    Object? error = _unset,
    int? currentPage,
    bool? hasMore,
    Object? serverId = _unset,
    bool? pagingFailed,
  }) {
    return BooruPageState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _unset) ? this.error : error as String?,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      serverId:
          identical(serverId, _unset) ? this.serverId : serverId as String?,
      pagingFailed: pagingFailed ?? this.pagingFailed,
    );
  }
}

class BooruPageNotifier extends StateNotifier<BooruPageState> {
  BooruPageNotifier() : super(const BooruPageState());

  BooruRepository? _repo;
  String _currentQuery = '';
  String? _currentRating;
  int _requestSeq = 0;

  BooruRepository? get repository => _repo;
  String get currentQuery => _currentQuery;
  String? get currentRating => _currentRating;

  /// 切换站点。[rating] 由调用方给出「本次浏览应当使用的评级」
  /// （安全模式下就是安全档），传 null 表示沿用当前评级。
  Future<void> switchServer(BooruRepository repo, {String? rating}) async {
    _repo = repo;
    if (rating != null) _currentRating = rating;
    final seq = ++_requestSeq;
    // 清空旧站点内容并进入加载态，让切换立即有反馈；
    // serverId 变化会驱动 UI 滚动回顶
    state = state.copyWith(
      posts: const [],
      isLoading: true,
      error: null,
      currentPage: 1,
      serverId: repo.serverId,
      pagingFailed: false,
    );
    try {
      final result = await repo.searchPosts(BooruQuery(
        tags: _currentQuery,
        page: 1,
        rating: _currentRating,
      ));
      if (seq != _requestSeq) return;
      state = state.copyWith(
        posts: result.posts,
        isLoading: false,
        error: null,
        hasMore: result.hasMore,
        currentPage: 1,
      );
    } catch (e) {
      if (seq != _requestSeq) return;
      state = state.copyWith(
          isLoading: false, error: e.toString(), pagingFailed: false);
    }
  }

  Future<void> search(String query, {String? rating}) async {
    if (_repo == null) {
      state = state.copyWith(
        isLoading: false,
        error: kNoServerSelected,
        pagingFailed: false,
      );
      return;
    }
    _currentQuery = query;
    _currentRating = rating;
    final seq = ++_requestSeq;
    state = state.copyWith(
      posts: const [],
      isLoading: true,
      error: null,
      currentPage: 1,
      pagingFailed: false,
    );
    try {
      final result = await _repo!.searchPosts(BooruQuery(
        tags: query,
        page: 1,
        rating: rating,
      ));
      if (seq != _requestSeq) return;
      state = state.copyWith(
        posts: result.posts,
        isLoading: false,
        // 显式传 null：成功时必须清掉上一次的错误，否则空结果会被
        // 渲染成过期错误页。
        error: null,
        hasMore: result.hasMore,
        currentPage: 1,
      );
    } catch (e) {
      if (seq != _requestSeq) return;
      state = state.copyWith(
          isLoading: false, error: e.toString(), pagingFailed: false);
    }
  }

  Future<void> refresh() {
    return search(_currentQuery, rating: _currentRating);
  }

  Future<void> loadMore() async {
    if (_repo == null || state.isLoading || !state.hasMore) return;
    // 上一次翻页失败后不再自动重试：滚动事件会持续触发 loadMore，
    // 无节制地打一个已经失败的站点。改为等用户显式点「重试」。
    if (state.pagingFailed) return;
    final seq = ++_requestSeq;
    final nextPage = state.currentPage + 1;
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repo!.searchPosts(BooruQuery(
        tags: _currentQuery,
        page: nextPage,
        rating: _currentRating,
      ));
      if (seq != _requestSeq) return;
      // 追加前按 postKeyOf 去重：offset 型分页（danbooru/gelbooru 系/moebooru）
      // 在翻页期间有新投稿时，同一帖会同时出现在两页，于是同一路由里出现
      // 两个相同 Hero tag —— 打开详情或长按预览会直接抛
      // "multiple heroes that share the same tag"。
      final seen = state.posts.map(postKeyOf).toSet();
      final appended = <PostSummary>[];
      for (final post in result.posts) {
        if (seen.add(postKeyOf(post))) appended.add(post);
      }
      // 熔断：这一页有内容、但去重后没有一条是新的（引擎 offset/pid 退化
      // 成「永远返回同一页」）时，继续翻页就是无限爬页。此前页码照常前进、
      // hasMore 照常为真，坏掉的引擎会被一直打下去。
      final stalled = result.posts.isNotEmpty && appended.isEmpty;
      state = state.copyWith(
        posts: [...state.posts, ...appended],
        isLoading: false,
        hasMore: result.hasMore && !stalled,
        currentPage: nextPage,
        pagingFailed: false,
      );
    } catch (e) {
      if (seq != _requestSeq) return;
      // 已有内容保留，只标记翻页失败；currentPage 不前进，
      // 用户点重试时仍拉同一页。
      state = state.copyWith(isLoading: false, pagingFailed: true);
    }
  }

  /// 翻页失败后的手动重试：清标记后重拉当前页。
  Future<void> retryLoadMore() async {
    if (_repo == null || state.isLoading) return;
    state = state.copyWith(pagingFailed: false);
    await loadMore();
  }
}

final booruPageStateProvider =
    StateNotifierProvider<BooruPageNotifier, BooruPageState>((ref) {
  return BooruPageNotifier();
});
