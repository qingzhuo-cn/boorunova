// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'dart:async';

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/favorites/user_favorite_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/theme/app_dimens.dart';
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
    this.enablePeekPreview = false,
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

  /// 长按浮起放大镜预览（非多选模式下生效）。
  final bool enablePeekPreview;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final axisCount = crossAxisCount ?? (screenWidth / 180).round().clamp(2, 6);
    // 按实际显示宽度解码缩略图：物理像素 = 逻辑宽度 × DPR，防 OOM 且不糊
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final decodeWidth = (screenWidth / axisCount * dpr).round();

    return AppSliverMasonryGrid(
      crossAxisCount: axisCount,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      childCount: posts.length + (isLoading ? axisCount * 2 : 0),
      itemBuilder: (context, index) {
        if (index < posts.length) {
          return _AnimatedTile(
            // 身份跟内容走：Sliver 按 index 复用元素，黑名单增删导致
            // filteredPosts 位移而列表长度不变时，同一 index 会换绑到另一个
            // 帖子；配合 gaplessPlayback，用户会一直看到上一个帖子已解码的帧
            // （点进去是 B，看到的是 A）。挂 key 后 index 换帖即重建元素。
            key: ValueKey(postKeyOf(posts[index])),
            // 与 key 同源的帖子身份：入场动画靠它跨 State 记住「已播过」，
            // 修掉滚回重播（见 _AnimatedTileState）。
            identityKey: postKeyOf(posts[index]),
            index: index,
            child: _PostTile(
              post: posts[index],
              decodeWidth: decodeWidth,
              onTap: () => onPostTap(index),
              enablePeekPreview: enablePeekPreview,
              onLongPress:
                  onLongPress != null ? () => onLongPress!(index) : null,
              selectionMode: selectionMode,
              isSelected: selectedIds.contains(postKeyOf(posts[index])),
              onSelectionToggle: onSelectionToggle != null
                  ? () => onSelectionToggle!(index)
                  : null,
              onFavorite: onFavorite != null ? () => onFavorite!(index) : null,
            ),
          );
        }
        return _ShimmerTile(index: index);
      },
    );
  }
}

class _AnimatedTile extends ConsumerStatefulWidget {
  const _AnimatedTile({
    super.key,
    required this.identityKey,
    required this.index,
    required this.child,
  });

  /// 帖子身份（serverId/postId）。用于跨 State 记住「这个帖子已入场过」，
  /// 滚出屏幕再滚回来时不再重播。
  final String identityKey;
  final int index;
  final Widget child;

  @override
  ConsumerState<_AnimatedTile> createState() => _AnimatedTileState();
}

class _AnimatedTileState extends ConsumerState<_AnimatedTile>
    with SingleTickerProviderStateMixin {
  /// 已播过入场动画的帖子身份（进程级）。
  ///
  /// 瀑布流的 Sliver 在滚出缓存区时会销毁元素，滚回来重建 State；只在
  /// State 里记标志挡不住重播——用户每滚回一屏，瓦片就集体再淡入一次。
  /// 用帖子身份跨 State 记忆，保证每个帖子只入场一次。超过上限整体清空，
  /// 避免长会话里无界增长（清空后最坏情况是再播一轮）。
  static final Set<String> _played = <String>{};
  static const int _playedLimit = 2000;

  AnimationController? _controller;
  Animation<double>? _anim;
  Timer? _delayTimer;

  void _markPlayed(String key) {
    if (_played.length >= _playedLimit) _played.clear();
    _played.add(key);
  }

  @override
  void initState() {
    super.initState();
    if (_played.contains(widget.identityKey)) return;
    _markPlayed(widget.identityKey);
    // 「减少动画」开启时跳过入场动画，仅保留静态内容
    if (ref.read(settingsProvider).reduceAnimations) return;
    final controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _controller = controller;
    _anim = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
    // Timer 可在 dispose 时取消，避免快速滚动后仍排队 forward
    _delayTimer = Timer(Duration(milliseconds: (widget.index % 20) * 15), () {
      if (mounted) controller.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 运行中切换「减少动画」要立即生效：修复前只在 initState 读一次，
    // 开关对已经建好的瓦片完全无效。
    ref.listen(settingsProvider.select((s) => s.reduceAnimations), (prev, next) {
      if (next == prev || !next) return;
      // 打开「减少动画」：把正在播的淡入推到终态并重建一次，
      // 避免瓦片停在半透明/带位移的中间帧。
      _delayTimer?.cancel();
      _controller?.value = 1.0;
      if (mounted) setState(() {});
    });

    final anim = _anim;
    if (anim == null) return widget.child;
    return FadeTransition(
      opacity: anim,
      child: Transform.translate(
        offset: Offset(0, 20 * (1 - anim.value)),
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
    this.enablePeekPreview = false,
    this.decodeWidth = 360,
  });

  final PostSummary post;
  final int decodeWidth;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;
  final VoidCallback? onFavorite;
  final bool enablePeekPreview;

  void _showPeekPreview(BuildContext context) {
    final url = post.sampleUrl.isNotEmpty ? post.sampleUrl : post.thumbnailUrl;
    if (url.isEmpty) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogCtx, _, __) {
        return _PeekPreviewOverlay(
          heroTag: 'post_${post.serverId}_${post.id}',
          url: url,
          onDismiss: () => Navigator.of(dialogCtx).pop(),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = isVideoPost(post);
    final showMeta = isVideo || post.score != 0;
    // 坏数据兜底（覆盖所有引擎）：aspectRatio <= 0 / NaN / 无穷会让
    // AspectRatio 直接抛断言，挂掉整页；各 parser 只挡住 height 不挡 width。
    final rawAspect = post.aspectRatio;
    final aspectRatio =
        rawAspect > 0 && rawAspect.isFinite ? rawAspect : 1.0;
    // 无障碍（OPT §5.2）：瓦片此前对读屏用户只是一张图——既没有「可以点开」
    // 的按钮角色，也没有任何文本。这里补上标签与角色；批量选择模式下还要把
    // 「选中/未选中」播报出来，否则勾选状态对读屏用户完全不可见。
    return Semantics(
      label: T.viewPostSemantics(post.id, isVideo: isVideo),
      button: true,
      selected: selectionMode ? isSelected : null,
      // 读屏的「双击激活」必须落到同一个动作上：只给标签不给 onTap 的话，
      // TalkBack 用户听得见「按钮」却点不动（手势在 GestureDetector 里，
      // 而读屏走的是语义动作，不经过手势竞技场）。
      onTap: selectionMode ? onSelectionToggle : onTap,
      child: GestureDetector(
      onTap: selectionMode ? onSelectionToggle : onTap,
      // 手势节点自己也会生成一个语义节点（无标签的「按钮」）→ 与上面的
      // Semantics 重复播报同一个「打开帖子」动作。排除它的语义，只留一个。
      excludeFromSemantics: true,
      onLongPress: enablePeekPreview && !selectionMode
          ? () => _showPeekPreview(context)
          : onLongPress,
      child: Hero(
        tag: selectionMode
            ? 'post_${post.serverId}_${post.id}_batch'
            : 'post_${post.serverId}_${post.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusS),
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExtendedImage.network(
                  post.thumbnailUrl,
                  fit: BoxFit.cover,
                  cache: true,
                  cacheWidth: decodeWidth,
                  gaplessPlayback: true,
                  // 挂起连接（TCP 建好但服务端不回数据）不会自己判失败：
                  // 没有 timeLimit 时 shimmer 会一直转下去。8 秒对齐侧栏
                  // 头图的口径，再给一次有限重试。
                  timeLimit: const Duration(seconds: 8),
                  retries: 1,
                  loadStateChanged: (state) {
                    if (state.extendedImageLoadState == LoadState.loading) {
                      return const _ShimmerTile();
                    }
                    if (state.extendedImageLoadState == LoadState.failed) {
                      return Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Center(
                            child: Icon(Icons.broken_image_outlined, size: 24)),
                      );
                    }
                    return state.completedWidget;
                  },
                ),
                if (showMeta)
                  // 底部渐变 + 元信息徽章：评分 / 视频标识（不拦截点击）
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 14, 6, 3),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                        child: Row(
                          children: [
                            if (isVideo)
                              const Icon(Icons.play_circle_fill,
                                  size: 14, color: Colors.white70),
                            // 视频站给得出时长（`05:12`）：显示出来，用户不必点开
                            // 才知道多长。此前这个值被塞在 uploader 里、无人消费。
                            if (isVideo && (post.duration?.isNotEmpty ?? false))
                              Padding(
                                padding: const EdgeInsets.only(left: 3),
                                child: Text(
                                  post.duration!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    height: 1.2,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            if (post.score != 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.thumb_up,
                                      size: 10, color: Colors.white70),
                                  const SizedBox(width: 3),
                                  Text(
                                    T.compactScore(post.score),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      height: 1.2,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (!selectionMode && onFavorite != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    // 收藏按钮此前是个**没有标签**的可点节点：读屏只会念「按钮」，
                    // 用户不知道它是干什么的（OPT §5.2）。它必须独立成节点，
                    // 不能并进「打开帖子」那一个——两个动作不能被合成一句话。
                    child: Consumer(
                      builder: (context, ref, _) {
                        // select 精确订阅：只在该帖收藏状态翻转时重建此图标，
                        // 其余 tile 的收藏变化不再触发整屏重建
                        final isFav = ref.watch(
                          userFavoritesRepoProvider.select(
                            (repo) => repo.isFavorite(post.id,
                                serverId: post.serverId),
                          ),
                        );
                        return Semantics(
                          label: T.favoriteToggleSemantics(isFav),
                          button: true,
                          onTap: onFavorite,
                          child: GestureDetector(
                            onTap: onFavorite,
                            excludeFromSemantics: true,
                            // 外层透明内边距扩大触控区至约 40dp，视觉气泡保持小巧
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Colors.black26,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isFav ? Icons.favorite : Icons.favorite_border,
                                  size: 16,
                                  color: isFav ? Colors.red : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (selectionMode)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
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
                          size: 16,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (isSelected)
                  Container(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// 长按速览浮层：圆角大图 + 松手即关。
class _PeekPreviewOverlay extends StatelessWidget {
  const _PeekPreviewOverlay({
    required this.heroTag,
    required this.url,
    required this.onDismiss,
  });

  final String heroTag;
  final String url;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: onDismiss,
      onLongPressEnd: (_) => onDismiss(),
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Hero(
            tag: heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width * 0.85,
                  maxHeight: size.height * 0.7,
                ),
                child: ExtendedImage.network(
                  url,
                  fit: BoxFit.contain,
                  cache: true,
                  loadStateChanged: (state) {
                    if (state.extendedImageLoadState == LoadState.loading) {
                      return Container(
                        width: 200,
                        height: 260,
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      );
                    }
                    if (state.extendedImageLoadState == LoadState.failed) {
                      return Container(
                        width: 200,
                        height: 260,
                        color: Colors.black54,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: Colors.white54, size: 40),
                        ),
                      );
                    }
                    return state.completedWidget;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerTile extends StatelessWidget {
  const _ShimmerTile({this.index = 0});

  final int index;

  // 固定轮换高度（按 index），避免每次重建随机变化导致瀑布流抖动
  static const _heights = [120.0, 160.0, 140.0, 180.0, 100.0, 200.0];

  @override
  Widget build(BuildContext context) {
    final height = _heights[index % _heights.length];

    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimens.radiusS),
        ),
      ),
    );
  }
}
