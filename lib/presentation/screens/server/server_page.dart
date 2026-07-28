import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/screens/server/booru_site_template.dart';
import 'package:boorunova/presentation/screens/server/server_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ServerPage extends ConsumerWidget {
  const ServerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(userServerRepoProvider);
    final servers = repo.getAll();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(T.servers)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'custom_server',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ServerEditorPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (servers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                T.myServers,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            for (final s in servers)
              _ServerTile(
                server: s,
                onEdit: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServerEditorPage(serverId: s.id),
                    ),
                  );
                },
                onDelete: () => _delete(context, ref, s),
              ),
            const Divider(height: 32),
          ],
          Padding(
            key: null,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              T.popularSites,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ...BooruSiteTemplate.all.map((t) {
            final added = servers.any((s) => s.type == t.type);
            return _TemplateTile(
                template: t,
              added: added,
              onTap: () {
                if (added) {
                  final existing = servers.firstWhere((s) => s.type == t.type);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServerEditorPage(serverId: existing.id),
                    ),
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServerEditorPage(template: t),
                    ),
                  );
                }
              },
            );
          }),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, BooruServer server) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(T.removeServer),
        content: Text('${T.deleteConfirm}${server.name}${T.deleteConfirmEnd}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(T.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(T.delete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(userServerRepoProvider).delete(server.id);
      ref.invalidate(userServerRepoProvider);
    }
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.server,
    required this.onEdit,
    required this.onDelete,
  });

  final BooruServer server;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final template = BooruSiteTemplate.findByType(server.type);
    final icon = template?.icon ?? Icons.dns_outlined;
    final color = template?.color ?? Colors.grey;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(server.name),
      subtitle: Text(server.baseUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: PopupMenuButton<String>(
        onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text(T.edit)),
          const PopupMenuItem(value: 'delete', child: Text(T.delete)),
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.added,
    required this.onTap,
  });

  final BooruSiteTemplate template;
  final bool added;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: template.color.withOpacity(0.2),
        child: Icon(template.icon, color: template.color, size: 20),
      ),
      title: Text(template.name),
      subtitle: Text(template.description ?? template.baseUrl,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(
        added ? Icons.check_circle : Icons.add_circle_outline,
        color: added ? Colors.green : Colors.grey,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
