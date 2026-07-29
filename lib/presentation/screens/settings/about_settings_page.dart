import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _repoUrl = 'https://github.com/qingzhuo-cn/boorunova';
const _issuesUrl = '$_repoUrl/issues';
const _version = '1.2.2';

class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(children: [
        const SizedBox(height: 24),
        Center(
          child: Column(children: [
            const Icon(Icons.image_search, size: 48),
            const SizedBox(height: 12),
            const Text('BooruNova', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('版本 $_version', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5))),
          ]),
        ),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('源代码'),
          subtitle: const Text('github.com/qingzhuo-cn/boorunova'),
          onTap: () => _openUrl(_repoUrl),
        ),
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('反馈问题'),
          subtitle: const Text('GitHub Issues'),
          onTap: () => _openUrl(_issuesUrl),
        ),
        ListTile(
          leading: const Icon(Icons.gavel_outlined),
          title: const Text('开源协议'),
          subtitle: const Text('MIT License'),
          onTap: () => _openUrl('$_repoUrl/blob/main/LICENSE'),
        ),
      ]),
    );
  }
}
