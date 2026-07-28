import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐私')),
      body: ListView(children: const [
        ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('使用说明'),
          subtitle: Text('BooruNova 不会收集任何个人信息'),
        ),
      ]),
    );
  }
}
