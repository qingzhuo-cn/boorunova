// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 建议条数上限的唯一来源是 AppSettings.tagSuggestionLimit（此前是纯内存的
/// StateProvider，全应用唯一不持久化的设置：杀进程即回到 12）。

/// 内存缓存：key 为「serverId::limit::query」，跨 provider 生命周期保留，
/// 避免重复请求。
///
/// 三条纪律：条目有上限（此前无界，长会话跨站点/跨查询会一直堆积）；
/// key 带 limit（用户改了建议条数后不能继续命中旧条数的结果）；
/// 凭据/站点信息变化时由调用方 [clearTagSuggestionCache] 主动清空。
final _cache = <String, List<String>>{};

/// 缓存条目上限，超出后按 LRU 淘汰最旧的一条。
const int kTagSuggestionCacheMax = 200;

/// 清空建议缓存。凭据保存 / 设置变更后调用。
void clearTagSuggestionCache() => _cache.clear();

/// 仅供测试：当前缓存条目数。
@visibleForTesting
int get tagSuggestionCacheSize => _cache.length;

/// 仅供测试：某个 key 是否还在缓存里（用来验证 LRU 淘汰）。
@visibleForTesting
bool tagSuggestionCacheHas(String serverId, int limit, String query) =>
    _cache.containsKey('$serverId::$limit::$query');

/// family 参数必须包含 serverId：站点切换后 serverId 变化会生成新的 provider 实例，
/// 重新执行请求，避免复用旧站点的建议结果（曾踩过的坑：family 只有 query 时，
/// 同 query 切站点会返回缓存里的旧结果）。
final tagSuggestionProvider = FutureProvider.autoDispose
    .family<List<String>, ({String serverId, String query})>((ref, arg) async {
  final query = arg.query;
  if (query.isEmpty) return [];
  final repo = ref.read(booruPageStateProvider.notifier).repository;
  if (repo == null) return [];

  // 防串结果：UI 传的 serverId 与当前实际站点不一致时直接返回空
  if (repo.serverId != arg.serverId) return [];

  final limit = ref.watch(
    settingsProvider.select((s) => s.tagSuggestionLimit),
  );
  final key = '${arg.serverId}::$limit::$query';
  final cached = _cache.remove(key);
  if (cached != null) {
    // LRU：命中即挪到最新
    _cache[key] = cached;
    return cached;
  }

  final result = await repo.suggestTags(query, limit: limit);
  _cache[key] = result;
  while (_cache.length > kTagSuggestionCacheMax) {
    _cache.remove(_cache.keys.first);
  }
  return result;
});
