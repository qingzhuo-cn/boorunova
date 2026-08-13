import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/widgets/timeline/timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 图集详情页：以 `pool:<id>` 查询展示该图集下的全部帖子。
class PoolDetailPage extends ConsumerStatefulWidget {
  const PoolDetailPage({
    super.key,
    required this.poolId,
    this.poolName = '',
  });

  final String poolId;
  final String poolName;

  @override
  ConsumerState<PoolDetailPage> createState() => _PoolDetailPageState();
}

class _PoolDetailPageState extends ConsumerState<PoolDetailPage> {
  List<PostSummary> _posts = [];
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
      final result = await repo.searchPosts(
        BooruQuery(tags: 'pool:${widget.poolId}', limit: 100),
      );
      if (!mounted) return;
      setState(() {
        _posts = result.posts;
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
      appBar: AppBar(
        title: Text(widget.poolName.isNotEmpty ? widget.poolName : '图集'),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64,
                color: theme.colorScheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(_error!,
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5))),
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_posts.isEmpty) {
      return Center(
        child: Text('该图集暂无内容',
            style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5))),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          Timeline(
            posts: _posts,
            enablePeekPreview: true,
            onPostTap: (index) {
              context.push('/post/${_posts[index].id}',
                  extra: <String, dynamic>{
                    'posts': _posts,
                    'initialIndex': index,
                  });
            },
          ),
        ],
      ),
    );
  }
}
