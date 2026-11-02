// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';

/// Shimmie2 / paheal 系图站（rule34.paheal.net 等）。
///
/// 与 gelbooru DAPI 不同族：接口是图库 HTML 页（老分支）或新版 JSON 接口，
/// 由 [Shimmie2Repository] 两条路都试。
class Shimmie2 extends Booru {
  const Shimmie2();

  @override
  BooruType get type => BooruType.shimmie2;

  @override
  String get id => 'shimmie2';

  @override
  // UI 显示名：Play 版用中性说法，不出现站点名
  String get name => kPlayBuild ? 'Shimmie2 gallery' : 'Shimmie2';

  @override
  // 出厂默认域名来自 site_presets（Play 版为空串：必须由服务器配置提供）
  String get baseUrl => kShimmie2BaseUrl;

  @override
  BooruCapabilities get capabilities => const BooruCapabilities(
        ratingFilter: false,
      );

  @override
  Map<String, String> get defaultHeaders => {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
        'Accept': 'text/html,application/json',
      };

  @override
  String? get loginUrl => null;
}
