// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// 「内容来源与举报」说明页。
///
/// 这是 Play UGC 政策三要素（可屏蔽 / 可举报 / 有申诉）在本应用里的落地形态：
/// 应用**不托管也不中转任何内容**，所有内容来自用户自己添加的服务器，所以
/// 「举报」的正确去向是来源站自身的举报入口——这里把用户已配置的服务器列出来，
/// 点一条直接在浏览器里打开，省掉「自己去地址栏敲域名」。
///
/// 刻意**不写死**联系邮箱：Play 商店页强制公示开发者联系方式，那是权威且
/// 会随账号变更的出口；在应用里写一个可能过期的邮箱反而误导用户。
class ContentSourcePage extends ConsumerWidget {
  const ContentSourcePage({super.key});

  Future<void> _open(String baseUrl) async {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final servers = ref.watch(userServerRepoProvider).getAll();
    // 安全模式入口放在这里，与「内容来源」同一页：审核与用户都在同一个
    // 位置看到「内容从哪来」与「怎么限制它」。
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(T.contentSourceEntry)),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(T.contentSourceIntro,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
        ),
        const Divider(),
        SwitchListTile(
          secondary: const Icon(Icons.shield_outlined),
          title: Text(T.safeModeTitle),
          subtitle: Text(
              settings.safeMode ? T.safeModeSubOn : T.safeModeSubOff),
          value: settings.safeMode,
          onChanged: (v) => v
              ? ref.read(settingsProvider.notifier).setSafeMode(true)
              : _confirmAgeAndDisable(context, ref),
        ),
        SectionHeader(title: T.contentSourceServersHeader),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(T.contentSourceServersHint,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
        ),
        if (servers.isEmpty)
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(T.noServerToOpen),
            subtitle: Text(T.addBooruServer),
            onTap: () => context.push('/servers/scan'),
          )
        else
          for (final server in servers)
            ListTile(
              leading: const Icon(Icons.public_outlined),
              title: Text(server.name),
              subtitle: Text(server.baseUrl,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _open(server.baseUrl),
            ),
        SectionHeader(title: T.contentSourceBlockHeader),
        ListTile(
          leading: const Icon(Icons.visibility_off_outlined),
          title: Text(T.blacklistTitle),
          subtitle: Text(T.contentSourceBlockBody),
          onTap: () => context.push('/blacklist'),
        ),
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: Text(T.servers),
          onTap: () => context.push('/servers'),
        ),
        SectionHeader(title: T.contentSourceReportHeader),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(T.contentSourceReportBody,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
        ),
        SectionHeader(title: T.contentSourceAppealHeader),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Text(T.contentSourceAppealBody,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
        ),
      ]),
    );
  }

  /// 关闭安全模式前的本地年龄确认（无账号，纯本地开关）。
  Future<void> _confirmAgeAndDisable(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(T.ageGateTitle),
        content: Text(T.ageGateBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(T.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(T.ageGateConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.markAgeConfirmed();
    await notifier.setSafeMode(false);
  }
}
