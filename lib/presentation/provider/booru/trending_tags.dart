// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trendingTagsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  // 订阅 serverId：修复前只 `read` 一次仓库，autoDispose 存活期间切换站点
  // 不会触发重算，新站点会继续显示旧站点的热门标签（脆弱耦合）。
  final serverId = ref.watch(booruPageStateProvider.select((s) => s.serverId));
  if (serverId == null) return const [];
  // switchServer 先赋值 notifier 的 _repo 再更新 state.serverId，所以这里
  // read 到的仓库一定属于当前 serverId。
  final repo = ref.read(booruPageStateProvider.notifier).repository;
  if (repo == null || repo.serverId != serverId) return const [];
  return repo.fetchTrendingTags();
});
