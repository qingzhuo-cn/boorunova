// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:flutter/material.dart';

/// 安全模式挡下「不支持评级过滤」的站点时的说明页。
///
/// 首页 / 探索 / 图集详情三处共用：安全模式的口径必须**处处一致**，否则
/// 用户在首页看到拦截说明，划到探索页却能照常刷到限制级内容——那等于
/// 安全模式根本没生效。
///
/// 刻意不做成一句空态文案：这里必须给用户两条**可执行**的出路，否则他只会
/// 觉得应用坏了（站点明明能用，却什么都没有）。
class SafeModeBlockedView extends StatelessWidget {
  const SafeModeBlockedView({
    super.key,
    required this.onSwitchServer,
    required this.onOpenSettings,
  });

  final VoidCallback onSwitchServer;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_moon_outlined,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(T.safeModeBlockedTitle,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(T.safeModeBlockedBody,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onSwitchServer,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: Text(T.openServers),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.shield_outlined, size: 18),
                  label: Text(T.openSafeModeSettings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
