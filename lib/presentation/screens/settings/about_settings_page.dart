import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
            Text('Version 1.0.0', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            const SizedBox(height: 2),
            Text('MIT License', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
          ]),
        ),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('源代码'),
          subtitle: const Text('github.com/qingzhuo-cn/boorunova'),
          onTap: () => Clipboard.setData(const ClipboardData(text: 'https://github.com/qingzhuo-cn/boorunova')),
        ),
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('反馈问题'),
          subtitle: const Text('GitHub Issues'),
          onTap: () => Clipboard.setData(const ClipboardData(text: 'https://github.com/qingzhuo-cn/boorunova/issues')),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outlined),
          title: const Text('开放许可'),
          subtitle: const Text('MIT License'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('技术栈'),
          subtitle: const Text('Flutter 3 + Riverpod + Hive + GoRouter'),
        ),
      ]),
    );
  }
}
