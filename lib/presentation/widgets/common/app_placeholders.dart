// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:flutter/material.dart';

/// 设置页分节标题：全应用唯一的分节样式。
///
/// 取代此前 4 份漂移的实现（三种 Colors.grey 灰 + 一种 titleSmall+primary）。
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

/// 统一空状态：图标 + 标题 + 可选提示行。
///
/// 此前该模式在 8 个页面被复制且有三档质量（完整/半裸/纯文本），
/// 统一收口到这一份。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
    this.padding = const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
  });

  final IconData icon;
  final String title;
  final String? hint;

  /// 可选的动作按钮（如「重试」），显示在提示行下方。
  final Widget? action;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
            textAlign: TextAlign.center,
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
