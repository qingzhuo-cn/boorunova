import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tagSuggestionLimitProvider = StateProvider<int>((ref) => 12);

final tagSuggestionProvider =
    FutureProvider.autoDispose.family<List<String>, String>(
  (ref, query) async {
    if (query.length < 1) return [];
    final repo = ref.read(booruPageStateProvider.notifier).repository;
    if (repo == null) return [];
    return repo.suggestTags(query, limit: ref.read(tagSuggestionLimitProvider));
  },
);
