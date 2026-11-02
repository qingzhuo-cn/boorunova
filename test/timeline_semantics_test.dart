import 'dart:io';

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/widgets/timeline/timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// 瀑布流瓦片的无障碍标签（OPT §5.2）。
///
/// 修复前瓦片对读屏用户只是「一张图」：没有按钮角色，也没有任何文本，
/// TalkBack 里既听不出是哪一条、也点不开。这里按**语义标签**找节点再断言。
///
/// 两个测试细节都是踩出来的：
/// 1. 瓦片有入场动画（FadeTransition 从 opacity 0 开始），而 opacity 0 的
///    FadeTransition 会把子树从语义树上摘掉——不等动画结束，标签永远读到空。
///    这里开「减少动画」让瓦片不进动画路径，断言才与实现无关。
///    顺带记下现状：新瓦片在淡入的 300ms 内没有语义（滚得快时读屏听不到），
///    这是 Flutter 的默认行为，也符合「还没显示出来就不播报」。
/// 2. 标签挂在**瓦片节点**上，不在外层 Timeline 上，所以用 bySemanticsLabel
///    定位，而不是 getSemantics(find.byType(Timeline))。
PostSummary _post({String id = '42', bool video = false, String? duration}) =>
    PostSummary(
      id: id,
      serverId: 'srv',
      thumbnailUrl: 'https://x.test/t.jpg',
      sampleUrl: '',
      // 视频帖靠 originalUrl 的扩展名判定
      originalUrl: video ? 'https://x.test/v.mp4' : '',
      tags: const ['a'],
      aspectRatio: 2 / 3,
      width: 300,
      height: 450,
      rating: 's',
      score: 0,
      duration: duration,
    );

Future<void> _pump(
  WidgetTester tester, {
  required PostSummary post,
  bool selectionMode = false,
  bool isSelected = false,
  void Function(int)? onSelectionToggle,
  void Function(int)? onFavorite,
}) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            Timeline(
              posts: [post],
              onPostTap: (_) {},
              selectionMode: selectionMode,
              selectedIds:
                  isSelected ? {'${post.serverId}/${post.id}'} : const {},
              onSelectionToggle: onSelectionToggle,
              onFavorite: onFavorite,
            ),
          ],
        ),
      ),
    ),
  ));
  await tester.pump();
}

/// 跑一段需要语义树的断言，结束后**立刻**释放 SemanticsHandle。
///
/// 不能只靠 addTearDown：框架的「handle 必须已释放」检查发生在 tearDown
/// 之前，addTearDown 太晚，会报 A SemanticsHandle was active at the end of
/// the test。
Future<void> _withSemantics(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final handle = tester.ensureSemantics();
  try {
    await body();
  } finally {
    handle.dispose();
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('boorunova_timeline_sem');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveSetup.settingsBoxName);
    await Hive.openBox(HiveSetup.serversBoxName);
    await HiveSetup.settingsBox
        .put('app_settings', const {'reduceAnimations': true});
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('瓦片带「查看帖子」标签与按钮角色', (tester) async {
    await _withSemantics(tester, () async {
      await _pump(tester, post: _post(id: '777'));

      final label = T.viewPostSemantics('777');
      expect(find.bySemanticsLabel(label), findsOneWidget);

      final data = tester
          .getSemantics(find.bySemanticsLabel(label))
          .getSemanticsData();
      expect(data.hasFlag(SemanticsFlag.isButton), isTrue,
          reason: '没有按钮角色时 TalkBack 不会提示可以点开');
      expect(data.hasAction(SemanticsAction.tap), isTrue,
          reason: '读屏的双击激活必须真的能触发打开帖子');
    });
  });

  testWidgets('视频帖的标签说明是视频（打开行为不同）', (tester) async {
    await _withSemantics(tester, () async {
      await _pump(
        tester,
        post: _post(id: '9', video: true, duration: '05:12'),
      );

      // 用 RegExp 而不是字符串：`bySemanticsLabel(String)` 要求**完全相等**，
      // 而瓦片节点的最终 label 会并入子节点的文本（视频时长、评分），
      // 实际是「查看视频帖 9 05:12」这一类。RegExp 走包含匹配。
      final node =
          tester.getSemantics(find.bySemanticsLabel(RegExp('查看视频帖 9')));
      final data = node.getSemanticsData();
      expect(data.label, contains('查看视频帖 9'));
      expect(data.label, contains('05:12'),
          reason: '时长并入标签是好事：读屏用户不用点开就知道多长');
    });
  });

  testWidgets('批量选择模式下播报选中状态', (tester) async {
    await _withSemantics(tester, () async {
      await _pump(
        tester,
        post: _post(),
        selectionMode: true,
        isSelected: true,
        onSelectionToggle: (_) {},
      );

      final data = tester
          .getSemantics(find.bySemanticsLabel(T.viewPostSemantics('42')))
          .getSemanticsData();
      expect(data.hasFlag(SemanticsFlag.isSelected), isTrue,
          reason: '勾选状态对读屏用户必须可见');
    });
  });

  testWidgets('非选择模式不带 selected 状态（避免误报已选中）', (tester) async {
    await _withSemantics(tester, () async {
      await _pump(tester, post: _post());

      final data = tester
          .getSemantics(find.bySemanticsLabel(T.viewPostSemantics('42')))
          .getSemanticsData();
      expect(data.hasFlag(SemanticsFlag.isSelected), isFalse);
    });
  });

  testWidgets('瓦片内的收藏按钮有独立标签，不会被并进「打开帖子」', (tester) async {
    await _withSemantics(tester, () async {
      await _pump(tester, post: _post(), onFavorite: (_) {});

      // 此前它是个**没有标签**的可点节点：读屏只念「按钮」。
      expect(
        find.bySemanticsLabel(T.favoriteToggleSemantics(false)),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(T.viewPostSemantics('42')), findsOneWidget,
          reason: '两个动作各自成节点，不能合成一句话');
    });
  });

  testWidgets('瓦片里没有「自带无标签语义」的手势（防止重复播报）', (tester) async {
    await _withSemantics(tester, () async {
      await _pump(tester, post: _post(), onFavorite: (_) {});

      // GestureDetector 默认会生成一个语义节点（无标签的「按钮」），于是同一个
      // 「打开帖子」动作会被读屏念两遍。瓦片里所有手势都要么自己给语义、
      // 要么 excludeFromSemantics。
      final loose = tester
          .widgetList<GestureDetector>(find.byType(GestureDetector))
          .where((g) => !g.excludeFromSemantics)
          .toList();
      expect(loose, isEmpty,
          reason: '有 ${loose.length} 个手势没有排除自身语义'
              '（会在读屏里多出一个无标签按钮）');
    });
  });
}
