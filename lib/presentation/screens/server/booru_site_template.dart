// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';
import 'package:flutter/material.dart';

/// 站点模板：预置数据（名称 / 域名 / 描述）来自 [kSitePresets]，
/// 这里只负责补上表示层的东西（图标与配色）。
///
/// 这样做的意义是「出厂预置只有一处」（site_presets.dart）：Play 版把那份
/// 数据编译期置空之后，模板区整体消失，而且站点域名不会留在构建产物里。
/// 此前模板直接写在这个文件里，与引擎默认域名、探测捷径表三处各写一份，
/// 漏改任一处都等于「没删干净」。
class BooruSiteTemplate {
  const BooruSiteTemplate({
    required this.name,
    required this.type,
    required this.baseUrl,
    required this.icon,
    required this.color,
    this.description,
  });

  final String name;
  final BooruType type;
  final String baseUrl;
  final IconData icon;
  final MaterialColor color;
  final String? description;

  /// 出厂模板。Play 版为空列表。
  static final List<BooruSiteTemplate> all = _build(kSitePresets);

  /// 尚未实现引擎的站点模板（详见 [kPlannedSitePresets] 的注释）。
  static final List<BooruSiteTemplate> planned = _build(kPlannedSitePresets);

  static List<BooruSiteTemplate> _build(List<SitePreset> presets) => [
        for (final preset in presets)
          BooruSiteTemplate(
            name: preset.name,
            type: preset.type,
            baseUrl: preset.baseUrl,
            icon: _iconOf(preset.style),
            color: _colorOf(preset.style),
            description: preset.description,
          ),
      ];

  static IconData _iconOf(PresetStyle style) => switch (style) {
        PresetStyle.photoLibrary => Icons.photo_library,
        PresetStyle.image => Icons.image,
        PresetStyle.shield => Icons.shield,
        PresetStyle.autoAwesome => Icons.auto_awesome,
        PresetStyle.pets => Icons.pets,
        PresetStyle.lensBlur => Icons.lens_blur,
        PresetStyle.filterVintage => Icons.filter_vintage,
        PresetStyle.warningAmber => Icons.warning_amber,
        PresetStyle.gridView => Icons.grid_view,
        PresetStyle.photoCameraBack => Icons.photo_camera_back,
        PresetStyle.collectionsBookmark => Icons.collections_bookmark,
        PresetStyle.link => Icons.link,
        PresetStyle.photoLibraryOutlined => Icons.photo_library_outlined,
        PresetStyle.playCircleOutline => Icons.play_circle_outline,
        PresetStyle.palette => Icons.palette,
        PresetStyle.collections => Icons.collections,
      };

  static MaterialColor _colorOf(PresetStyle style) => switch (style) {
        PresetStyle.photoLibrary => Colors.blue,
        PresetStyle.image => Colors.orange,
        PresetStyle.shield => Colors.green,
        PresetStyle.autoAwesome => Colors.pink,
        PresetStyle.pets => Colors.brown,
        PresetStyle.lensBlur => Colors.red,
        PresetStyle.filterVintage => Colors.teal,
        PresetStyle.warningAmber => Colors.deepOrange,
        PresetStyle.gridView => Colors.pink,
        PresetStyle.photoCameraBack => Colors.deepPurple,
        PresetStyle.collectionsBookmark => Colors.brown,
        PresetStyle.link => Colors.amber,
        PresetStyle.photoLibraryOutlined => Colors.red,
        PresetStyle.playCircleOutline => Colors.red,
        PresetStyle.palette => Colors.indigo,
        PresetStyle.collections => Colors.cyan,
      };

  static BooruSiteTemplate? findByType(BooruType type) {
    for (final template in all) {
      if (template.type == type) return template;
    }
    return null;
  }
}
