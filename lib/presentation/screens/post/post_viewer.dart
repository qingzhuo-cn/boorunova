import 'dart:async';

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:boorunova/data/repository/favorites/user_favorite_repo.dart';
import 'package:boorunova/data/repository/history/user_history_repo.dart';
import 'package:boorunova/foundation/util/image_downloader.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/download_progress.dart';
import 'package:boorunova/presentation/widgets/media/video_viewer.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

class PostViewer extends ConsumerStatefulWidget {
  const PostViewer({
    super.key,
    required this.posts,
    required this.initialIndex,
  });

  final List<PostSummary> posts;
  final int initialIndex;

  @override
  ConsumerState<PostViewer> createState() => _PostViewerState();
}

class _PostViewerState extends ConsumerState<PostViewer>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _saving = false;
  bool _slideshowPlaying = false;
  Timer? _slideshowTimer;

  // 跟手下滑 dismiss 状态
  final _dragOffset = ValueNotifier<double>(0);
  late final AnimationController _springController;
  Animation<double>? _springAnim;
  VoidCallback? _springListener;

  static const _dismissThreshold = 140.0; // 超过此位移松手即关闭

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.black,
    ));
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _trackHistory(widget.posts[_currentIndex]);
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _springController.dispose();
    _dragOffset.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));
    _pageController.dispose();
    super.dispose();
  }

  void _toggleSlideshow() {
    if (_slideshowPlaying) {
      _slideshowTimer?.cancel();
      setState(() => _slideshowPlaying = false);
    } else {
      final interval = ref.read(settingsProvider).slideshowInterval;
      _slideshowTimer = Timer.periodic(Duration(seconds: interval), (_) {
        if (_currentIndex < widget.posts.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        } else {
          _slideshowTimer?.cancel();
          setState(() => _slideshowPlaying = false);
        }
      });
      setState(() => _slideshowPlaying = true);
    }
  }

  void _trackHistory(PostSummary post) {
    ref.read(userHistoryRepoProvider).add(post);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.posts[_currentIndex];
    final favRepo = ref.watch(userFavoritesRepoProvider);
    final isFav = favRepo.isFavorite(post.id, serverId: post.serverId);
    final isVideo = _isVideoUrl(post.originalUrl) || _isVideoUrl(post.sampleUrl);
    // 翻页方向：true=横向翻页（纵轴留给下滑关闭），false=纵向翻页（横轴留给侧滑关闭）
    final horizontalPages = ref.watch(settingsProvider).viewerSwipeMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ValueListenableBuilder<double>(
          valueListenable: _dragOffset,
          builder: (context, offset, child) {
            final fade = 1.0 - (offset.abs() / 400).clamp(0.0, 1.0);
            return Opacity(opacity: fade, child: child);
          },
          child: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
        title: Text(
          '${_currentIndex + 1} / ${widget.posts.length}',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          if (widget.posts.length > 1 && !isVideo)
            IconButton(
              icon: Icon(_slideshowPlaying ? Icons.pause_circle_filled : Icons.auto_awesome),
              tooltip: _slideshowPlaying ? '停止自动切换' : '自动切换',
              onPressed: _toggleSlideshow,
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: T.share,
            onPressed: () => _share(post),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: T.postDetails,
            onPressed: () => _showDetails(context, post),
          ),
          IconButton(
            icon: _saving
                ? _DownloadProgressIcon(post: post)
                : const Icon(Icons.download_outlined),
            onPressed: _saving ? null : () => _download(post),
          ),
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.red : Colors.white,
            ),
            onPressed: () async {
              final repo = ref.read(userFavoritesRepoProvider);
              await repo.toggle(BooruPost(
                id: post.id,
                serverId: post.serverId,
                thumbnailUrl: post.thumbnailUrl,
                sampleUrl: post.sampleUrl,
                originalUrl: post.originalUrl,
                tags: post.tags,
                tagGeneral: post.tagGeneral,
                tagArtist: post.tagArtist,
                tagCharacter: post.tagCharacter,
                tagCopyright: post.tagCopyright,
                tagMeta: post.tagMeta,
                aspectRatio: post.aspectRatio,
                width: post.width,
                height: post.height,
                rating: post.rating,
                score: post.score,
                source: post.source,
                postUrl: post.postUrl,
              ));
              ref.invalidate(userFavoritesRepoProvider);
            },
          ),
        ],
          ),
        ),
      ),
      body: GestureDetector(
        onLongPress: _toggleSlideshow,
        onVerticalDragStart:
            horizontalPages ? (_) => _springController.stop() : null,
        onVerticalDragUpdate:
            horizontalPages ? (d) => _dragOffset.value += d.delta.dy : null,
        onVerticalDragEnd:
            horizontalPages ? (d) => _onDragEnd(d, post, true) : null,
        onHorizontalDragStart:
            horizontalPages ? null : (_) => _springController.stop(),
        onHorizontalDragUpdate:
            horizontalPages ? null : (d) => _dragOffset.value += d.delta.dx,
        onHorizontalDragEnd:
            horizontalPages ? null : (d) => _onDragEnd(d, post, false),
        child: ValueListenableBuilder<double>(
          valueListenable: _dragOffset,
          builder: (context, offset, child) {
            final progress = (offset.abs() / 400).clamp(0.0, 1.0);
            return Container(
              color: Colors.black.withOpacity(1.0 - 0.9 * progress),
              child: Transform.translate(
                offset:
                    horizontalPages ? Offset(0, offset) : Offset(offset, 0),
                child: Transform.scale(
                  scale: 1.0 - 0.12 * progress,
                  child: child,
                ),
              ),
            );
          },
          child: PageView.builder(
          scrollDirection: ref.watch(settingsProvider).viewerSwipeMode ? Axis.horizontal : Axis.vertical,
          controller: _pageController,
          itemCount: widget.posts.length,
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
            _trackHistory(widget.posts[index]);
          },
          itemBuilder: (context, index) {
            final p = widget.posts[index];
            final url = p.sampleUrl.isNotEmpty ? p.sampleUrl : p.originalUrl;
            final isVideo = _isVideoUrl(url);

            if (isVideo) {
              return Center(
                child: Hero(
                  tag: 'post_${p.serverId}_${p.id}',
                  child: VideoViewer(url: url),
                ),
              );
            }

            return GestureDetector(
              onTap: () {
                if (ref.read(settingsProvider).tapAction == 'detail') {
                  _showDetails(context, p);
                }
              },
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 5.0,
              child: Center(
                child: Hero(
                  tag: 'post_${p.serverId}_${p.id}',
                  child: ExtendedImage.network(
                          url,
                          fit: BoxFit.contain,
                          cache: true,
                          loadStateChanged: (state) {
                            if (state.extendedImageLoadState ==
                                LoadState.loading) {
                              return const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white),
                              );
                            }
                            if (state.extendedImageLoadState ==
                                LoadState.failed) {
                              return const Center(
                                child: Icon(Icons.broken_image,
                                    color: Colors.white54, size: 48),
                              );
                            }
                            return state.completedWidget;
                          },
                        ),
                    ),
                  ),
                ),
              );
          },
          ),
        ),
      ),
    );
  }

  void _onDragEnd(DragEndDetails details, PostSummary post, bool horizontalPages) {
    final offset = _dragOffset.value;
    final velocity = details.primaryVelocity ?? 0;
    // 横向翻页模式下快速下甩且下滑动作为详情：回弹并打开详情
    if (horizontalPages &&
        velocity > 900 &&
        offset.abs() < _dismissThreshold &&
        ref.read(settingsProvider).swipeDownAction == 'detail') {
      _springBack();
      _showDetails(context, post);
      return;
    }
    // 位移过阈值或甩速足够：顺势关闭
    if (offset.abs() > _dismissThreshold || velocity.abs() > 1200) {
      Navigator.of(context).pop();
      return;
    }
    _springBack();
  }

  void _springBack() {
    if (_springListener != null && _springAnim != null) {
      _springAnim!.removeListener(_springListener!);
    }
    _springAnim = Tween(begin: _dragOffset.value, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutCubic),
    );
    _springListener = () => _dragOffset.value = _springAnim!.value;
    _springAnim!.addListener(_springListener!);
    _springController.forward(from: 0);
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.contains('/video/') ||
        lower.contains('/sample/') && lower.contains('.mp4');
  }

  void _share(PostSummary post) {
    final postUrl = post.postUrl ?? post.originalUrl;
    if (postUrl.isEmpty) return;
    Share.share(postUrl);
  }

  Future<void> _download(PostSummary post) async {
    final quality = ref.read(settingsProvider).downloadQuality;
    final url = quality == 'sample' && post.sampleUrl.isNotEmpty
        ? post.sampleUrl
        : (post.originalUrl.isNotEmpty ? post.originalUrl : post.sampleUrl);
    if (url.isEmpty) return;

    final progressNotifier = ref.read(downloadProgressProvider.notifier);
    progressNotifier.start(url, post.id);
    setState(() => _saving = true);

    final result = await ImageDownloader.downloadImage(
      url,
      postId: post.id,
      width: post.width,
      height: post.height,
      onProgress: (p) => progressNotifier.update(url, p),
    );
    setState(() => _saving = false);

    if (result.success) {
      progressNotifier.complete(url);
    } else {
      progressNotifier.fail(url, result.error ?? '');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success ? T.savedToGallery : T.downloadFailed),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showDetails(BuildContext context, PostSummary post) {
    context.push('/post/${post.id}/detail', extra: post);
  }
}

class _DownloadProgressIcon extends ConsumerWidget {
  const _DownloadProgressIcon({required this.post});
  final PostSummary post;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = post.originalUrl.isNotEmpty ? post.originalUrl : post.sampleUrl;
    final p = ref.watch(downloadProgressProvider).where((d) => d.url == url).firstOrNull;
    return SizedBox(width: 20, height: 20, child: CircularProgressIndicator(value: (p?.progress ?? 0) > 0 ? p!.progress : null, strokeWidth: 2, color: Colors.white));
  }
}
