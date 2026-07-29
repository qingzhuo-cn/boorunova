import 'package:boorunova/presentation/l10n/app_strings.dart';
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

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    const sections = [
      _Section('通用', [
        _SettingEntry(icon: Icons.palette_outlined, title: '外观', subtitle: '主题、颜色', route: '/settings/appearance'),
        _SettingEntry(icon: Icons.language_outlined, title: '语言', subtitle: '界面语言', route: '/settings/language'),
      ]),
      _Section('浏览', [
        _SettingEntry(icon: Icons.image_outlined, title: '图片查看器', subtitle: '滑动、幻灯片、视频', route: '/settings/viewer'),
        _SettingEntry(icon: Icons.gesture_outlined, title: '手势', subtitle: '滑动、点击、长按动作', route: '/settings/gestures'),
        _SettingEntry(icon: Icons.search_outlined, title: '搜索', subtitle: '搜索选项、过滤', route: '/settings/search'),
        _SettingEntry(icon: Icons.history_outlined, title: '搜索历史', subtitle: '查看管理搜索记录', route: '/search-history'),
      ]),
      _Section('数据', [
        _SettingEntry(icon: Icons.download_outlined, title: '下载', subtitle: '下载路径、质量', route: '/settings/download'),
        _SettingEntry(icon: Icons.storage_outlined, title: '数据与存储', subtitle: '缓存管理、存储空间', route: '/settings/data'),
        _SettingEntry(icon: Icons.backup_outlined, title: '备份恢复', subtitle: '导出/导入数据', route: '/settings/backup'),
      ]),
      _Section('服务器', [
        _SettingEntry(icon: Icons.dns_outlined, title: '服务器管理', subtitle: '添加、编辑、排序', route: '/servers'),
        _SettingEntry(icon: Icons.tune_outlined, title: 'Booru 配置', subtitle: '每服务器独立设置', route: '/settings/booru'),
        _SettingEntry(icon: Icons.block_outlined, title: '黑名单', subtitle: '屏蔽标签管理', route: '/blacklist'),
        _SettingEntry(icon: Icons.dns, title: 'Hosts', subtitle: '自定义域名映射', route: '/settings/hosts'),
      ]),
      _Section('其他', [
        _SettingEntry(icon: Icons.shield_outlined, title: '隐私', subtitle: '隐私设置', route: '/settings/privacy'),
        _SettingEntry(icon: Icons.info_outline, title: '关于', subtitle: '版本信息、开源许可', route: '/settings/about'),
      ]),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text(T.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final section in sections) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                section.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            for (final entry in section.entries)
              ListTile(
                leading: Icon(entry.icon),
                title: Text(entry.title),
                subtitle: Text(entry.subtitle, style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => context.push(entry.route),
              ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _Section {
  const _Section(this.title, this.entries);
  final String title;
  final List<_SettingEntry> entries;
}
