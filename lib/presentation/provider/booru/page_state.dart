import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BooruPageState {
  const BooruPageState({
    this.posts = const [],
    this.isLoading = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
  });

  final List<PostSummary> posts;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final bool hasMore;

  BooruPageState copyWith({
    List<PostSummary>? posts,
    bool? isLoading,
    String? error,
    int? currentPage,
    bool? hasMore,
  }) {
    return BooruPageState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class BooruPageNotifier extends StateNotifier<BooruPageState> {
  BooruPageNotifier() : super(const BooruPageState());

  BooruRepository? _repo;
  String _currentQuery = '';
  String? _currentRating;

  BooruRepository? get repository => _repo;
  String get currentQuery => _currentQuery;

  void setRepository(BooruRepository repo) {
    _repo = repo;
  }

  Future<void> search(String query, {String? rating}) async {
    if (_repo == null) {
      state = state.copyWith(isLoading: false, error: '未选择服务器');
      return;
    }
    _currentQuery = query;
    _currentRating = rating;
    state = state.copyWith(posts: const [], isLoading: true, error: null, currentPage: 1);
    try {
      final result = await _repo!.searchPosts(BooruQuery(
        tags: query,
        page: 1,
        rating: rating,
      ));
      state = state.copyWith(
        posts: result.posts,
        isLoading: false,
        hasMore: result.hasMore,
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> refresh() {
    return search(_currentQuery, rating: _currentRating);
  }

  Future<void> loadMore() async {
    if (_repo == null || state.isLoading || !state.hasMore) return;
    final nextPage = state.currentPage + 1;
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repo!.searchPosts(BooruQuery(
        tags: _currentQuery,
        page: nextPage,
        rating: _currentRating,
      ));
      state = state.copyWith(
        posts: [...state.posts, ...result.posts],
        isLoading: false,
        hasMore: result.hasMore,
        currentPage: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final booruPageStateProvider =
    StateNotifierProvider<BooruPageNotifier, BooruPageState>((ref) {
  return BooruPageNotifier();
});
