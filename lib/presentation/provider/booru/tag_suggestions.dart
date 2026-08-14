import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tagSuggestionLimitProvider = StateProvider<int>((ref) => 12);

/// 内存缓存：key 为「serverId::query」，跨 provider 生命周期保留，避免重复请求。
final _cache = <String, List<String>>{};

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

  final key = '${arg.serverId}::$query';
  final cached = _cache[key];
  if (cached != null) return cached;

  final result = await repo.suggestTags(
    query,
    limit: ref.read(tagSuggestionLimitProvider),
  );
  _cache[key] = result;
  return result;
});
