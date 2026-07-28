import 'package:flutter/material.dart';

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('语言')),
      body: ListTile(
        leading: const Icon(Icons.language),
        title: const Text('简体中文'),
        trailing: const Icon(Icons.check, color: Colors.green),
      ),
    );
  }
}
