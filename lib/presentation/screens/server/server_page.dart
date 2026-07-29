import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/screens/server/booru_site_template.dart';
import 'package:boorunova/presentation/screens/server/server_editor_page.dart';
import 'package:boorunova/presentation/screens/server/server_probe_page.dart';
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
            MaterialPageRoute(builder: (_) => const ServerScanPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: servers.isEmpty
          ? ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                const SizedBox(height: 100),
                ..._buildTemplateSection(context, servers, theme),
              ],
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              key: const PageStorageKey('server_list'),
              itemCount: servers.length + _templatesHeaderCount + BooruSiteTemplate.all.length,
              onReorder: (oldIndex, newIndex) {
                final headerOffset = 1;
                if (oldIndex < headerOffset || newIndex < headerOffset) return;
                final serverOld = oldIndex - headerOffset;
                final serverNew = newIndex - headerOffset;
                if (serverOld < servers.length && serverNew < servers.length) {
                  ref.read(userServerRepoProvider).reorder(serverOld, serverNew);
                  ref.invalidate(userServerRepoProvider);
                }
              },
              buildDefaultDragHandles: false,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    key: const Key('server_header'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      '${T.myServers}   \u2014 长按拖动排序',
                      style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                    ),
                  );
                }
                final serverIndex = index - 1;
                if (serverIndex < servers.length) {
                  final s = servers[serverIndex];
                  return _ServerTile(
                    key: ValueKey(s.id),
                    index: index,
                    server: s,
                    onEdit: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ServerEditorPage(serverId: s.id)),
                      );
                    },
                    onDelete: () => _delete(context, ref, s),
                  );
                }
                final templateIndex = index - 1 - servers.length - 1;
                if (templateIndex == 0) {
                  return Padding(
                    key: const Key('templates_header'),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      T.popularSites,
                      style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                    ),
                  );
                }
                if (templateIndex > 0) {
                  final t = BooruSiteTemplate.all[templateIndex - 1];
                  final added = servers.any((s) => s.type == t.type);
                  return _TemplateTile(
                    key: ValueKey('tpl_${t.type.value}'),
                    template: t,
                    added: added,
                    onTap: () {
                      if (added) {
                        final existing = servers.firstWhere((s) => s.type == t.type);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ServerEditorPage(serverId: existing.id)),
                        );
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ServerEditorPage(template: t)),
                        );
                      }
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
    );
  }

  static const _templatesHeaderCount = 2;

  List<Widget> _buildTemplateSection(BuildContext context, List<BooruServer> servers, ThemeData theme) {
    return [
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
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ServerEditorPage(serverId: existing.id)),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ServerEditorPage(template: t)),
              );
            }
          },
        );
      }),
    ];
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
    required this.index,
    required this.server,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
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
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
          ),
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
