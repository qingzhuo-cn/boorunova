import 'package:boorunova/presentation/widgets/common/drawer_header_content.dart';
import 'package:boorunova/presentation/widgets/common/side_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 侧栏头图与头部内容的**热区边界**回归。
///
/// 用户实测：「左侧栏的图片点不进去；右侧栏的图片点了会切换站点」。
/// 根因是右抽屉头部那层"切换站点"的 InkWell 把整张头图盖住了——头部的
/// Row 用了默认的 `mainAxisSize.max`，热区横铺整个宽度。
///
/// 这里锁住契约：头部内容窄（内容有多大热区就多大），头图其余区域归头图。
/// 若把 header 里的 Row 改回 `max`，本用例立刻失败。
void main() {
  testWidgets('头部内容不侵占头图热区：点图片进帖子，点内容才触发内容回调', (tester) async {
    var artworkTaps = 0;
    var headerTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 176,
              child: SideNavPanel(
                groups: const [],
                // 头部内容用**线上那一份**组件（不再是测试里手抄的同构 Row）：
                // 热区被 Row 的默认 max 横铺正是这里出过的真问题，测试必须打
                // 在真实实现上，抄一份就失去了守卫意义。
                header: DrawerHeaderContent(
                  leading: const Icon(Icons.image_search,
                      size: 32, color: Colors.white),
                  title: '站点名',
                  trailingIcon: Icons.swap_horiz,
                  onTap: () => headerTaps++,
                ),
                // 头图：整张可点，与 SiteArtwork 的热区口径一致
                artwork: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => artworkTaps++,
                  child: const ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(SideNavPanel));

    // 1) 点头部内容**同一水平带**、但远离文字右侧的图片区域 → 必须命中头图。
    //
    // 纵向落在头部内容带内（不是上方那片纯图片）：这才是原来出事的几何——
    // 头部内容的 Row 一旦用 mainAxisSize.max，它的 InkWell 会横铺整个头图
    // 宽度，把这一整条都吃掉（用户点图片却切了站点）。
    await tester.tapAt(Offset(rect.right - 40, rect.bottom - 46));
    await tester.pump();
    expect(artworkTaps, 1, reason: '点头图应当命中头图，而不是被头部热区吃掉');
    expect(headerTaps, 0, reason: '头图区域的点击不该触发头部回调（切换站点）');

    // 2) 点头部内容文字 → 命中头部回调
    await tester.tap(find.text('站点名'));
    await tester.pump();
    expect(headerTaps, 1);
    expect(artworkTaps, 1, reason: '点头部内容不该同时触发头图');
  });
}
