import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/screens/server/booru_site_template.dart';
import 'package:boorunova/presentation/screens/server/server_editor_page.dart';
import 'package:boorunova/presentation/screens/server/server_probe_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ServerPage extends ConsumerStatefulWidget {
  const ServerPage({super.key});

  @override
  ConsumerState<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends ConsumerState<ServerPage> {
  bool _reorderMode = false;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(userServerRepoProvider);
    final servers = repo.getAll();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(T.servers),
        actions: [
          if (servers.length >= 2)
            IconButton(
              icon: Icon(_reorderMode ? Icons.check : Icons.format_list_numbered),
              tooltip: _reorderMode ? '完成' : '排序',
              onPressed: () => setState(() => _reorderMode = !_reorderMode),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'custom_server',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ServerScanPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: _reorderMode && servers.length >= 2
          ? ReorderableListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (var i = 0; i < servers.length; i++)
                  _ServerTile(
                    key: ValueKey(servers[i].id),
                    dragHandle: true,
                    server: servers[i],
                    onEdit: () => _editServer(servers[i]),
                    onDelete: () => _delete(context, ref, servers[i]),
                  ),
              ],
              onReorder: (oldIndex, newIndex) {
                ref.read(userServerRepoProvider).reorder(oldIndex, newIndex);
                ref.invalidate(userServerRepoProvider);
              },
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (servers.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      servers.length >= 2
                          ? '${T.myServers}   \u2014 点击右上角排序'
                          : T.myServers,
                      style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                  for (final s in servers)
                    _ServerTile(
                      server: s,
                      onEdit: () => _editServer(s),
                      onDelete: () => _delete(context, ref, s),
                    ),
                  const Divider(height: 32),
                  const SizedBox(height: 16),
                ] else
                  const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    T.popularSites,
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                ...BooruSiteTemplate.all.map((t) {
                  final added = servers.any((s) => s.type == t.type);
                  return _TemplateTile(
                    key: ValueKey('tpl_${t.type.value}'),
                    template: t,
                    added: added,
                    onTap: () {
                      if (added) {
                        final existing = servers.firstWhere((s) => s.type == t.type);
                        _editServer(existing);
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ServerEditorPage(template: t)),
                        );
                      }
                    },
                  );
                }),
              ],
            ),
    );
  }

  void _editServer(BooruServer server) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ServerEditorPage(serverId: server.id)),
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
    super.key,
    this.dragHandle = false,
    required this.server,
    required this.onEdit,
    required this.onDelete,
  });

  final bool dragHandle;
  final BooruServer server;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _ServerFavicon(url: server.baseUrl),
      title: Text(server.name),
      subtitle: Text(server.baseUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dragHandle)
            const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text(T.edit)),
              const PopupMenuItem(value: 'delete', child: Text(T.delete)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    super.key,
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
      leading: _ServerFavicon(url: template.baseUrl),
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

class _ServerFavicon extends StatelessWidget {
  const _ServerFavicon({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) {
    try {
      final uri = Uri.parse(url);
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network('${uri.scheme}://${uri.host}/favicon.ico', width: 24, height: 24,
          errorBuilder: (_, __, ___) => const Icon(Icons.public, size: 20)),
      );
    } catch (_) {
      return const Icon(Icons.public, size: 20);
    }
  }
}
