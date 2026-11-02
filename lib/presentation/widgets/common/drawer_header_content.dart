// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:flutter/material.dart';

/// 抽屉头图**压在头图上的内容块**（不含头图容器本身）。
///
/// 左右两个抽屉共用同一份尺寸口径：图标 32、titleLarge 白字、行内 `min`
/// 尺寸，两边只有「显示什么」不同。
///
/// 为什么是公开组件：这段排版曾经直接写在 home_page 的私有方法里，测试只能
/// 手抄一份「同构」的 Row 去测热区——抄错了测试照样绿（而热区被 Row 的默认
/// `max` 横铺导致「点头图却切了站点」正是这里出过的真问题）。抽成组件后，
/// 测试渲染的就是线上那一份。
class DrawerHeaderContent extends StatelessWidget {
  const DrawerHeaderContent({
    super.key,
    required this.leading,
    required this.title,
    this.trailingIcon,
    this.onTap,
  });

  /// 头图左上角的图标（左抽屉是品牌图标，右抽屉是站标）。
  final Widget leading;

  final String title;

  /// 尾部提示图标（右抽屉的「可切换站点」）。为 null 时不占位，
  /// 于是两边的文字起点仍然一致。
  final IconData? trailingIcon;

  /// 点击回调。为 null 时不套 InkWell —— 纯装饰的头图内容不该有热区。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading,
        const SizedBox(height: 6),
        Row(
          // 必须 min：Row 默认 mainAxisSize.max 会横铺整个头图宽度，
          // 于是右抽屉那层「切换站点」的 InkWell 把整张头图都盖住——
          // 用户点图片时切了站点，还点不进帖子详情。
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 6),
              Icon(trailingIcon, size: 20, color: Colors.white70),
            ],
          ],
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: content,
    );
  }
}
