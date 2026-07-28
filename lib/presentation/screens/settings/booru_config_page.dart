import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BooruConfigPage extends ConsumerWidget {
  const BooruConfigPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(userServerRepoProvider).getAll();
    return Scaffold(
      appBar: AppBar(title: const Text('Booru 配置')),
      body: servers.isEmpty
          ? Center(child: Text('暂无服务器', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))))
          : ListView(children: [
              for (final s in servers)
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: Text(s.name),
                  subtitle: Text(s.baseUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => _showConfig(context, ref, s),
                ),
            ]),
    );
  }

  void _showConfig(BuildContext context, WidgetRef ref, BooruServer server) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(server.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Text('API 地址: ${server.baseUrl}', style: const TextStyle(fontSize: 13)),
          Text('类型: ${server.type.value}', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 24),
          const Text('更多配置即将推出', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
    );
  }
}
