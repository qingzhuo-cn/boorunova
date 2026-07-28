import 'package:flutter_riverpod/flutter_riverpod.dart';

final batchSelectionProvider =
    StateNotifierProvider<BatchSelectionNotifier, Set<String>>((ref) {
  return BatchSelectionNotifier();
});

class BatchSelectionNotifier extends StateNotifier<Set<String>> {
  BatchSelectionNotifier() : super({});

  void toggle(String id) {
    if (state.contains(id)) {
      final updated = Set<String>.from(state);
      updated.remove(id);
      state = updated;
    } else {
      final updated = Set<String>.from(state);
      updated.add(id);
      state = updated;
    }
  }

  void selectAll(Iterable<String> ids) {
    state = Set<String>.from(ids);
  }

  void clear() {
    state = {};
  }

  bool get isActive => state.isNotEmpty;
}
