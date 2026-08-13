import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 图集列表页：展示当前站点支持的图集（Pool）。
/// 不支持的站点 fetchPools 返回空，显示空态。
class PoolsPage extends ConsumerStatefulWidget {
  const PoolsPage({super.key});

  @override
  ConsumerState<PoolsPage> createState() => _PoolsPageState();
}

class _PoolsPageState extends ConsumerState<PoolsPage> {
  List<BooruPool> _pools = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(booruPageStateProvider.notifier).repository;
    if (repo == null) {
      setState(() {
        _loading = false;
        _error = '未选择服务器';
      });
      return;
    }
    try {
      final pools = await repo.fetchPools();
      if (!mounted) return;
      setState(() {
        _pools = pools;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('图集')),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _Placeholder(
        icon: Icons.error_outline,
        text: _error!,
        action: TextButton(onPressed: _load, child: const Text('重试')),
      );
    }
    if (_pools.isEmpty) {
      return const _Placeholder(
        icon: Icons.collections_outlined,
        text: '当前站点不支持图集，或暂无图集',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _pools.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final pool = _pools[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  theme.colorScheme.primaryContainer.withOpacity(0.5),
              child: Icon(Icons.collections_outlined,
                  color: theme.colorScheme.primary, size: 20),
            ),
            title: Text(
              pool.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: pool.description.isNotEmpty
                ? Text(
                    pool.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  )
                : null,
            trailing: Text(
              '${pool.postCount} 张',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5)),
            ),
            onTap: () => context.push('/pools/${pool.id}',
                extra: {'name': pool.displayName}),
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5))),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
