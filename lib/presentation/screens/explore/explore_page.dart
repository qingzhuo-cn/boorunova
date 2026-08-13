import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/widgets/timeline/timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 探索页：热门 / 最新 / 随机 三种浏览方式。
/// 通过 searchPosts 加排序元标签实现，不支持的排序由站点自行兜底。
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    (label: '热门', query: 'order:score'),
    (label: '最新', query: 'order:id_desc'),
    (label: '随机', query: 'order:random'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('探索'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [for (final t in _tabs) Tab(text: t.label)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final t in _tabs) _ExploreTab(key: ValueKey(t.query), query: t.query),
        ],
      ),
    );
  }
}

class _ExploreTab extends ConsumerStatefulWidget {
  const _ExploreTab({super.key, required this.query});

  final String query;

  @override
  ConsumerState<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends ConsumerState<_ExploreTab>
    with AutomaticKeepAliveClientMixin {
  List<PostSummary> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
        BooruQuery(tags: widget.query, limit: 60),
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
    super.build(context);
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: theme.colorScheme.onSurface.withOpacity(0.3)),
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
        child: Text('暂无内容',
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
