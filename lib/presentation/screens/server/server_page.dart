// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/data/repository/hosts/user_hosts_repo.dart';
import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/server_health.dart';
import 'package:boorunova/presentation/screens/server/booru_site_template.dart';
import 'package:boorunova/presentation/widgets/common/server_favicon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ServerPage extends ConsumerStatefulWidget {
  const ServerPage({super.key});

  @override
  ConsumerState<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends ConsumerState<ServerPage> {
  bool _reorderMode = false;

  /// 该站点是否正处于 hosts 映射生效状态（OPT §5.4 的可视化要求）。
  ///
  /// 只在 hosts 总开关打开、且确实有匹配的映射时才显示——否则「hosts」这个
  /// 徽章会出现在每一条上，等于没有信息量。地址解析失败时按「没有映射」处理。
  bool _hostsMapped(String baseUrl) {
    if (!ref.watch(settingsProvider).hostsEnabled) return false;
    final host = Uri.tryParse(baseUrl)?.host ?? '';
    if (host.isEmpty) return false;
    try {
      return ref.read(userHostsRepoProvider).match(host) != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(userServerRepoProvider);
    final servers = repo.getAll();
    final theme = Theme.of(context);
    final health = ref.watch(serverHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(T.servers),
        actions: [
          // 一次检查全部站点（OPT §5.4 健康面板）
          IconButton(
            icon: const Icon(Icons.monitor_heart_outlined),
            tooltip: T.checkAllServers,
            onPressed: servers.isEmpty
                ? null
                : () => ref
                    .read(serverHealthProvider.notifier)
                    .checkAll(servers),
          ),
          if (servers.length >= 2)
            IconButton(
              icon: Icon(_reorderMode ? Icons.check : Icons.format_list_numbered),
              tooltip: _reorderMode ? T.done : T.reorder,
              onPressed: () => setState(() => _reorderMode = !_reorderMode),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'custom_server',
        onPressed: () {
          context.push('/servers/scan');
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
                    onPreferences: () => context.push('/servers/preferences',
                        extra: {'serverId': servers[i].id}),
                    health: health[servers[i].id],
                    hostsMapped: _hostsMapped(servers[i].baseUrl),
                    onCheckHealth: () => ref
                        .read(serverHealthProvider.notifier)
                        .check(servers[i]),
                  ),
              ],
              onReorder: (oldIndex, newIndex) {
                ref.read(userServerRepoProvider).reorder(oldIndex, newIndex);
                ref.invalidate(userServerRepoProvider);
              },
            )
          : ListView(
              key: ValueKey('server_list_${servers.length}'),
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
                      onPreferences: () => context.push(
                          '/servers/preferences',
                          extra: {'serverId': s.id}),
                      health: health[s.id],
                      hostsMapped: _hostsMapped(s.baseUrl),
                      onCheckHealth: () =>
                          ref.read(serverHealthProvider.notifier).check(s),
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
                  // 按**规范化 baseUrl** 判定，而不是引擎 type：
                  // gelbooruV2 家族有 5 个模板、moebooru 有 2 个，按 type 判会
                  // 让「添加 Gelbooru 后其余镜像站全显示已添加」，点下去还只会
                  // 编辑 Gelbooru 那一个。
                  final normalized = _normUrl(t.baseUrl);
                  final matches = servers
                      .where((s) => _normUrl(s.baseUrl) == normalized)
                      .toList();
                  return _TemplateTile(
                    key: ValueKey('tpl_${t.type.value}'),
                    template: t,
                    added: matches.isNotEmpty,
                    // 主入口永远是「新增」：同引擎的镜像站本来就应该能各自添加
                    onTap: () =>
                        context.push('/servers/editor', extra: {'template': t}),
                    // 次入口只在确实存在同一个 URL 的服务器时出现（精确匹配）
                    onEditExisting: matches.isEmpty
                        ? null
                        : () => _editServer(matches.first),
                  );
                }),
              ],
            ),
    );
  }

  void _editServer(BooruServer server) {
    context.push('/servers/editor', extra: {'serverId': server.id});
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, BooruServer server) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(T.removeServer),
        content: Text('${T.deleteConfirm}${server.name}${T.deleteConfirmEnd}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(T.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(T.delete),
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
    required this.onPreferences,
    required this.health,
    required this.hostsMapped,
    required this.onCheckHealth,
  });

  final bool dragHandle;
  final BooruServer server;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// 站点级偏好入口（§6.4）。放二级菜单第一项：既不挤掉「编辑」，也不必
  /// 让用户为改一个画质先点进编辑页。
  final VoidCallback onPreferences;

  /// 最近一次健康检查结果（null = 还没查过）。
  final ServerHealth? health;

  /// 该站点当前是否走 hosts 映射。
  final bool hostsMapped;

  /// 点健康指示器时重查这一个站点。
  final VoidCallback onCheckHealth;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ServerFavicon(baseUrl: server.baseUrl, type: server.type),
      title: Text(server.name),
      subtitle: Text(server.baseUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hostsMapped)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: T.healthHostsActive,
                child: Icon(Icons.alt_route,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary),
              ),
            ),
          _HealthIndicator(
            health: health,
            onTap: onCheckHealth,
          ),
          if (dragHandle)
            Icon(Icons.drag_handle,
                color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'prefs':
                  onPreferences();
                case 'edit':
                  onEdit();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'prefs',
                child: Row(children: [
                  const Icon(Icons.tune, size: 18),
                  const SizedBox(width: 8),
                  Text(T.serverPreferences),
                ]),
              ),
              PopupMenuItem(value: 'edit', child: Text(T.edit)),
              PopupMenuItem(value: 'delete', child: Text(T.delete)),
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
    this.onEditExisting,
  });

  final BooruSiteTemplate template;
  final bool added;
  final VoidCallback onTap;

  /// 「已添加」时的次入口：打开与模板 baseUrl 完全相同的那一个服务器。
  final VoidCallback? onEditExisting;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: ServerFavicon(baseUrl: template.baseUrl, type: template.type),
      title: Text(template.name),
      subtitle: Text(
        added
            ? '${template.description ?? template.baseUrl} · ${T.addAnotherHint}'
            : (template.description ?? template.baseUrl),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (added && onEditExisting != null)
            TextButton(
              onPressed: onEditExisting,
              child: Text(T.editExisting),
            ),
          Icon(
            added ? Icons.check_circle : Icons.add_circle_outline,
            color: added ? scheme.primary : scheme.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
/// 规范化 baseUrl 用于「是否已添加」的比较：忽略大小写、首尾空白与尾部斜杠。
///
/// 只做规范化比较，不做等价域名推断——不同 URL 就是不同站点。
String _normUrl(String url) {
  var value = url.trim().toLowerCase();
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

/// 站点健康指示器（OPT §5.4）。点它只重查这一个站点。
class _HealthIndicator extends StatelessWidget {
  const _HealthIndicator({required this.health, required this.onTap});

  final ServerHealth? health;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = health?.status ?? ServerHealthStatus.unknown;

    if (current == ServerHealthStatus.checking) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final (Color color, String label) = switch (current) {
      ServerHealthStatus.ok => (Colors.green, T.healthOk),
      ServerHealthStatus.slow => (Colors.orange, T.healthSlow),
      ServerHealthStatus.rejected => (Colors.red, T.healthRejected),
      ServerHealthStatus.error => (Colors.red, T.healthError),
      ServerHealthStatus.unreachable => (Colors.red, T.healthUnreachable),
      _ => (scheme.outline, T.healthUnknown),
    };
    final latency = health?.latencyMs;
    final text = current == ServerHealthStatus.ok ||
            current == ServerHealthStatus.slow
        ? (latency == null ? label : T.healthLatency(latency))
        : label;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(text, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
