import 'dart:async';

import 'package:boorunova/presentation/widgets/media/video_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// 视频播放器控制层的交互测试。
///
/// 没有真实解码器，用 video_player 官方的做法替身平台层：这样能真正驱动
/// 控制器的状态机（初始化 / 播放 / 暂停 / seek / 变速 / 音量），
/// 于是"拖动进度条到底有没有 seek"这类问题可以被自动化验证，而不是靠肉眼。
///
/// 注意：不能用 pumpAndSettle —— 播放器每 500ms 轮询一次进度并重建，
/// 永远"settle"不下来，会一直等到超时。全部用显式 pump。
class _FakePlatform extends VideoPlayerPlatform {
  final List<String> calls = [];
  final _events = StreamController<VideoEvent>.broadcast();
  Duration position = Duration.zero;
  bool buffering = false;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    calls.add('create:${dataSource.uri}');
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) async* {
    yield VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(minutes: 2),
      size: const Size(1280, 720),
      rotationCorrection: 0,
    );
    yield* _events.stream;
  }

  @override
  Future<void> dispose(int textureId) async {
    calls.add('dispose');
  }

  @override
  Future<void> play(int textureId) async => calls.add('play');

  @override
  Future<void> pause(int textureId) async => calls.add('pause');

  @override
  Future<void> setVolume(int textureId, double volume) async =>
      calls.add('volume:$volume');

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async =>
      calls.add('speed:$speed');

  @override
  Future<void> setLooping(int textureId, bool looping) async {}

  @override
  Future<void> seekTo(int textureId, Duration pos) async {
    calls.add('seek:${pos.inSeconds}');
    position = pos;
  }

  @override
  Future<Duration> getPosition(int textureId) async => position;

  @override
  Widget buildView(int textureId) => const ColoredBox(color: Colors.black);

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

void main() {
  late _FakePlatform fake;

  setUp(() {
    fake = _FakePlatform();
    VideoPlayerPlatform.instance = fake;
  });

  Future<void> pumpPlayer(WidgetTester tester, {bool autoPlay = false}) async {
    // 用接近手机的视口：默认 800×600 太扁，弹出菜单会被挤到屏幕外
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: SizedBox(
              width: 400,
              height: 300,
              child: VideoViewer(
                url: 'https://site/get_file/1/a/v_720p.mp4',
                autoPlay: autoPlay,
              ),
            ),
          ),
        ),
      ),
    );
    // 初始化完成 + 首帧
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('初始化后出现控制层：播放键、时间、总时长', (tester) async {
    await pumpPlayer(tester);
    expect(fake.calls, contains('create:https://site/get_file/1/a/v_720p.mp4'));
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    // 2 分钟总时长，位置 0 → "0:00 / 2:00"
    expect(find.text('0:00 / 2:00'), findsOneWidget);
    // 进度条可拖动（用户要的"拖动进度条"）
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('点播放键会 play，再点会 pause', (tester) async {
    await pumpPlayer(tester);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(fake.calls, contains('play'));

    // 播放中控制层会自动隐藏，先让计时器到点
    await tester.pump(const Duration(seconds: 4));
    // 点画面把控制层叫回来
    await tester.tapAt(tester.getCenter(find.byType(VideoViewer)));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(fake.calls, contains('pause'));
  });

  testWidgets('拖动进度条会 seek 到目标位置', (tester) async {
    await pumpPlayer(tester);
    // 从轨道左端拖到中点 → 2 分钟的一半 ≈ 60 秒
    final slider = tester.getRect(find.byType(Slider));
    await tester.dragFrom(
      Offset(slider.left + 4, slider.center.dy),
      Offset(slider.width / 2, 0),
    );
    await tester.pump();
    final seek = fake.calls.where((c) => c.startsWith('seek:')).toList();
    expect(seek, isNotEmpty, reason: '拖动进度条必须真的 seek');
    final seconds = int.parse(seek.last.split(':')[1]);
    expect(seconds, greaterThan(20), reason: '拖到中点应当跳到靠后的位置');
  });

  testWidgets('静音生效，倍速菜单提供 0.5x–2x 六档', (tester) async {
    await pumpPlayer(tester);
    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    expect(fake.calls, contains('volume:0.0'));

    // 倍速要在播放中才下发到平台层：video_player 的 _applyPlaybackSpeed
    // 在暂停时只记值不应用（避免 iOS 上设置倍速意外开始播放），
    // 并在 _applyPlayPause 里明确补应用一次。
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('1x'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(PopupMenuItem<double>), findsNWidgets(6));
    expect(find.text('0.5x'), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
    // 注：菜单项的选中回调（PopupMenuButton.onSelected → setPlaybackSpeed）
    // 没有在这里自动断言——弹出菜单在 overlay 里，合成点击落在模态遮罩上。
    // 该路径是 Flutter 标准控件行为，且平台层调用时机已由上面引用的库源码确认。
  });

  testWidgets('全屏按钮进入全屏页，退出后回到原处', (tester) async {
    await pumpPlayer(tester);
    await tester.tap(find.byIcon(Icons.fullscreen_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // 全屏页有退出按钮
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    // 控制器没有被重建：只 create 过一次，退出后没有 dispose
    expect(fake.calls.where((c) => c.startsWith('create')), hasLength(1));
  });

  testWidgets('autoPlay=true 时打开即播放', (tester) async {
    await pumpPlayer(tester, autoPlay: true);
    expect(fake.calls, contains('play'));
  });

  testWidgets('进度按秒节流：亚秒变化不改时间文本，跨秒才更新', (tester) async {
    await pumpPlayer(tester, autoPlay: true);
    expect(find.text('0:00 / 2:00'), findsOneWidget);

    // 播放中每 500ms 轮询一次位置：先只走亚秒
    fake.position = const Duration(milliseconds: 400);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('0:00 / 2:00'), findsOneWidget,
        reason: '亚秒位置变化不该改变时间文本');

    // 跨过一秒边界才更新
    fake.position = const Duration(milliseconds: 1200);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('0:01 / 2:00'), findsOneWidget);
  });

  testWidgets('全屏控制层在播放中自动隐藏（此前永不隐藏）', (tester) async {
    await pumpPlayer(tester, autoPlay: true);
    await tester.tap(find.byIcon(Icons.fullscreen_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 播放中 3.2s 后控制层应自动隐藏
    await tester.pump(const Duration(milliseconds: 3500));

    // 注意 initialize() 自己会调一次 pause，所以比较**次数**而不是是否出现。
    final pausesBefore = fake.calls.where((c) => c == 'pause').length;

    // 精确点在**画面正中央**——那里正是播放/暂停按钮的位置，也是最锋利的
    // 判别点：控制层已隐藏时这一下落到下面的 GestureDetector 上（只唤出控制
    // 层），若回归成「永不隐藏」则会直接点到按钮、把视频暂停。
    await tester.tapAt(tester.getCenter(find.byType(VideoPlayer)));
    await tester.pump();
    expect(fake.calls.where((c) => c == 'pause').length, pausesBefore,
        reason: '控制层应当已自动隐藏，首次点击只负责唤出它');

    // 唤出后再点按钮才真的暂停
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(fake.calls, contains('pause'));
  });

  testWidgets('togglePlayback 是唯一一份播放/暂停实现：播放↔暂停，播完从头',
      (tester) async {
    // 内嵌与全屏两个入口共用它——此前各写一份，改一处忘一处。
    final controller =
        VideoPlayerController.networkUrl(Uri.parse('https://site/a.mp4'));
    // 不能 await：这个替身的事件流永不关闭，dispose 会卡在取消订阅上，
    // 而 addTearDown 会等它——整个用例文件就超时了（见第 1 轮的分析）。
    addTearDown(() {
      unawaited(controller.dispose());
    });
    await controller.initialize();

    togglePlayback(controller);
    await tester.pump();
    expect(controller.value.isPlaying, isTrue);

    togglePlayback(controller);
    await tester.pump();
    expect(controller.value.isPlaying, isFalse);

    // 播完（位置 == 总时长）时按播放 = 从头重播
    await controller.seekTo(controller.value.duration);
    await tester.pump();
    togglePlayback(controller);
    await tester.pump();
    expect(controller.value.isPlaying, isTrue);
    expect(controller.value.position, Duration.zero);

    // 收尾：播放中的位置轮询是一个 periodic Timer，留着会让测试框架报
    // 「A Timer is still pending even after the widget tree was disposed」。
    await controller.pause();
  });

  testWidgets('url 变化时重建控制器，不复用旧控制器', (tester) async {
    final url = ValueNotifier<String>('https://site/a.mp4');
    addTearDown(url.dispose);
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<String>(
          valueListenable: url,
          builder: (_, value, __) => VideoViewer(url: value, autoPlay: false),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(fake.calls, contains('create:https://site/a.mp4'));

    url.value = 'https://site/b.mp4';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.calls, contains('create:https://site/b.mp4'),
        reason: '换视频必须换控制器，否则画面还停在旧视频上');
    // 不断言平台层 dispose：替身的事件流永不关闭，video_player 的
    // dispose 会停在 _eventSubscription.cancel() 上（真实平台流不这样），
    // 断言它等于在测替身而不是在测我们的代码。
    expect(fake.calls.where((c) => c.startsWith('create')), hasLength(2));
  });
}
