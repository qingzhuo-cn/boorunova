import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trendingTagsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final repo = ref.read(booruPageStateProvider.notifier).repository;
  if (repo == null) return [];
  return repo.fetchTrendingTags();
});
