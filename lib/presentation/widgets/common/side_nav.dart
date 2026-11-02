// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/presentation/widgets/common/glass.dart';
import 'package:boorunova/presentation/widgets/common/site_artwork.dart';
import 'package:flutter/material.dart';

/// 一个侧栏菜单项的纯数据描述。
///
/// 侧栏此前是两组写死的 `ListTile`（左右抽屉各一份），样式改一处就要
/// 记得改另一处。抽成数据后，左右抽屉只负责「有哪些项 + 点了干什么」。
class SideNavItem {
  const SideNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// 液态玻璃侧栏面板：顶部站点随机图头图 + 下方一组组「各自独立」的玻璃菜单。
///
/// 「各项独立」是这个组件存在的理由：此前所有菜单项共用抽屉这一块面板，
/// 每项只有一条 1px 下划线，读起来是一张长列表而不是一层层玻璃。
/// 现在每一项都是自带圆角、描边、高光和阴影的独立玻璃块，
/// 与底部搜索栏（GlassContainer）用同一套语言。
class SideNavPanel extends StatelessWidget {
  const SideNavPanel({
    super.key,
    required this.header,
    required this.groups,
    this.right = false,
    this.artwork = const SiteArtwork(),
  });

  /// 头图上的内容。文字/图标需自带浅色，头图背景是暗压过的照片。
  final Widget header;

  /// 分组展示菜单项：组内紧凑、组间留更大空隙，替代原来的 Divider。
  final List<List<SideNavItem>> groups;

  /// 是否属于右抽屉：只影响外侧圆角方向。
  final bool right;

  /// 头图底图。默认取当前站点的随机安全图；测试里注入静态占位
  /// 以避开真实网络请求。
  final Widget artwork;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SideNavHeader(right: right, artwork: artwork, child: header),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
            children: [
              for (var g = 0; g < groups.length; g++) ...[
                // 组间距用留白而不是分割线：独立玻璃块之间再画横线，
                // 视觉上又会被串回一张列表。
                if (g > 0) const SizedBox(height: 10),
                for (final item in groups[g]) GlassNavTile(item: item),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 侧栏头图：随机网络图片铺底 + 压暗渐隐，内容压在左下角。
///
/// 图片在下边缘 14% 内渐隐到透明，露出抽屉自身的玻璃底色，避免在
/// 图片和菜单之间出现一条硬边；内容区不在渐隐范围内（见 [build] 里的
/// 说明），所以文字下方始终有完整厚度的压暗层，浅色主题下也是白字可读。
class SideNavHeader extends StatelessWidget {
  const SideNavHeader({
    super.key,
    required this.child,
    this.right = false,
    this.height = 176,
    this.artwork = const SiteArtwork(),
  });

  final Widget child;
  final bool right;
  final double height;

  /// 头图底图，默认 [SiteArtwork]。
  final Widget artwork;

  /// 下边缘渐隐占整个头图的比例。内容底边留白必须大于它，否则文字会
  /// 落到渐隐区里，压暗层变薄、白字失去对比。
  static const double _fadeRatio = 0.14;

  @override
  Widget build(BuildContext context) {
    // 只圆外侧：左抽屉圆右上，右抽屉圆左上，贴合滑出的方向。
    // （面板外层还有一层同半径的裁剪，这里是为了组件能独立使用。）
    final radius = BorderRadius.only(
      topLeft: Radius.circular(right ? 20 : 0),
      topRight: Radius.circular(right ? 0 : 20),
    );

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 图片 + 压暗层一起做下边缘渐隐。
            ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 1 - _fadeRatio, 1],
              ).createShader(rect),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  artwork,
                  // 上浅下深的压暗：上边缘还能看出照片，下半部分安静下来，
                  // 标题压在深色处，任何图片上都是白字可读。
                  //
                  // 必须 IgnorePointer：DecoratedBox 的 hitTestSelf 会返回真
                  // （BoxDecoration.hitTest 默认 true），压在图片上就把整张
                  // 头图的点击全吃掉了——用户实测"侧栏图片点不进去"正是它。
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x3D000000),
                            Color(0x99000000),
                            Color(0xB3000000),
                          ],
                          stops: [0, 0.55, 1],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 内容不在 ShaderMask 里：它不该跟着图片一起渐隐。
            // 底部留白 26 > 176 * 0.14 ≈ 25，文字整体落在实心压暗层上。
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 独立玻璃菜单项：每项一块玻璃，而不是共用列表背景。
///
/// 这里传 `blur: false`：抽屉本身就有一层 [BackdropFilter] 在模糊下层
/// 滚动内容，菜单项再各自叠一层，采样的还是那张已经模糊过的结果，
/// 观感几乎不变却要多付 N 次模糊合成；侧栏只有几项，但仍然没必要。
/// 玻璃的其余要素（半透填充、描边、顶部高光、投影）都在，所以每一项
/// 依然是独立的一块玻璃。
class GlassNavTile extends StatelessWidget {
  const GlassNavTile({super.key, required this.item});

  final SideNavItem item;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(18));

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dark = colorScheme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      // 投影画在玻璃外侧：玻璃内部那层 BackdropFilter 会裁剪掉自己的
      // 阴影，因此阴影不能挂在 GlassContainer 的 decoration 上。
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.30 : 0.10),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: GlassContainer(
          borderRadius: _radius,
          tint: dark ? Colors.black : Colors.white,
          fillOpacity: dark ? 0.30 : 0.34,
          blur: false,
          child: ClipRRect(
            borderRadius: _radius,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: _radius,
                onTap: item.onTap,
                child: Padding(
                  // 上下各 14 + 图标 20 = 48，正好卡住 Material 的最小点击尺寸。
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  child: Row(
                    children: [
                      Icon(item.icon, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
