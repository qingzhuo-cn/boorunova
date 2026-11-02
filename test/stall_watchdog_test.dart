import 'dart:async';

import 'package:boorunova/foundation/util/image_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

/// 挂起看门狗的判定口径。
///
/// 这段逻辑单独测而不是只靠网络用例：测试绑定下 chunked 响应体不会逐块送达
///（服务端 flush 了、客户端流也要等响应结束才给出数据），所以「慢但在动」
/// 的字节流没法在集成测试里复现。而这里恰恰是最容易写反的地方——
/// 按总耗时判会杀掉正常的大文件下载，是整个改动的关键风险点。
void main() {
  test('每个检查周期内都有进展 → 永不判挂起', () async {
    var stalls = 0;
    final watchdog = StallWatchdog(
      timeout: const Duration(milliseconds: 120),
      onStall: () => stalls++,
    )..start();
    final ticker = Timer.periodic(
      const Duration(milliseconds: 40),
      (_) => watchdog.noteProgress(),
    );

    await Future<void>.delayed(const Duration(milliseconds: 500));
    ticker.cancel();
    watchdog.stop();

    expect(stalls, 0, reason: '一直在收数据就不该判挂起');
    expect(watchdog.isStalled, isFalse);
  });

  test('判定依据是「无进展」而不是「总耗时长」', () async {
    // 总耗时是 timeout 的 7 倍以上，但每 20ms 都有进展。
    // 若回归成按总耗时（或按 dio 的进度回调）判定，这条立刻失败。
    var stalls = 0;
    final watchdog = StallWatchdog(
      timeout: const Duration(milliseconds: 80),
      onStall: () => stalls++,
    )..start();
    final ticker = Timer.periodic(
      const Duration(milliseconds: 20),
      (_) => watchdog.noteProgress(),
    );

    await Future<void>.delayed(const Duration(milliseconds: 620));
    ticker.cancel();
    watchdog.stop();

    expect(stalls, 0, reason: '慢 ≠ 挂起');
  });

  test('完全没有进展 → 一个周期后判挂起并回调', () async {
    var stalls = 0;
    final watchdog = StallWatchdog(
      timeout: const Duration(milliseconds: 100),
      onStall: () => stalls++,
    )..start();

    await Future<void>.delayed(const Duration(milliseconds: 360));
    watchdog.stop();

    expect(stalls, greaterThanOrEqualTo(1));
    expect(watchdog.isStalled, isTrue);
  });

  test('stop() 之后不再判定（下载结束不该留着定时器）', () async {
    var stalls = 0;
    final watchdog = StallWatchdog(
      timeout: const Duration(milliseconds: 60),
      onStall: () => stalls++,
    )..start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    watchdog.stop();

    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(stalls, 0);
  });
}
