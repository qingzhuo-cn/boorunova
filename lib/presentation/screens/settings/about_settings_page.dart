// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'dart:io';

import 'package:boorunova/boorus/engine/site_presets.dart';
import 'package:boorunova/foundation/util/diagnostic_log.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_version.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _repoUrl = 'https://github.com/qingzhuo-cn/boorunova';
const _issuesUrl = '$_repoUrl/issues';

class AboutSettingsPage extends ConsumerWidget {
  const AboutSettingsPage({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 导出本地诊断日志。
  ///
  /// 走系统分享面板：日志只在用户主动选择接收方时离开设备——
  /// 这样「数据不出设备」的承诺与「偶发崩溃可被定位」不再互相排斥。
  Future<void> _exportDiagnostics(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (DiagnosticLog.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(T.noDiagnostics)));
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${DiagnosticLog.exportFileName()}');
      await file.writeAsString(DiagnosticLog.export());
      await Share.shareXFiles([XFile(file.path)], subject: 'BooruNova diagnostics');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(T.friendlyError(e.toString()))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final version = ref.watch(appVersionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(T.about)),
      body: ListView(children: [
        const SizedBox(height: 24),
        Center(
          child: Column(children: [
            const Icon(Icons.image_search, size: 48),
            const SizedBox(height: 12),
            Text(T.appTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${T.versionLabel} $version',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5))),
          ]),
        ),
        const SizedBox(height: 24),
        // Play 版不链 GitHub：仓库 README 里有完整站点表与内容截图，对审核员
        // 是公开可查的「意图证据」。GitHub 版照常保留（那是它的用户支持入口）。
        if (!kPlayBuild) ...[
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(T.sourceCode),
            subtitle: const Text('github.com/qingzhuo-cn/boorunova'),
            onTap: () => _openUrl(_repoUrl),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(T.reportIssue),
            subtitle: const Text('GitHub Issues'),
            onTap: () => _openUrl(_issuesUrl),
          ),
        ],
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(T.exportDiagnostics),
          subtitle: Text(T.exportDiagnosticsSub),
          onTap: () => _exportDiagnostics(context),
        ),
        ListTile(
          leading: const Icon(Icons.gavel_outlined),
          title: Text(T.openSource),
          subtitle: const Text('GNU AGPL-3.0'),
          // Play 版只显示许可，不提供外链（同上的审核口径）
          onTap: kPlayBuild ? null : () => _openUrl('$_repoUrl/blob/main/LICENSE'),
        ),
      ]),
    );
  }
}
