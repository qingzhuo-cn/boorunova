import 'dart:io';

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/screens/post/post_detail_page.dart';
import 'package:boorunova/presentation/screens/post/post_viewer.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// 「详情页 → 打开完整查看器」的回归：从查看器进来的必须**pop 回原查看器**。
///
/// 修复前无条件 `context.push('/post/:id', extra: 重建的画廊)`：用户在查看器里
/// 翻到第 N 张、点进详情、再点「打开完整查看器」，画廊被换成「当前站点首页
/// 那一批」甚至只剩单帖，位置与缩放全丢。
class _PushCounter extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

PostSummary _post() => const PostSummary(
      id: '42',
      serverId: 'srv',
      thumbnailUrl: 'https://x.test/t.jpg',
      sampleUrl: 'https://x.test/s.jpg',
      originalUrl: 'https://x.test/o.jpg',
      tags: ['a'],
      aspectRatio: 1.5,
      width: 300,
      height: 200,
      rating: 's',
      score: 1,
    );

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('boorunova_detail_viewer');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveSetup.settingsBoxName);
    await Hive.openBox(HiveSetup.serversBoxName);
  });

  tearDown(() async {
    try {
      await Hive.deleteFromDisk();
    } catch (_) {}
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<_PushCounter> pumpDetail(WidgetTester tester,
      {required bool fromViewer}) async {
    final observer = _PushCounter();
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        navigatorObservers: [observer],
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PostDetailPage(post: _post(), fromViewer: fromViewer),
                  ),
                ),
                child: const Text('查看器替身'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('查看器替身'));
    // 不用 pumpAndSettle：详情页里的网络图会持续调度帧，settle 不下来。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return observer;
  }

  testWidgets('fromViewer=true：点预览图 pop 回查看器，不新建路由', (tester) async {
    final observer = await pumpDetail(tester, fromViewer: true);
    expect(find.text(T.postDetails), findsOneWidget);
    final pushesAfterOpen = observer.pushes;

    await tester.tap(find.byType(ExtendedImage), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(observer.pushes, pushesAfterOpen,
        reason: '不应再 push 一个新查看器——那样画廊与位置都会丢');
    expect(find.text('查看器替身'), findsOneWidget,
        reason: '应当回到原来的查看器（这里是替身页）');
    expect(find.byType(PostViewer), findsNothing,
        reason: '不该重建出第二个查看器');
  });

  // fromViewer=false（首页头图等入口）走的是 `context.push`，需要完整的
  // GoRouter 才能渲染；本文件刻意只钉「从查看器来的行为」——那条路径的语义
  // 这次才被改（pop 而不是重建），而 legacy 路径的「按 pageState 重建画廊」
  // 逻辑未改动。要覆盖它需要把整个应用路由起来，成本高于收益。
}
