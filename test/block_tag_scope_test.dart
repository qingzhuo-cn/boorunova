import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/widgets/common/block_tag_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 快捷屏蔽（OPT §5.5）的作用域映射与对话框契约。
///
/// 作用域语义是**全局 = 空 serverId**——过滤侧 `filterBlockedPosts` 就是按这个
/// 约定判断「对所有站点生效」的。所以这条映射必须有测试，改错了会静默地
/// 把「全局屏蔽」变成「只在某一个站点屏蔽」。
void main() {
  group('作用域映射', () {
    test('全局 → 空 serverId（过滤侧据此判定对所有站点生效）', () {
      expect(blockScopeServerId(BlockTagScope.global, 'srv-1'), '');
    });

    test('仅本站 → 用帖子的 serverId', () {
      expect(blockScopeServerId(BlockTagScope.thisSite, 'srv-1'), 'srv-1');
    });

    test('没有 serverId 时「仅本站」退化成全局（总比丢进空作用域好）', () {
      expect(blockScopeServerId(BlockTagScope.thisSite, ''), '');
    });
  });

  group('对话框三种出口', () {
    /// 极简宿主：按一下就把对话框的结果记下来。
    Future<BlockTagScope?> tapAndRead(
      WidgetTester tester,
      String buttonLabel, {
      String tag = 'cat',
      String? siteName = 'My Site',
    }) async {
      BlockTagScope? result;
      var answered = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await askBlockTagScope(
                    context,
                    tag: tag,
                    siteName: siteName,
                  );
                  answered = true;
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text(T.blockThisTag), findsOneWidget,
          reason: '应先问清楚在哪儿屏蔽');
      expect(find.textContaining('cat'), findsWidgets,
          reason: '对话框要写明是哪个标签');

      await tester.tap(find.text(buttonLabel));
      await tester.pumpAndSettle();
      expect(answered, isTrue);
      return result;
    }

    testWidgets('选「全局屏蔽」→ global', (tester) async {
      expect(await tapAndRead(tester, T.blockGlobally), BlockTagScope.global);
    });

    testWidgets('选站点按钮 → thisSite（按钮文案带站点名）', (tester) async {
      // T.blockScopeFor('My Site') 展开成「仅 My Site」
      final siteLabel = T.blockScopeFor('My Site');
      expect(await tapAndRead(tester, siteLabel), BlockTagScope.thisSite);
    });

    testWidgets('取消 → null（什么都不做）', (tester) async {
      expect(await tapAndRead(tester, T.cancel), isNull);
    });

    testWidgets('没有站点名时站点按钮退化成「仅本站屏蔽」', (tester) async {
      expect(
        await tapAndRead(tester, T.blockOnThisSite, siteName: null),
        BlockTagScope.thisSite,
      );
    });
  });
    testWidgets('没有 serverId 时不提供「仅本站」选项，避免静默升级成全局', (tester) async {
      // 修复前：对话框照样给「仅本站屏蔽」，而映射会把空 serverId 退化成空串
      // = 全局屏蔽——用户点的是「只在这个站」，结果哪个站都没有了。
      var answered = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  await askBlockTagScope(
                    context,
                    tag: 'cat',
                    siteName: null,
                    canScopeToSite: false,
                  );
                  answered = true;
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text(T.blockGlobally), findsOneWidget);
      expect(find.text(T.blockOnThisSite), findsNothing,
          reason: '无从谈起的选项不该出现');

      await tester.tap(find.text(T.cancel));
      await tester.pumpAndSettle();
      expect(answered, isTrue);
    });

    testWidgets('没有 serverId 时仍可选「全局屏蔽」（唯一有意义的出口）',
        (tester) async {
      BlockTagScope? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await askBlockTagScope(
                    context,
                    tag: 'cat',
                    canScopeToSite: false,
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(T.blockGlobally));
      await tester.pumpAndSettle();

      expect(result, BlockTagScope.global);
    });
}
