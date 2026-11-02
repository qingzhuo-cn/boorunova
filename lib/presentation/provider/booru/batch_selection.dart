// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 批量选择的选中集合。
///
/// 元素是 [postKeyOf] 生成的 `serverId/postId` 复合键，不是裸 postId。
/// 切换站点时这个 notifier 不会被清空，用裸 id 会让 A 站的选中态
/// 误命中 B 站的同号帖子。
final batchSelectionProvider =
    StateNotifierProvider<BatchSelectionNotifier, Set<String>>((ref) {
  return BatchSelectionNotifier();
});

class BatchSelectionNotifier extends StateNotifier<Set<String>> {
  BatchSelectionNotifier() : super({});

  void toggle(String postKey) {
    if (state.contains(postKey)) {
      final updated = Set<String>.from(state);
      updated.remove(postKey);
      state = updated;
    } else {
      final updated = Set<String>.from(state);
      updated.add(postKey);
      state = updated;
    }
  }

  void selectAll(Iterable<String> postKeys) {
    state = Set<String>.from(postKeys);
  }

  void clear() {
    state = {};
  }

  bool get isActive => state.isNotEmpty;
}
