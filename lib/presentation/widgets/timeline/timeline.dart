import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/favorites/user_favorite_repo.dart';
import 'package:boorunova/presentation/widgets/sliver_masonry_grid.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

class Timeline extends StatelessWidget {
  const Timeline({
    super.key,
    required this.posts,
    required this.onPostTap,
    this.isLoading = false,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.onSelectionToggle,
    this.onLongPress,
    this.crossAxisCount,
    this.onFavorite,
  });

  final List<PostSummary> posts;
  final void Function(int index) onPostTap;
  final bool isLoading;
  final bool selectionMode;
  final Set<String> selectedIds;
  final void Function(int index)? onSelectionToggle;
  final void Function(int index)? onLongPress;
  final int? crossAxisCount;
  final void Function(int index)? onFavorite;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final axisCount = crossAxisCount ?? (screenWidth / 180).round().clamp(2, 6);

    return AppSliverMasonryGrid(
      crossAxisCount: axisCount,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childCount: posts.length + (isLoading ? axisCount * 2 : 0),
      itemBuilder: (context, index) {
        if (index < posts.length) {
          return _AnimatedTile(
            index: index,
            child: _PostTile(
              post: posts[index],
              onTap: () => onPostTap(index),
              onLongPress: onLongPress != null ? () => onLongPress!(index) : null,
              selectionMode: selectionMode,
              isSelected: selectedIds.contains(posts[index].id),
              onSelectionToggle: onSelectionToggle != null
                  ? () => onSelectionToggle!(index)
                  : null,
              onFavorite: onFavorite != null ? () => onFavorite!(index) : null,
            ),
          );
        }
        return const _ShimmerTile();
      },
    );
  }
}

class _AnimatedTile extends StatefulWidget {
  const _AnimatedTile({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_AnimatedTile> createState() => _AnimatedTileState();
}

class _AnimatedTileState extends State<_AnimatedTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: (widget.index % 20) * 15), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Transform.translate(
        offset: Offset(0, 20 * (1 - _anim.value)),
        child: widget.child,
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({
    required this.post,
    required this.onTap,
    this.onLongPress,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectionToggle,
    this.onFavorite,
  });

  final PostSummary post;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selectionMode ? onSelectionToggle : onTap,
      onLongPress: onLongPress,
      child: Hero(
        tag: selectionMode ? 'post_${post.id}_batch' : 'post_${post.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AspectRatio(
            aspectRatio: post.aspectRatio,
            child: Stack(
            fit: StackFit.expand,
              children: [
                ExtendedImage.network(
                  post.thumbnailUrl,
                  fit: BoxFit.cover,
                  cache: true,
                  cacheWidth: 360,
                  loadStateChanged: (state) {
                    if (state.extendedImageLoadState == LoadState.loading) {
                      return const _ShimmerTile();
                    }
                    if (state.extendedImageLoadState == LoadState.failed) {
                      return Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Center(child: Icon(Icons.broken_image_outlined, size: 24)),
                      );
                    }
                    return state.completedWidget;
                  },
                ),
                if (!selectionMode && onFavorite != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: onFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black26,
                          shape: BoxShape.circle,
                        ),
                        child: Consumer(
                          builder: (context, ref, _) {
                            final isFav = ref.watch(userFavoritesRepoProvider).isFavorite(post.id, serverId: post.serverId);
                            return Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              size: 14,
                              color: isFav ? Colors.red : Colors.white70,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                if (selectionMode)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black.withOpacity(0.4),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white60,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isSelected ? Icons.check : Icons.circle_outlined,
                        size: 20,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Colors.white,
                      ),
                    ),
                  ),
                if (isSelected)
                  Container(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.15),
                  ),
              ],
            ),
          ),
        ),
      ),
      );
  }
}

class _ShimmerTile extends StatelessWidget {
  const _ShimmerTile();

  @override
  Widget build(BuildContext context) {
    final heights = [120.0, 160.0, 140.0, 180.0, 100.0, 200.0];
    final height =
        heights[DateTime.now().millisecondsSinceEpoch % heights.length];

    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
