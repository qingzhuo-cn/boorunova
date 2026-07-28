import 'package:flutter/material.dart';

class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.image_search, size: 64),
          const SizedBox(height: 16),
          const Text('BooruNova', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Version 1.0.0', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 4),
          Text('MIT License', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 24),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('开源许可'),
          ),
        ]),
      ),
    );
  }
}
