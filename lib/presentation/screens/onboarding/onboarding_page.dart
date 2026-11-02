// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/onboarding_state.dart';
import 'package:boorunova/presentation/screens/server/booru_site_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 首次启动引导：选择语言 → 勾选要浏览的站点 → 进入首页。
/// 由路由 redirect 在「无服务器且未完成引导」时强制进入。
///
/// `_step` / 已勾选站点存放在 onboardingProvider，语言切换导致的整树
/// 重建不会丢失当前进度。
class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  static final List<BooruSiteTemplate> _templates = BooruSiteTemplate.all;

  /// 保存当前已勾选的站点并完成引导（用于「开始/下一步」）。
  Future<void> _finish(WidgetRef ref, BuildContext context) async {
    final selected = ref.read(onboardingProvider).selected;
    final repo = ref.read(userServerRepoProvider);
    // 按 baseUrl 去重，避免重复进入引导时再次添加已有站点
    final existingUrls = repo.getAll().map((s) => s.baseUrl).toSet();
    for (final t in _templates) {
      if (!selected.contains(t.type)) continue;
      if (existingUrls.contains(t.baseUrl)) continue;
      await repo.save(BooruServer.create(
        name: t.name,
        baseUrl: t.baseUrl,
        type: t.type,
      ));
    }
    await _complete(ref);
    if (context.mounted) context.go('/');
  }

  /// 跳过：不添加任何站点，仅完成引导进入首页。
  Future<void> _skip(WidgetRef ref, BuildContext context) async {
    await _complete(ref);
    if (context.mounted) context.go('/');
  }

  /// 收尾：同步引导完成状态并复位引导流程（不含导航）。
  Future<void> _complete(WidgetRef ref) async {
    ref.invalidate(userServerRepoProvider);
    await ref.read(settingsProvider.notifier).completeOnboarding();
    ref.read(onboardingProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ob = ref.watch(onboardingProvider);
    final step = ob.step;
    final language = ref.watch(settingsProvider).language;

    return PopScope(
      // 系统返回键：第 1 步回退到语言选择，第 0 步不退出（引导未完成）
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (step > 0) {
          ref.read(onboardingProvider.notifier).setStep(0);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  step == 0 ? T.obWelcome : T.obChooseSites,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  step == 0 ? T.obWelcomeSubtitle : T.obChooseSitesSubtitle,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: step == 0
                      ? _buildLanguageStep(theme, language, ref)
                      : _buildSitesStep(context, theme, ref),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _skip(ref, context),
                      child: Text(T.obSkip),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () {
                        if (step == 0) {
                          ref.read(onboardingProvider.notifier).setStep(1);
                        } else {
                          _finish(ref, context);
                        }
                      },
                      icon: Icon(step == 0 ? Icons.arrow_forward : Icons.rocket_launch_outlined),
                      label: Text(step == 0 ? T.obNext : T.obStart),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageStep(ThemeData theme, String language, WidgetRef ref) {
    Widget card(String code, IconData icon, String name, String subtitle) {
      final selected = language.startsWith(code);
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: ListTile(
          leading: Icon(icon,
              color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
          title: Text(name, style: theme.textTheme.titleMedium),
          subtitle: Text(subtitle),
          trailing:
              selected ? Icon(Icons.check_circle, color: theme.colorScheme.primary) : null,
          onTap: () {
            // 立即生效：后续步骤文案随选随切
            ref.read(settingsProvider.notifier).setLanguage(code);
          },
        ),
      );
    }

    return Column(
      children: [
        card('zh', Icons.language, T.langZhName,
            T.isEn ? 'Chinese (Simplified)' : T.langZhSub),
        card('en', Icons.abc, T.langEnName,
            T.isEn ? T.langEnSub : 'English (US)'),
      ],
    );
  }

  Widget _buildSitesStep(BuildContext context, ThemeData theme, WidgetRef ref) {
    // Play 版没有出厂模板（site_presets 编译期置空）：引导页不能变成一个
    // 空白列表，而是引导用户**自己添加第一个服务器**——这正是 BYO 的
    // 第一课，也保证界面上不出现任何站点名。
    if (_templates.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Icon(Icons.add_link,
              size: 40, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(T.addBooruServer, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await _complete(ref);
              if (context.mounted) await context.push('/servers/scan');
            },
            icon: const Icon(Icons.add),
            label: Text(T.addServer),
          ),
        ],
      );
    }
    final selected = ref.watch(onboardingProvider).selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _templates.length,
            itemBuilder: (context, i) {
              final t = _templates[i];
              final checked = selected.contains(t.type);
              return CheckboxListTile(
                value: checked,
                secondary: CircleAvatar(
                  backgroundColor: t.color.withOpacity(0.15),
                  child: Icon(t.icon, color: t.color, size: 20),
                ),
                title: Text(t.name),
                subtitle: Text(t.description ?? t.baseUrl,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onChanged: (v) {
                  // 同 type 多镜像（moebooru）按 type 记录即可
                  ref
                      .read(onboardingProvider.notifier)
                      .toggle(t.type, v ?? false);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                T.obSiteAuthNote,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
