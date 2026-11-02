// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/screens/blacklist/blacklist_page.dart';
import 'package:boorunova/presentation/screens/downloads/downloads_page.dart';
import 'package:boorunova/presentation/screens/explore/explore_page.dart';
import 'package:boorunova/presentation/screens/favorites/favorites_page.dart';
import 'package:boorunova/presentation/screens/history/history_page.dart';
import 'package:boorunova/presentation/screens/history/search_history_page.dart';
import 'package:boorunova/presentation/screens/home/home_page.dart';
import 'package:boorunova/presentation/screens/onboarding/onboarding_page.dart';
import 'package:boorunova/presentation/screens/pools/pool_detail_page.dart';
import 'package:boorunova/presentation/screens/pools/pools_page.dart';
import 'package:boorunova/presentation/screens/post/post_detail_page.dart';
import 'package:boorunova/presentation/screens/post/post_viewer.dart';
import 'package:boorunova/presentation/screens/search/search_page.dart';
import 'package:boorunova/presentation/screens/server/booru_site_template.dart';
import 'package:boorunova/presentation/screens/server/server_editor_page.dart';
import 'package:boorunova/presentation/screens/server/server_page.dart';
import 'package:boorunova/presentation/screens/server/server_preferences_page.dart';
import 'package:boorunova/presentation/screens/server/server_probe_page.dart';
import 'package:boorunova/presentation/screens/settings/about_settings_page.dart';
import 'package:boorunova/presentation/screens/settings/appearance_page.dart';
import 'package:boorunova/presentation/screens/settings/content_source_page.dart';
import 'package:boorunova/presentation/screens/settings/data_backup_page.dart';
import 'package:boorunova/presentation/screens/settings/data_storage_page.dart';
import 'package:boorunova/presentation/screens/settings/download_settings_page.dart';
import 'package:boorunova/presentation/screens/settings/gestures_page.dart';
import 'package:boorunova/presentation/screens/settings/hosts_page.dart';
import 'package:boorunova/presentation/screens/settings/language_settings_page.dart';
import 'package:boorunova/presentation/screens/settings/privacy_page.dart';
import 'package:boorunova/presentation/screens/settings/search_settings_page.dart';
import 'package:boorunova/presentation/screens/settings/settings_page.dart';
import 'package:boorunova/presentation/screens/settings/viewer_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Page<T> _slidePage<T>(Widget child, {bool reduceAnimations = false}) {
  final duration = reduceAnimations ? Duration.zero : const Duration(milliseconds: 300);
  return CustomTransitionPage<T>(
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        )),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  // 「减少动画」此前只有参数定义、33 个调用点无一传值，等于设置项失效。
  // 这里从 settings 读取并注入，转场时长真正受设置控制。
  // 用 ref.read 而非 watch：切换该选项不应重建整个 GoRouter（那会丢掉
  // 导航栈），只需要后续新建的页面读到最新值。
  Page<T> page<T>(Widget child) => _slidePage(
        child,
        reduceAnimations: ref.read(settingsProvider).reduceAnimations,
      );

  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    // 首次启动（未完成引导 且 尚无任何站点）强制进入引导页。
    // 双条件避免老用户升级时（有站点、无 onboardingComplete 标记）被强制重走。
    redirect: (context, state) {
      final settings = ref.read(settingsProvider);
      final hasServers = ref.read(userServerRepoProvider).count > 0;
      final needsOnboarding =
          !settings.onboardingComplete && !hasServers;
      final onOnboarding = state.uri.path == '/onboarding';
      if (needsOnboarding && !onOnboarding) return '/onboarding';
      if (!needsOnboarding && onOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (context, state) => page(const HomePage()),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => page(const OnboardingPage()),
      ),
      GoRoute(
        path: '/favorites',
        name: 'favorites',
        pageBuilder: (context, state) => page(const FavoritesPage()),
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        pageBuilder: (context, state) => page(const HistoryPage()),
      ),
      GoRoute(
        path: '/downloads',
        name: 'downloads',
        pageBuilder: (context, state) => page(const DownloadsPage()),
      ),
      GoRoute(
        path: '/search-history',
        name: 'search-history',
        pageBuilder: (context, state) => page(const SearchHistoryPage()),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        pageBuilder: (context, state) {
          final extra = state.extra;
          final initialQuery =
              extra is Map ? (extra['initialQuery'] as String? ?? '') : '';
          return page(SearchPage(initialQuery: initialQuery));
        },
      ),
      GoRoute(
        path: '/explore',
        name: 'explore',
        pageBuilder: (context, state) => page(const ExplorePage()),
      ),
      GoRoute(
        path: '/pools',
        name: 'pools',
        pageBuilder: (context, state) => page(const PoolsPage()),
      ),
      GoRoute(
        path: '/pools/:id',
        name: 'pool-detail',
        pageBuilder: (context, state) {
          final extra = state.extra;
          final name = extra is Map ? (extra['name'] as String? ?? '') : '';
          return page(PoolDetailPage(
            poolId: state.pathParameters['id']!,
            poolName: name,
          ));
        },
      ),
      GoRoute(
        path: '/blacklist',
        name: 'blacklist',
        pageBuilder: (context, state) => page(const BlacklistPage()),
      ),

      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) => page(const SettingsPage()),
        routes: [
          GoRoute(
            path: 'hosts',
            name: 'settings-hosts',
            pageBuilder: (context, state) => page(const HostsPage()),
          ),
          GoRoute(
            path: 'viewer',
            name: 'settings-viewer',
            pageBuilder: (context, state) => page(const ViewerSettingsPage()),
          ),
          GoRoute(
            path: 'appearance',
            name: 'settings-appearance',
            pageBuilder: (context, state) => page(const AppearanceSettingsPage()),
          ),
          GoRoute(
            path: 'language',
            name: 'settings-language',
            pageBuilder: (context, state) => page(const LanguageSettingsPage()),
          ),
          GoRoute(
            path: 'gestures',
            name: 'settings-gestures',
            pageBuilder: (context, state) => page(const GesturesPage()),
          ),
          GoRoute(
            path: 'search',
            name: 'settings-search',
            pageBuilder: (context, state) => page(const SearchSettingsPage()),
          ),
          GoRoute(
            path: 'download',
            name: 'settings-download',
            pageBuilder: (context, state) => page(const DownloadSettingsPage()),
          ),
          GoRoute(
            path: 'data',
            name: 'settings-data',
            pageBuilder: (context, state) => page(const DataStoragePage()),
          ),
          GoRoute(
            path: 'backup',
            name: 'settings-backup',
            pageBuilder: (context, state) => page(const DataBackupPage()),
          ),
          GoRoute(
            path: 'privacy',
            name: 'settings-privacy',
            pageBuilder: (context, state) => page(const PrivacyPage()),
          ),
          GoRoute(
            path: 'content-source',
            name: 'settings-content-source',
            pageBuilder: (context, state) => page(const ContentSourcePage()),
          ),
          GoRoute(
            path: 'about',
            name: 'settings-about',
            pageBuilder: (context, state) => page(const AboutSettingsPage()),
          ),
        ],
      ),
      GoRoute(
        path: '/servers',
        name: 'servers',
        pageBuilder: (context, state) => page(const ServerPage()),
        routes: [
          GoRoute(
            path: 'preferences',
            name: 'servers-preferences',
            pageBuilder: (context, state) {
              final extra = state.extra;
              final serverId = extra is Map
                  ? extra['serverId'] as String?
                  : extra is String
                      ? extra
                      : null;
              if (serverId == null || serverId.isEmpty) {
                return page(const _InvalidRoutePage());
              }
              return page(ServerPreferencesPage(serverId: serverId));
            },
          ),
          GoRoute(
            path: 'editor',
            name: 'servers-editor',
            pageBuilder: (context, state) {
              final extra = state.extra;
              if (extra is Map) {
                return page(ServerEditorPage(
                  serverId: extra['serverId'] as String?,
                  template: extra['template'] as BooruSiteTemplate?,
                  initialUrl: extra['initialUrl'] as String?,
                  initialName: extra['initialName'] as String?,
                  initialType: extra['initialType'] as BooruType?,
                ));
              }
              return page(const _InvalidRoutePage());
            },
          ),
          GoRoute(
            path: 'scan',
            name: 'servers-scan',
            pageBuilder: (context, state) {
              final extra = state.extra;
              final initialUrl =
                  extra is Map ? (extra['initialUrl'] as String? ?? '') : '';
              return page(ServerScanPage(initialUrl: initialUrl));
            },
          ),
        ],
      ),
      GoRoute(
        path: '/post/:id',
        name: 'post',
        pageBuilder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            final posts = extra['posts'];
            final initialIndex = extra['initialIndex'];
            if (posts is List<PostSummary> && initialIndex is int && initialIndex >= 0 && initialIndex < posts.length) {
              return page(PostViewer(posts: posts, initialIndex: initialIndex));
            }
          }
          return page(const _InvalidRoutePage());
        },
        routes: [
          GoRoute(
            path: 'detail',
            name: 'post-detail',
            pageBuilder: (context, state) {
              final extra = state.extra;
              // 两种形态：直接给 PostSummary（首页头图等入口），或给
              // {'post': ..., 'fromViewer': true}（从全屏查看器点进来，
              // 详情页据此把「打开完整查看器」实现为 pop 回原查看器）。
              if (extra is PostSummary) {
                return page(PostDetailPage(post: extra));
              }
              if (extra is Map) {
                final post = extra['post'];
                if (post is PostSummary) {
                  return page(PostDetailPage(
                    post: post,
                    fromViewer: extra['fromViewer'] == true,
                  ));
                }
              }
              return page(const _InvalidRoutePage());
            },
          ),
        ],
      ),
    ],
  );
});

class _InvalidRoutePage extends StatelessWidget {
  const _InvalidRoutePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(T.invalidLink, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(T.invalidLinkHint,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/'),
              child: Text(T.backToHome),
            ),
          ],
        ),
      ),
    );
  }
}
