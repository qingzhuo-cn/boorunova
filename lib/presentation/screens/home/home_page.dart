import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/registry.dart';
import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/screens/home/home_content.dart';
import 'package:boorunova/presentation/screens/server/booru_site_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  BooruServer? _activeServer;
  final Map<String, BooruRepository> _repoCache = {};
  static final Set<String> _failedFavicons = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDefaultServer();
    });
  }

  void _onServersChanged(List<BooruServer> servers) {
    if (_activeServer != null) {
      // active 服务器被编辑（URL/凭据变化）→ 失效缓存并重建 repo 刷新
      final updated = servers.where((s) => s.id == _activeServer!.id).firstOrNull;
      if (updated == null) {
        // active 服务器被删除：清空缓存并切到第一个可用站点
        _repoCache.remove(_activeServer!.id);
        _activeServer = null;
      } else if (_configChanged(updated)) {
        _repoCache.remove(updated.id);
        _activeServer = null;
        _selectServer(updated);
        return;
      } else {
        return;
      }
    }
    if (servers.isEmpty) return;
    final settings = ref.read(settingsProvider);
    BooruServer? target;
    if (settings.defaultServerId != null) {
      target = servers.where((s) => s.id == settings.defaultServerId).firstOrNull;
    }
    if (ref.read(booruPageStateProvider.notifier).currentQuery.isEmpty) {
      _selectServer(target ?? servers.first);
    }
  }

  bool _configChanged(BooruServer updated) {
    final cur = _activeServer;
    if (cur == null) return true;
    return cur.baseUrl != updated.baseUrl ||
        cur.type != updated.type ||
        cur.login != updated.login ||
        cur.apiKey != updated.apiKey;
  }

  void _initDefaultServer() {
    final servers = ref.read(userServerRepoProvider).getAll();
    if (servers.isEmpty) return;

    final settings = ref.read(settingsProvider);
    BooruServer? target;
    if (settings.defaultServerId != null) {
      target = servers.where((s) => s.id == settings.defaultServerId).firstOrNull;
    }
    if (ref.read(booruPageStateProvider.notifier).currentQuery.isEmpty) {
      _selectServer(target ?? servers.first);
    }
  }

  void _selectServer(BooruServer server) {
    if (server.id == _activeServer?.id) return;
    setState(() => _activeServer = server);
    final registry = ref.read(booruRegistryProvider);
    try {
      final repo = _repoCache[server.id] ??
          registry.createRepository(
            server.type,
            baseUrl: server.baseUrl,
            serverId: server.id,
            login: server.login,
            apiKey: server.apiKey,
          );
      _repoCache[server.id] = repo;
      final notifier = ref.read(booruPageStateProvider.notifier);
      // 有搜索词时也重新加载（保留旧内容），避免显示旧服务器帖子
      notifier.switchServer(repo);
    } catch (e) {
      final template = BooruSiteTemplate.findByType(server.type);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            template != null
                ? '${template.name} 引擎不可用，请更换服务器或修改引擎类型'
                : '引擎不可用：${server.type.value}',
          ),
        ),
      );
    }
  }

  Widget _buildFavicon(String baseUrl) {
    return _serverFavicon(baseUrl, _activeServer!.type, size: 24);
  }

  Widget _serverIcon(BooruType type, {double size = 16}) {
    final template = BooruSiteTemplate.findByType(type);
    return CircleAvatar(
      radius: size / 2 + 2,
      backgroundColor: (template?.color ?? Colors.grey).withOpacity(0.2),
      child: Icon(template?.icon ?? Icons.dns_outlined,
          color: template?.color ?? Colors.grey, size: size),
    );
  }

  bool _hasCapability(bool Function(BooruCapabilities) check) {
    if (_activeServer == null) return false;
    try {
      final engine = ref.read(booruRegistryProvider).get(_activeServer!.type);
      return engine != null && check(engine.booru.capabilities);
    } catch (_) {
      return false;
    }
  }

  Widget _serverFavicon(String baseUrl, BooruType type, {double size = 16}) {
    try {
      final clean = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final faviconUrl = '$clean/favicon.ico';
      if (_failedFavicons.contains(faviconUrl)) {
        return _serverIcon(type, size: size);
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          faviconUrl,
          width: size,
          height: size,
          errorBuilder: (_, __, ___) {
            _failedFavicons.add(faviconUrl);
            return _serverIcon(type, size: size);
          },
        ),
      );
    } catch (_) {
      return _serverIcon(type, size: size);
    }
  }

  Widget _faviconWidget() {
    if (_activeServer == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Builder(
        builder: (ctx) => GestureDetector(
          onLongPress: () {
            final servers = ref.read(userServerRepoProvider).getAll();
            if (servers.length < 2) return;
            final renderBox = ctx.findRenderObject() as RenderBox;
            final offset = renderBox.localToGlobal(Offset.zero);
            final size = renderBox.size;
            final items = servers.map((s) {
              final isActive = s.id == _activeServer?.id;
              return PopupMenuItem<String>(
                value: s.id,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _serverFavicon(s.baseUrl, s.type, size: 18),
                    const SizedBox(width: 8),
                    Text(s.name, style: const TextStyle(fontSize: 13)),
                    if (isActive) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check, color: Colors.green, size: 14),
                    ],
                  ],
                ),
              );
            }).toList();
            final screenSize = MediaQuery.of(ctx).size;
            showMenu<String>(
              context: ctx,
              position: RelativeRect.fromRect(
                Rect.fromLTWH(offset.dx, offset.dy + size.height, 0, 0),
                Rect.fromLTWH(0, 0, screenSize.width, screenSize.height),
              ),
              items: items,
            ).then((id) {
              if (id != null) {
                final server = servers.firstWhere((s) => s.id == id);
                _selectServer(server);
              }
            });
          },
          child: _buildFavicon(_activeServer!.baseUrl),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(userServerRepoProvider).getAll();
    ref.listen<UserServerRepo>(userServerRepoProvider, (_, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onServersChanged(next.getAll());
      });
    });

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.image_search, size: 40),
                  const SizedBox(height: 8),
                  Text('BooruNova', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.favorite_outline),
              title: const Text(T.favorites),
              onTap: () { Navigator.pop(context); context.push('/favorites'); },
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text(T.downloads),
              onTap: () { Navigator.pop(context); context.push('/downloads'); },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text(T.history),
              onTap: () { Navigator.pop(context); context.push('/history'); },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: const Text(T.servers),
              onTap: () { Navigator.pop(context); context.push('/servers'); },
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('黑名单'),
              onTap: () { Navigator.pop(context); context.push('/blacklist'); },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text(T.settings),
              onTap: () { Navigator.pop(context); context.push('/settings'); },
            ),
          ],
        ),
      ),
      drawerEdgeDragWidth: 40,
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Builder(
                    builder: (ctx) => GestureDetector(
                      onLongPress: () {
                        Navigator.pop(ctx);
                        // trigger server switch popup
                      },
                      child: Row(
                        children: [
                          _buildFavicon(_activeServer?.baseUrl ?? ''),
                          const SizedBox(width: 8),
                          Text(
                            _activeServer?.name ?? 'BooruNova',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.explore_outlined),
              title: const Text('探索'),
              onTap: () { Navigator.pop(context); },
            ),
            const Divider(),
            if (_activeServer != null && _hasCapability((c) => c.forums))
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: const Text('论坛'),
                onTap: () { Navigator.pop(context); context.push('/forum'); },
              ),
            if (_activeServer != null && _hasCapability((c) => c.artistPages))
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('艺术家'),
                onTap: () { Navigator.pop(context); context.push('/artists'); },
              ),
          ],
        ),
      ),
      appBar: AppBar(
        toolbarHeight: 1,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Builder(
        builder: (ctx) => GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity! > 100) {
              Scaffold.of(ctx).openDrawer();
            } else if (details.primaryVelocity! < -100) {
              Scaffold.of(ctx).openEndDrawer();
            }
          },
          child: servers.isEmpty
              ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_search, size: 64,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(T.noPostsYet,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                  const SizedBox(height: 8),
                  Text(T.addBooruServer,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3))),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.push('/servers'),
                    icon: const Icon(Icons.add),
                    label: const Text(T.addServer),
                  ),
                ],
              ),
            )
          : HomeContent(favicon: _faviconWidget()),
        ),
      ),
      );
  }
}
