import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tagSuggestionLimitProvider = StateProvider<int>((ref) => 12);

/// 内存缓存：key 为「serverId::query」，避免跨站点串结果、重复请求。
final _cache = <String, List<String>>{};

final tagSuggestionProvider =
    FutureProvider.autoDispose.family<List<String>, String>(
  (ref, query) async {
    if (query.isEmpty) return [];
    final repo = ref.read(booruPageStateProvider.notifier).repository;
    if (repo == null) return [];

    final key = '${repo.serverId}::$query';
    final cached = _cache[key];
    if (cached != null) return cached;

    final result = await repo.suggestTags(
      query,
      limit: ref.read(tagSuggestionLimitProvider),
    );
    _cache[key] = result;
    return result;
  },
);
