// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:boorunova/presentation/widgets/common/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class _SettingEntry {
  const _SettingEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}

class _Section {
  const _Section(this.title, this.entries);
  final String title;
  final List<_SettingEntry> entries;
}

/// 单个设置项：自己一块玻璃，而不是铺在页面底色上的一条 ListTile。
///
/// 口径与侧栏的 GlassNavTile 对齐（18 圆角、半透填充、外侧投影），
/// 于是「从侧栏那一格点进设置页」时，列表读起来是同一层玻璃的延续，
/// 而不是换了一种材质。
///
/// blur 传 false 的理由和侧栏一样：设置页背后是纯色页面底，叠一层
/// BackdropFilter 采不到任何纹理，观感不变却要为整页每一项各付一次
/// 模糊合成——玻璃的其余要素（半透填充、描边、顶部高光、投影）都在，
/// 每一项依然是独立的一块玻璃。
class _GlassSettingTile extends StatelessWidget {
  const _GlassSettingTile({required this.entry});

  final _SettingEntry entry;

  /// 与侧栏菜单项相同的圆角与左右内间距口径。
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(18));

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dark = colorScheme.brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      // 投影画在玻璃外侧：玻璃内部那层裁剪会把 decoration 上的阴影切掉，
      // 所以阴影单独挂在这层 DecoratedBox 上（与侧栏菜单项同一手法）。
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.30 : 0.10),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: GlassContainer(
          borderRadius: _radius,
          tint: dark ? Colors.black : Colors.white,
          fillOpacity: dark ? 0.30 : 0.34,
          blur: false,
          child: ClipRRect(
            borderRadius: _radius,
            child: Material(
              type: MaterialType.transparency,
              // InkWell 自己的手势层就是 HitTestBehavior.opaque 的，
              // 整块玻璃都是热区，不存在「只有文字能点」的死角。
              child: InkWell(
                borderRadius: _radius,
                onTap: () => context.push(entry.route),
                child: Padding(
                  // 上下各 12 + 两行文字（约 38）= 62dp，
                  // 稳稳高于 Material 的 48dp 最小点按尺寸。
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    children: [
                      Icon(entry.icon, size: 22, color: colorScheme.primary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              entry.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 语言切换后整树重建，这里每次 build 重新取文案
    final sections = [
      _Section(T.sectionGeneral, [
        _SettingEntry(icon: Icons.palette_outlined, title: T.appearance, subtitle: T.appearanceSub, route: '/settings/appearance'),
        _SettingEntry(icon: Icons.language_outlined, title: T.language, subtitle: T.languageSub, route: '/settings/language'),
      ]),
      _Section(T.sectionBrowsing, [
        _SettingEntry(icon: Icons.image_outlined, title: T.viewerEntry, subtitle: T.viewerEntrySub, route: '/settings/viewer'),
        _SettingEntry(icon: Icons.gesture_outlined, title: T.gestures, subtitle: T.gesturesSub, route: '/settings/gestures'),
        _SettingEntry(icon: Icons.search_outlined, title: T.searchEntry, subtitle: T.searchEntrySub, route: '/settings/search'),
        _SettingEntry(icon: Icons.history_outlined, title: T.searchHistoryEntry, subtitle: T.searchHistoryEntrySub, route: '/search-history'),
      ]),
      _Section(T.sectionData, [
        _SettingEntry(icon: Icons.download_outlined, title: T.downloadEntry, subtitle: T.downloadEntrySub, route: '/settings/download'),
        _SettingEntry(icon: Icons.storage_outlined, title: T.dataAndStorage, subtitle: T.dataAndStorageSub, route: '/settings/data'),
        _SettingEntry(icon: Icons.backup_outlined, title: T.backup, subtitle: T.backupSub, route: '/settings/backup'),
      ]),
      _Section(T.sectionServer, [
        _SettingEntry(icon: Icons.dns_outlined, title: T.serverManage, subtitle: T.serverManageSub, route: '/servers'),
        _SettingEntry(icon: Icons.block_outlined, title: T.blacklist, subtitle: T.blacklistSub, route: '/blacklist'),
        _SettingEntry(icon: Icons.dns, title: T.hosts, subtitle: T.hostsEntrySub, route: '/settings/hosts'),
      ]),
      _Section(T.sectionOther, [
        _SettingEntry(icon: Icons.shield_outlined, title: T.privacyTitle, subtitle: T.privacyEntrySub, route: '/settings/privacy'),
        _SettingEntry(icon: Icons.info_outline, title: T.about, subtitle: T.aboutSub, route: '/settings/about'),
      ]),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(T.settings)),
      body: ListView(
        // 左右留白由每一项自带的 10dp 提供，与侧栏菜单的贴边距离一致。
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
        children: [
          for (final section in sections) ...[
            SectionHeader(title: section.title),
            for (final entry in section.entries)
              _GlassSettingTile(entry: entry),
            // 组间留白大于组内（组内是每格自带的 3dp）：独立玻璃块之间
            // 不再画分割线，否则视觉上又会被串回一张长列表。
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
