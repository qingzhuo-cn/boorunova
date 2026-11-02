// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'dart:async';

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/favorites/user_favorite_repo.dart';
import 'package:boorunova/data/repository/history/user_history_repo.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/foundation/util/image_downloader.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/provider/download_progress.dart';
import 'package:boorunova/presentation/widgets/common/download_feedback.dart';
import 'package:boorunova/presentation/widgets/common/glass.dart';
import 'package:boorunova/presentation/widgets/media/resolved_video.dart';
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

  /// 本次会话内已解析的真实下载地址（键为 postKeyOf），供进度图标查询。
  ///
  /// 视频站/paheal 的媒体地址要异步解析，与 downloadUrlOf 的同步结果不同，
  /// 不缓存的话进度图标永远对不上进度记录（恒为不确定态）。
  final Map<String, String> _resolvedDownloadUrls = {};

  /// 手势动作的无障碍播报文本（liveRegion 的 label）。
  ///
  /// 双击缩放 / 长按收藏都不会改变任何可见控件的状态，读屏用户对这类手势
  /// 完全无感。把动作结果写进一个 liveRegion，label 变化时由系统朗读。
  String _gestureFeedback = '';

  // 跟手下滑 dismiss 状态
  final _dragOffset = ValueNotifier<double>(0);

  // 缩放控制器。doubleTapAction == 'zoom' 依赖它做双击放大/还原；
  // 此前 InteractiveViewer 没有 controller，双击缩放根本无法实现。
  final _zoomController = TransformationController();
  bool _zoomed = false;

  /// 是否处于放大状态。
  ///
  /// 必须以**变换矩阵**为准：双指捏合不会经过 [_zoomed] 这个双击标记，
  /// 只看标记会把"用户捏合放大"当成未放大。也不能拿 `Matrix4.identity()`
  /// 做 == 比较——Matrix4 没有值相等语义，比出来恒为 false。
  bool get _isZoomed {
    final storage = _zoomController.value.storage;
    // 2D 仿射的 x/y 缩放项
    return (storage[0] - 1).abs() > 0.01 || (storage[5] - 1).abs() > 0.01;
  }
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
    // 缩放状态变化时重算手势闸门（见 build 里的 drag 回调）
    _zoomController.addListener(_onZoomChanged);
    _trackHistory(widget.posts[_currentIndex]);
  }

  void _onZoomChanged() {
    final zoomed = _isZoomed;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  /// 更新 liveRegion 文本。相同文本不重复触发——liveRegion 只在 label
  /// 变化时朗读，而双击/长按的结果文案天然在两种状态间交替。
  void _announce(String message) {
    if (!mounted || _gestureFeedback == message) return;
    setState(() => _gestureFeedback = message);
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _zoomController.removeListener(_onZoomChanged);
    _springController.dispose();
    _dragOffset.dispose();
    _zoomController.dispose();
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
    final isVideo = isVideoPost(post);
    // 翻页方向：true=横向翻页（纵轴留给下滑关闭），false=纵向翻页（横轴留给侧滑关闭）
    final horizontalPages = ref.watch(settingsProvider).viewerSwipeMode;
    final zoomed = _isZoomed;

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
          child: GlassContainer(
            borderRadius: BorderRadius.zero,
            tint: Colors.black,
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
                    icon: Icon(_slideshowPlaying
                        ? Icons.pause_circle_filled
                        : Icons.auto_awesome),
                    tooltip:
                        _slideshowPlaying ? T.stopSlideshow : T.autoSlideshow,
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
                      ? _DownloadProgressIcon(
                          post: post,
                          resolvedUrl: _resolvedDownloadUrls[postKeyOf(post)],
                        )
                      : const Icon(Icons.download_outlined),
                  tooltip: T.downloads,
                  onPressed: _saving ? null : () => _download(post),
                ),
                IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? Colors.red : Colors.white,
                  ),
                  tooltip: T.favorites,
                  // 按钮态不弹提示：图标翻转本身就是反馈，
                  // 长按/双击才需要 snackbar 确认（手势没有可见的视觉变化）
                  onPressed: () => _toggleFavorite(post, notify: false),
                ),
              ],
            ),
          ),
        ),
      ),
      // 手势接线：四个设置项此前只有 tapAction / swipeDownAction 生效，
      // doubleTapAction 与 longPressAction 声明了但没有任何消费点。
      //
      // 长按此前被 _toggleSlideshow 无条件抢占，用户把长按设成「收藏」
      // 实际行为却是切幻灯片 —— 语义直接冲突。这里改为按设置分发，
      // 幻灯片移交给 AppBar 上的显式按钮（本来就有）。
      // 放大后必须让出 dismiss 手势：否则用户想在放大图里上下平移，
      // 结果被"下滑关闭"劫持，一拖就把查看器关掉了。
      // 手势动作（双击缩放 / 长按收藏）没有任何可见的控件状态变化，读屏
      // 用户对这类操作完全无感；把动作结果写进一个 liveRegion，label 变化
      // 时由系统朗读。修复前这两个手势对读屏完全不可见。
      body: Semantics(
        container: true,
        liveRegion: true,
        label: _gestureFeedback,
        child: GestureDetector(
          onLongPress: () => _onLongPress(post),
          onDoubleTap: () => _onDoubleTap(post),
          onVerticalDragStart: horizontalPages && !zoomed
              ? (_) => _springController.stop()
              : null,
          onVerticalDragUpdate: horizontalPages && !zoomed
              ? (d) => _dragOffset.value += d.delta.dy
              : null,
          onVerticalDragEnd: horizontalPages && !zoomed
              ? (d) => _onDragEnd(d, post)
              : null,
          onHorizontalDragStart: !horizontalPages && !zoomed
              ? (_) => _springController.stop()
              : null,
          onHorizontalDragUpdate: !horizontalPages && !zoomed
              ? (d) => _dragOffset.value += d.delta.dx
              : null,
          onHorizontalDragEnd: !horizontalPages && !zoomed
              ? (d) => _onDragEnd(d, post)
              : null,
          child: ValueListenableBuilder<double>(
            valueListenable: _dragOffset,
            builder: (context, offset, child) {
              final progress = (offset.abs() / 400).clamp(0.0, 1.0);
              return Container(
                color: Colors.black.withOpacity(1.0 - 0.9 * progress),
                child: Transform.translate(
                  offset: horizontalPages ? Offset(0, offset) : Offset(offset, 0),
                  child: Transform.scale(
                    scale: 1.0 - 0.12 * progress,
                    child: child,
                  ),
                ),
              );
            },
            child: PageView.builder(
              scrollDirection: ref.watch(settingsProvider).viewerSwipeMode
                  ? Axis.horizontal
                  : Axis.vertical,
              controller: _pageController,
              itemCount: widget.posts.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                _resetZoom();
                _trackHistory(widget.posts[index]);
              },
              itemBuilder: (context, index) {
                final p = widget.posts[index];
                // 预览画质按**这条帖子所属站点**的偏好取（§6.4）
                final url = previewUrlOf(
                  p,
                  preferOriginal: previewQualityFor(
                        ref.watch(settingsProvider),
                        ref
                            .watch(userServerRepoProvider)
                            .preferencesOf(p.serverId),
                      ) ==
                      'original',
                );
                final isVideo = isVideoPost(p);

                if (isVideo) {
                  return Center(
                    child: Hero(
                      tag: 'post_${p.serverId}_${p.id}',
                      child: ResolvedVideo(post: p),
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
                    transformationController: _zoomController,
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
      ),
    );
  }

  /// 长按：按 longPressAction 设置分发。
  /// 幻灯片不再占用长按，改由 AppBar 按钮触发。
  void _onLongPress(PostSummary post) {
    switch (ref.read(settingsProvider).longPressAction) {
      case 'fav':
        _toggleFavorite(post);
      case 'none':
        break;
      default:
        // 未知值退化为无操作，不做猜测性行为
        break;
    }
  }

  /// 双击：按 doubleTapAction 设置分发（缩放 / 收藏）。
  void _onDoubleTap(PostSummary post) {
    switch (ref.read(settingsProvider).doubleTapAction) {
      case 'zoom':
        _toggleZoom();
        // 放大/还原没有读屏可见的反馈，补一条 liveRegion 播报；带上倍率，
        // 重复双击时文本会变化，liveRegion 才会再次朗读。
        _announce('${T.actionZoom} ${_zoomed ? '2.5x' : '1x'}');
      case 'fav':
        // _toggleFavorite 在 notify=true 的手势路径里已经负责播报结果。
        _toggleFavorite(post);
      default:
        break;
    }
  }

  /// 双击缩放：在 1x 与 2.5x 之间切换，带动画。
  void _toggleZoom() {
    final target =
        _zoomed ? Matrix4.identity() : (Matrix4.identity()..scale(2.5));
    _zoomed = !_zoomed;
    _zoomController.value = target;
  }

  /// 翻页后复位缩放：否则新一页会继承上一页的放大倍率。
  void _resetZoom() {
    if (!_isZoomed) {
      _zoomed = false;
      return;
    }
    _zoomed = false;
    _zoomController.value = Matrix4.identity();
  }

  /// 切换收藏。[notify] 为 true 时弹 snackbar 确认——手势触发时用，
  /// 因为手势没有像按钮图标那样明显的视觉反馈。
  Future<void> _toggleFavorite(PostSummary post, {bool notify = true}) async {
    final repo = ref.read(userFavoritesRepoProvider);
    // messenger 在 await 之前取好：await 之后组件可能已销毁，不能再碰 context。
    final messenger = ScaffoldMessenger.of(context);
    await repo.toggle(post.toPost());
    // 修复前 invalidate 排在 mounted 检查之前：收藏请求返回前查看器被关闭
    // （下滑 dismiss / 返回）时，dispose 后继续用 ref 会抛
    // "Cannot use ref after the widget was disposed"。
    if (!mounted) return;
    ref.invalidate(userFavoritesRepoProvider);
    if (!notify) return;
    final nowFav = repo.isFavorite(post.id, serverId: post.serverId);
    final message = nowFav ? T.addedToFavoritesShort : T.removedFromFavorites;
    // AppBar 心形图标有可见的状态翻转；长按/双击手势没有，读屏用户完全
    // 不知道刚才发生了什么。手势路径（notify=true）额外播报一条 liveRegion。
    _announce(message);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _onDragEnd(DragEndDetails details, PostSummary post) {
    final offset = _dragOffset.value;
    final velocity = details.primaryVelocity ?? 0;
    // 下滑动作按设置分发。纵向翻页模式下纵轴被 PageView 占用，
    // 此时该设置不生效——这是翻页轴的固有限制，不是 bug，
    // 但必须让用户知道，而不是静默忽略。
    if (velocity > 900 &&
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

  void _share(PostSummary post) {
    final postUrl = permalinkOf(post);
    if (postUrl.isEmpty) return;
    Share.share(postUrl);
  }

  Future<void> _download(PostSummary post) async {
    final settings = ref.read(settingsProvider);
    // 视频站/paheal 系的帖子要先解析真实地址，否则会下到缩略图。
    // 解析结果下面会按 post 缓存给进度图标，让图标查的 URL 与这里实际下载的
    // 完全一致（此前图标查同步的 downloadUrlOf，视频帖永远对不上进度记录）。
    // 站点级偏好优先于全局：画质与下载子目录都跟着这条帖子所属的站点走
    final prefs =
        ref.read(userServerRepoProvider).preferencesOf(post.serverId);
    final url = await resolveDownloadUrl(
      post,
      ref.read(booruPageStateProvider.notifier).repository,
      preferSample: downloadQualityFor(settings, prefs) == 'sample',
    );
    if (url.isEmpty || !mounted) return;

    final progressNotifier = ref.read(downloadProgressProvider.notifier);
    progressNotifier.start(url, post.id);
    // 缓存解析后的真实下载地址。视频站/paheal 的实际地址要异步解析，与
    // downloadUrlOf 的同步结果不同；修复前进度图标查的是同步地址，永远
    // 匹配不到这里的进度记录，图标恒为不确定态转圈。
    setState(() {
      _saving = true;
      _resolvedDownloadUrls[postKeyOf(post)] = url;
    });

    final result = await ImageDownloader.downloadImage(
      url,
      postId: post.id,
      namespace: post.serverId,
      width: post.width,
      height: post.height,
      // postId 一起传：同一媒体地址被两个帖子下载时才不会互相打断
      onProgress: (p) => progressNotifier.update(url, p, postId: post.id),
      // 限流时别让进度条一动不动地干等：明确说清为什么等、会自动继续
      onRetryWait: (retryIn) {
        if (mounted) showRateLimitNotice(context, retryIn);
      },
      downloadPath: settings.downloadPath,
      downloadSubdir: prefs.downloadSubdir,
    );
    if (mounted) {
      setState(() => _saving = false);
    }

    if (result.success) {
      progressNotifier.complete(url, postId: post.id);
    } else {
      progressNotifier.fail(url, result.error ?? '', postId: post.id);
    }

    if (mounted) {
      // 四态各自说话：已保存过 / 已存相册但记录失败 / 权限拒绝 / 失败。
      // 权限类失败单独给可读文案与指引，而不是一句笼统的「下载失败」。
      final message = downloadResultMessage(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showDetails(BuildContext context, PostSummary post) {
    // 带上来源标记：详情页据此改成「pop 回本查看器」，而不是新建一个
    // 重建出来的画廊（那会把用户当前的画廊与位置丢掉）。
    context.push('/post/${post.id}/detail',
        extra: <String, dynamic>{'post': post, 'fromViewer': true});
  }
}

class _DownloadProgressIcon extends ConsumerWidget {
  const _DownloadProgressIcon({required this.post, this.resolvedUrl});
  final PostSummary post;

  /// [_PostViewerState._download] 解析并缓存的真实下载地址。
  ///
  /// 为 null 时退回同步的 downloadUrlOf（纯图片站两者一致）。视频站/paheal
  /// 只有解析后的地址才对得上进度记录，传 null 会退回「永远转圈」的老问题。
  final String? resolvedUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 兜底地址必须与 _download 用同一个画质口径（含站点级覆盖）：
    // 否则站点设了 sample 时，图标查的是原图地址，永远匹配不到进度记录，
    // 又回到「一直转圈」的老问题。
    final settings = ref.watch(settingsProvider);
    final prefs = ref.watch(userServerRepoProvider).preferencesOf(post.serverId);
    final url = resolvedUrl ??
        downloadUrlOf(
          post,
          preferSample: downloadQualityFor(settings, prefs) == 'sample',
        );
    final p = ref
        .watch(downloadProgressProvider)
        .where((d) => d.url == url)
        .firstOrNull;
    return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
            value: (p?.progress ?? 0) > 0 ? p!.progress : null,
            strokeWidth: 2,
            color: Colors.white));
  }
}
