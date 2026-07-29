import 'package:flutter/material.dart';

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('语言')),
      body: ListView(children: const [
        ListTile(
          leading: Icon(Icons.check, color: Colors.green),
          title: Text('简体中文'),
          subtitle: Text('当前语言'),
        ),
        ListTile(
          leading: Icon(Icons.language, color: Colors.grey),
          title: Text('English'),
          enabled: false,
        ),
      ]),
    );
  }
}
