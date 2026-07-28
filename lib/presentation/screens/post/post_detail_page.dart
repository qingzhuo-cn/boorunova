import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:boorunova/data/repository/favorites/user_favorite_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/provider/tags_blocker_state.dart';
import 'package:boorunova/presentation/screens/post/post_viewer.dart';
import 'package:boorunova/presentation/widgets/media/video_viewer.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({super.key, required this.post});
  final PostSummary post;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final Set<String> _selectedTags = {};

  void _onTagTap(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _searchSelected() {
    final query = _selectedTags.join(' ');
    ref.read(booruPageStateProvider.notifier).search(query);
    context.go('/');
  }

  void _addToSearch() {
    final current = ref.read(booruPageStateProvider.notifier).currentQuery;
    final add = _selectedTags.join(' ');
    final query = current.isEmpty ? add : '$current $add';
    ref.read(booruPageStateProvider.notifier).search(query);
    context.go('/');
  }

  void _blockSelected() {
    final tags = _selectedTags.toList();
    setState(_selectedTags.clear);
    ref.read(tagsBlockerStateProvider.notifier).pushAll(tags: tags);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已屏蔽标签')),
      );
    }
  }

  void _copySelected() {
    final text = _selectedTags.join(' ');
    Clipboard.setData(ClipboardData(text: text));
    setState(_selectedTags.clear);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制标签')),
      );
    }
  }

  void _openPostViewer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostViewer(posts: [widget.post], initialIndex: 0),
      ),
    );
  }

  String _categoryLabel(String key) {
    switch (key) {
      case 'meta': return 'META';
      case 'artist': return 'ARTIST';
      case 'character': return 'CHARACTER';
      case 'copyright': return 'COPYRIGHT';
      case 'general': return 'GENERAL';
      default: return key.toUpperCase();
    }
  }

  Widget _buildTagRow(List<String> tags, String? category, ThemeData theme) {
    return Wrap(spacing: 6, runSpacing: 4, children: tags.map((tag) {
      final isSelected = _selectedTags.contains(tag);
      final chipColor = _chipColor(theme, category ?? 'general');
      return GestureDetector(
        onTap: () => _onTagTap(tag),
        child: Chip(
          label: Text(tag, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : chipColor)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          backgroundColor: isSelected ? chipColor : chipColor.withOpacity(0.15),
          side: BorderSide(color: isSelected ? chipColor : chipColor.withOpacity(0.4)),
        ),
      );
    }).toList());
  }

  Color _chipColor(ThemeData theme, String? category) {
    switch (category) {
      case 'artist': return Colors.blue;
      case 'character': return Colors.green;
      case 'copyright': return Colors.purple;
      case 'meta': return Colors.orange;
      default: return theme.colorScheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final favRepo = ref.watch(userFavoritesRepoProvider);
    final isFav = favRepo.isFavorite(post.id);
    final theme = Theme.of(context);

    final categories = <String, List<String>>{
      'meta': post.tagMeta,
      'artist': post.tagArtist,
      'character': post.tagCharacter,
      'copyright': post.tagCopyright,
      'general': post.tagGeneral,
    };
    final categorized = categories.entries.where((e) => e.value.isNotEmpty).toList();

    final imageUrl = post.sampleUrl.isNotEmpty ? post.sampleUrl : post.originalUrl;
    final isVideo = imageUrl.endsWith('.mp4') || imageUrl.endsWith('.webm');

    return Scaffold(
      appBar: AppBar(
        title: const Text(T.postDetails),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: T.share,
            onPressed: () {
              final url = post.postUrl ?? post.originalUrl;
              if (url.isNotEmpty) Share.share(url);
            },
          ),
          IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Colors.red : null),
            onPressed: () async {
              final repo = ref.read(userFavoritesRepoProvider);
              await repo.toggle(BooruPost(
                id: post.id, serverId: '', thumbnailUrl: post.thumbnailUrl,
                sampleUrl: post.sampleUrl, originalUrl: post.originalUrl,
                tags: post.tags, tagGeneral: post.tagGeneral,
                tagArtist: post.tagArtist, tagCharacter: post.tagCharacter,
                tagCopyright: post.tagCopyright, tagMeta: post.tagMeta,
                aspectRatio: post.aspectRatio, width: post.width,
                height: post.height, rating: post.rating, score: post.score,
                source: post.source, postUrl: post.postUrl,
              ));
              ref.invalidate(userFavoritesRepoProvider);
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 300,
              child: isVideo
                  ? VideoViewer(url: imageUrl)
                  : GestureDetector(
                      onTap: () => _openPostViewer(context),
                      child: ExtendedImage.network(imageUrl, fit: BoxFit.contain, cache: true,
                        loadStateChanged: (state) {
                          if (state.extendedImageLoadState == LoadState.loading) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (state.extendedImageLoadState == LoadState.failed) {
                            return const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48));
                          }
                          return state.completedWidget;
                        },
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetadataRow(icon: Icons.star_outline, label: T.score, value: post.score.toString()),
                  const SizedBox(height: 8),
                  _MetadataRow(icon: Icons.star_outline, label: T.rating, value: post.rating.toUpperCase(),
                      valueColor: post.rating == 'e' ? Colors.red : post.rating == 'q' ? Colors.orange : Colors.green),
                  const SizedBox(height: 8),
                  _MetadataRow(icon: Icons.aspect_ratio, label: T.size, value: '${post.width} x ${post.height}'),
                  if (post.source != null && post.source!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MetadataRow(icon: Icons.link, label: T.source, value: post.source!),
                  ],
                  if (post.postUrl != null && post.postUrl!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MetadataRow(icon: Icons.open_in_new, label: T.postUrl, value: post.postUrl!),
                  ],
                  const SizedBox(height: 24),
                  Row(children: [
                    Icon(Icons.label_outline, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('${T.tags} (${post.tags.length})', style: theme.textTheme.titleSmall),
                    if (_selectedTags.isNotEmpty) ...[
                      const Spacer(),
                      Text('${_selectedTags.length} 已选', style: const TextStyle(fontSize: 12)),
                    ],
                  ]),
                  const SizedBox(height: 12),
                  if (categorized.isNotEmpty)
                    for (final cat in categorized)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_categoryLabel(cat.key), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          _buildTagRow(cat.value, cat.key, theme),
                          const SizedBox(height: 8),
                        ],
                      )
                  else
                    _buildTagRow(post.tags, null, theme),
                  const SizedBox(height: 32),
                  SafeArea(child: SizedBox(width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openPostViewer(context),
                      icon: const Icon(Icons.open_in_full),
                      label: const Text(T.openFullViewer),
                    ),
                  )),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.tag,
        activeIcon: Icons.close,
        backgroundColor: theme.colorScheme.tertiary,
        foregroundColor: theme.colorScheme.onTertiary,
        visible: _selectedTags.isNotEmpty,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.search, size: 18),
            backgroundColor: theme.colorScheme.tertiary,
            foregroundColor: theme.colorScheme.onTertiary,
            label: '搜索',
            onTap: _searchSelected,
          ),
          SpeedDialChild(
            child: const Icon(Icons.add, size: 18),
            backgroundColor: theme.colorScheme.secondary,
            foregroundColor: theme.colorScheme.onSecondary,
            label: '追加',
            onTap: _addToSearch,
          ),
          SpeedDialChild(
            child: const Icon(Icons.block, size: 18),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            label: '屏蔽',
            onTap: _blockSelected,
          ),
          SpeedDialChild(
            child: const Icon(Icons.copy, size: 18),
            backgroundColor: Colors.blueGrey,
            foregroundColor: Colors.white,
            label: '复制',
            onTap: _copySelected,
          ),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.icon, required this.label, required this.value, this.valueColor});
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
      const SizedBox(width: 8),
      Text('$label: ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
      Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: valueColor),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
    ]);
  }
}
