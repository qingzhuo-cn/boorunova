// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'dart:async';

import 'package:boorunova/foundation/network/dio_factory.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/theme/app_dimens.dart';
import 'package:boorunova/presentation/widgets/common/glass.dart';
import 'package:boorunova/presentation/widgets/media/video_format.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// 视频播放器：直链（mp4/webm）与 HLS（m3u8）都支持——Android 的 ExoPlayer
/// 与 iOS 的 AVPlayer 都原生吃 HLS。
///
/// 控制层是自己实现的（不引依赖）：点击画面显隐、中央播放/暂停、底部
/// 进度条可拖动定位、已播/总时长、倍速、静音、全屏。此前的版本只有一条
/// 极细的进度指示线，实际拖不住，也没有时间显示——用户反馈"没有拖动
/// 进度条等功能"就是它。
/// 播放 / 暂停 / 播完重播的统一实现。
///
/// 内嵌播放器与全屏页此前各写一份逐字相同的分支（播放中→暂停、已播完→回到
/// 开头再播、否则→播放）：改一处忘另一处就会出现「全屏里点播放没反应」这类
/// 只在其中一个入口复现的问题。
@visibleForTesting
void togglePlayback(VideoPlayerController controller) {
  if (controller.value.isPlaying) {
    controller.pause();
    return;
  }
  if (controller.value.isCompleted) {
    controller.seekTo(Duration.zero);
  }
  controller.play();
}

class VideoViewer extends StatefulWidget {
  const VideoViewer({
    super.key,
    required this.url,
    this.headers,
    this.autoPlay = true,
  });

  final String url;
  final Map<String, String>? headers;
  final bool autoPlay;

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initialized = false;
  Object? _error;
  bool _controlsVisible = true;
  Timer? _hideTimer;

  /// 退到后台前是否在播：回前台时只恢复「本来就在播」的视频，
  /// 不把用户手动暂停的视频偷偷播起来。
  bool _resumeAfterBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // 退后台继续播：既费电又继续出声，用户切回来还找不到进度。
        if (controller.value.isPlaying) {
          _resumeAfterBackground = true;
          controller.pause();
          _hideTimer?.cancel();
        }
      case AppLifecycleState.resumed:
        if (_resumeAfterBackground) {
          _resumeAfterBackground = false;
          controller.play();
          _scheduleHide();
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _init() async {
    try {
      // Uri.parse 也放在 try 里：坏 URL 此前在 try 外抛异常，
      // 页面既没有错误态也没有重试，永久转圈。
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        // 与图片管线共用同一个工厂默认 UA：此前视频侧写死 'BooruNova/1.0'，
        // 与图片侧（含版本号）不一致，防盗链站点上同一帖的图和视频表现不同。
        httpHeaders: widget.headers ??
            <String, String>{'User-Agent': DioFactory.fallbackUserAgent},
      );
      _controller = controller;
      controller.addListener(_onControllerChanged);
      await controller.initialize();
      if (!mounted) return;
      _syncLastFromController();
      setState(() => _initialized = true);
      if (widget.autoPlay) {
        await controller.play();
      }
      _scheduleHide();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  void didUpdateWidget(covariant VideoViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // url / headers 变了必须重建控制器：此前完全忽略，切到另一个视频时
    // 画面还停在旧控制器上（音频/进度也是旧的）。
    if (oldWidget.url != widget.url ||
        !mapEquals(oldWidget.headers, widget.headers)) {
      _hideTimer?.cancel();
      final old = _controller;
      old?.removeListener(_onControllerChanged);
      unawaited(old?.dispose());
      _controller = null;
      _initialized = false;
      _error = null;
      unawaited(_init());
    }
  }

  // 上一帧真正影响本页渲染的状态。video_player 每 500ms 轮询一次位置并
  // 通知，此前无条件 setState → VideoPlayer、控制层、底部控制条全部每
  // 500ms 重建一次（播放期间 CPU 常驻高负载）。位置更新交给 _ControlBar
  // 自己按秒粒度订阅，这里只重建真正改变的东西。
  bool _lastPlaying = false;
  bool _lastBuffering = false;
  bool _lastCompleted = false;
  double _lastAspect = 0;

  /// 让节流用的快照与当前控制器状态对齐（初始化/重试后调用），
  /// 否则首帧的缓冲态可能被当成"没变化"而漏掉一次重建。
  void _syncLastFromController() {
    final value = _controller?.value;
    if (value == null) return;
    _lastPlaying = value.isPlaying;
    _lastBuffering = value.isBuffering;
    _lastCompleted = value.isCompleted;
    _lastAspect = value.aspectRatio;
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final value = _controller?.value;
    if (value == null) return;
    if (value.isPlaying != _lastPlaying) {
      _lastPlaying = value.isPlaying;
      if (value.isPlaying) _scheduleHide();
      setState(() {});
      return;
    }
    if (value.isBuffering != _lastBuffering ||
        value.isCompleted != _lastCompleted ||
        value.aspectRatio != _lastAspect) {
      _lastBuffering = value.isBuffering;
      _lastCompleted = value.isCompleted;
      _lastAspect = value.aspectRatio;
      setState(() {});
    }
  }

  /// 只在播放中自动隐藏控制层：暂停时保持可见，否则用户找不到按钮。
  void _scheduleHide() {
    _hideTimer?.cancel();
    final controller = _controller;
    if (controller == null || !controller.value.isPlaying) return;
    _hideTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    final wasPlaying = controller.value.isPlaying;
    togglePlayback(controller);
    if (wasPlaying) {
      _hideTimer?.cancel();
      if (mounted) setState(() => _controlsVisible = true);
    } else {
      _scheduleHide();
    }
  }

  /// 全屏：不新建控制器（避免重新缓冲与跳回 0 秒），把同一个控制器交给
  /// 全屏页显示，退出时再交回来。
  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller == null) return;
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => _FullscreenVideoPage(
          controller: controller,
          onClose: () => Navigator.of(context).maybePop(),
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (mounted) _scheduleHide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    final old = _controller;
    old?.removeListener(_onControllerChanged);
    // 不 await：video_player 的 dispose 会先等事件订阅取消完成，而订阅
    // 挂在一个只由平台事件驱动的流上——一旦它不返回，重试按钮就永远没反应。
    // 我们只需要解绑监听，资源回收交给它自己的 future。
    if (old != null) unawaited(old.dispose());
    if (!mounted) return;
    setState(() {
      _controller = null;
      _initialized = false;
      _error = null;
    });
    await _init();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) return _VideoError(error: error, onRetry: _retry);

    final controller = _controller;
    if (!_initialized || controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final aspect = controller.value.aspectRatio;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Center(
            child: AspectRatio(
              aspectRatio: aspect > 0 ? aspect : 16 / 9,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        if (controller.value.isBuffering)
          const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            ),
          ),
        AnimatedOpacity(
          opacity: _controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: _ControlsLayer(
              controller: controller,
              isFullscreen: false,
              onTogglePlay: _togglePlay,
              onToggleFullscreen: _openFullscreen,
            ),
          ),
        ),
        if (controller.value.isCompleted)
          Center(
            child: _RoundIconButton(
              icon: Icons.replay,
              tooltip: T.replay,
              size: 60,
              onTap: _togglePlay,
            ),
          ),
      ],
    );
  }
}

/// 控制层：上下渐变 + 中央播放键 + 底部控制条。
class _ControlsLayer extends StatelessWidget {
  const _ControlsLayer({
    required this.controller,
    required this.isFullscreen,
    required this.onTogglePlay,
    this.onToggleFullscreen,
    this.onClose,
  });

  final VideoPlayerController controller;
  final bool isFullscreen;
  final VoidCallback onTogglePlay;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 渐变只为提升图标可读性，不挡视频
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black54,
                Colors.transparent,
                Colors.transparent,
                Colors.black87,
              ],
              stops: [0, 0.22, 0.55, 1],
            ),
          ),
        ),
        Center(
          child: _RoundIconButton(
            icon: controller.value.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            tooltip: controller.value.isPlaying ? T.pause : T.play,
            size: 68,
            onTap: onTogglePlay,
          ),
        ),
        if (onClose != null)
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: _RoundIconButton(
                icon: Icons.close_rounded,
                tooltip: T.exitFullscreen,
                size: 40,
                onTap: onClose!,
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: _ControlBar(
              controller: controller,
              isFullscreen: isFullscreen,
              onToggleFullscreen: onToggleFullscreen,
            ),
          ),
        ),
      ],
    );
  }
}

/// 底部控制条：进度拖动 + 时间 + 倍速 + 静音 + 全屏。
///
/// 拖动状态（`_dragMs`）放在这里：拖动期间以手指位置为准，不被播放进度
/// 拉回去；松手才真正 seek。此前直接绑控制器进度，滑块一碰就弹回原处。
class _ControlBar extends StatefulWidget {
  const _ControlBar({
    required this.controller,
    required this.isFullscreen,
    this.onToggleFullscreen,
  });

  final VideoPlayerController controller;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;

  @override
  State<_ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends State<_ControlBar> {
  /// 拖动中的目标毫秒；非空表示正在拖。
  double? _dragMs;

  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  // 自己订阅控制器：位置/时间只在这里重建（秒粒度节流），
  // 不再靠父级每 500ms 整页 setState。
  int? _shownSecond;
  Duration? _shownDuration;
  bool? _shownPlaying;
  double? _shownSpeed;
  double? _shownVolume;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerTick);
    _capture();
  }

  @override
  void didUpdateWidget(covariant _ControlBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerTick);
      widget.controller.addListener(_onControllerTick);
      _capture();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerTick);
    super.dispose();
  }

  void _capture() {
    final value = widget.controller.value;
    _shownSecond = value.position.inSeconds;
    _shownDuration = value.duration;
    _shownPlaying = value.isPlaying;
    _shownSpeed = value.playbackSpeed;
    _shownVolume = value.volume;
  }

  void _onControllerTick() {
    if (!mounted) return;
    // 拖动中以手指为准，进度回调不参与重建
    if (_dragMs != null) return;
    final value = widget.controller.value;
    // 节流到秒粒度：视频播放期间每 500ms 一次回调，逐次 setState
    // 会让 Slider / 倍速菜单 / 静音按钮每 500ms 重建一次。
    if (value.position.inSeconds == _shownSecond &&
        value.duration == _shownDuration &&
        value.isPlaying == _shownPlaying &&
        value.playbackSpeed == _shownSpeed &&
        value.volume == _shownVolume) {
      return;
    }
    setState(_capture);
  }

  void _seekTo(double ms) {
    widget.controller.seekTo(Duration(milliseconds: ms.round()));
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final totalMs = value.duration.inMilliseconds;
    final maxMs = totalMs > 0 ? totalMs.toDouble() : 1.0;
    final shownMs = (_dragMs ?? value.position.inMilliseconds.toDouble())
        .clamp(0.0, maxMs);
    final muted = value.volume == 0;
    final speed = value.playbackSpeed;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusM),
      ),
      child: BackdropFilter(
        // 给控制条一点液态玻璃的底子，与全局观感统一。
        // 复用全局唯一那份滤镜：每次 build 新建 ImageFilter 会让合成层
        // 每次都重新分配一个引擎侧对象。
        filter: glassBlurFilter,
        child: Container(
          // Flutter 3.24 上还没有 Color.withValues（3.27+ 才引入），
          // 与项目其余 40 处保持一致用 withOpacity。
          // ignore: deprecated_member_use
          color: Colors.black.withOpacity(0.42),
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white30,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                ),
                child: Slider(
                  value: shownMs,
                  max: maxMs,
                  // 拖动中即时跟手；松手才 seek
                  onChanged: (v) => setState(() => _dragMs = v),
                  onChangeEnd: (v) {
                    _seekTo(v);
                    setState(() {
                      _dragMs = null;
                      // 松手后以控制器为准，节流快照跟着更新，
                      // 否则紧接着的一次 tick 会被当成"没变化"。
                      _capture();
                    });
                  },
                ),
              ),
              Row(
                children: [
                  const SizedBox(width: 6),
                  Text(
                    '${_fmt(Duration(milliseconds: shownMs.round()))}'
                    ' / ${_fmt(value.duration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  // 倍速
                  PopupMenuButton<double>(
                    tooltip: T.playbackSpeed,
                    initialValue: speed,
                    onSelected: (v) => widget.controller.setPlaybackSpeed(v),
                    itemBuilder: (_) => [
                      for (final s in _speeds)
                        PopupMenuItem(
                          value: s,
                          child: Text('${s == s.roundToDouble() ? s.toInt() : s}x'),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Text(
                        '${speed == speed.roundToDouble() ? speed.toInt() : speed}x',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: muted ? T.unmute : T.mute,
                    icon: Icon(
                      muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () =>
                        widget.controller.setVolume(muted ? 1 : 0),
                  ),
                  if (widget.onToggleFullscreen != null)
                    IconButton(
                      tooltip: widget.isFullscreen
                          ? T.exitFullscreen
                          : T.fullscreen,
                      icon: Icon(
                        widget.isFullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        color: Colors.white,
                      ),
                      onPressed: widget.onToggleFullscreen,
                    ),
                  const SizedBox(width: 2),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `mm:ss`，超过一小时给 `h:mm:ss`。
  static String _fmt(Duration d) => formatVideoDuration(d);
}

/// 全屏播放页：同一个控制器换个容器显示，并临时锁定横屏 + 沉浸式。
class _FullscreenVideoPage extends StatefulWidget {
  const _FullscreenVideoPage({required this.controller, required this.onClose});

  final VideoPlayerController controller;
  final VoidCallback onClose;

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  bool _visible = true;
  bool _lastBuffering = false;
  bool _lastPlaying = false;
  double _lastAspect = 0;
  Timer? _hideTimer;

  /// 与内嵌播放器同一个时长口径。
  static const Duration _hideDelay = Duration(milliseconds: 3200);

  @override
  void initState() {
    super.initState();
    // 与 main.dart 允许的方向保持一致，退出时原样恢复
    unawaited(SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
    ));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    widget.controller.addListener(_onChanged);
    // 进全屏时可能已经在播：直接排一次隐藏，否则控制层会一直盖在画面上。
    _lastPlaying = widget.controller.value.isPlaying;
    _scheduleHide();
  }

  /// 只在播放中自动隐藏：暂停时保持可见，否则用户找不到按钮
  /// （此前全屏页**从不**自动隐藏，播放时控制层永远挡着画面）。
  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!widget.controller.value.isPlaying) return;
    _hideTimer = Timer(_hideDelay, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _toggleControls() {
    setState(() => _visible = !_visible);
    if (_visible) {
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
    }
  }

  /// 与内嵌播放器同样的节流：位置更新由 `_ControlBar` 自己订阅，
  /// 这里只在**播放状态迁移**、缓冲态与宽高比变化时重建。
  void _onChanged() {
    if (!mounted) return;
    final value = widget.controller.value;

    // 播放状态迁移：开始播 → 重新计时隐藏；暂停 → 立刻显示并取消隐藏
    // （暂停时把控制层藏起来，用户就找不到按钮了）。
    if (value.isPlaying != _lastPlaying) {
      _lastPlaying = value.isPlaying;
      if (value.isPlaying) {
        if (_visible) _scheduleHide();
      } else {
        _hideTimer?.cancel();
        if (!_visible) setState(() => _visible = true);
        return;
      }
    }

    if (value.isBuffering == _lastBuffering &&
        value.aspectRatio == _lastAspect) {
      return;
    }
    setState(() {
      _lastBuffering = value.isBuffering;
      _lastAspect = value.aspectRatio;
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_onChanged);
    unawaited(SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final aspect = controller.value.aspectRatio;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: Center(
              child: AspectRatio(
                aspectRatio: aspect > 0 ? aspect : 16 / 9,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          if (controller.value.isBuffering)
            const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
          AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !_visible,
              child: _ControlsLayer(
                controller: controller,
                isFullscreen: true,
                onTogglePlay: () {
                  togglePlayback(controller);
                  _scheduleHide();
                },
                onToggleFullscreen: widget.onClose,
                onClose: widget.onClose,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 圆形半透明按钮：控制层里统一的手感与命中区。
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 48,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black38,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: size * 0.6),
          ),
        ),
      ),
    );
  }
}

/// 播放失败时的可恢复界面：坏链、编码不支持、防盗链都落在这里。
///
/// 关键是把「转圈到底」换成「告诉你失败 + 给一次重试」——视频站的外链
/// 常常需要 token，失败是常态而不是异常。
class _VideoError extends StatelessWidget {
  const _VideoError({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined,
                size: 48, color: Colors.white54),
            const SizedBox(height: AppDimens.spaceM),
            Text(
              T.videoPlayFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: AppDimens.spaceXS),
            Text(
              '$error',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: AppDimens.spaceM),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(T.retry),
            ),
          ],
        ),
      ),
    );
  }
}
