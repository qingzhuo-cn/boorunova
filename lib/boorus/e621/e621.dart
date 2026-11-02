// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';

class E621 extends Booru {
  const E621();

  @override
  BooruType get type => BooruType.e621;

  @override
  String get id => 'e621';

  @override
  // UI 显示名：Play 版用中性说法，不出现站点名
  String get name => kPlayBuild ? 'Furry booru API' : 'e621';

  @override
  // 出厂默认域名来自 site_presets（Play 版为空串：必须由服务器配置提供）
  String get baseUrl => kE621BaseUrl;

  @override
  BooruCapabilities get capabilities => const BooruCapabilities(
        pools: true,
        auth: true,
      );

  @override
  Map<String, String> get defaultHeaders => {
        'User-Agent': 'BooruNova/1.0 (by boorunova on e621)',
        'Accept': 'application/json',
      };

  @override
  String? get loginUrl => null;
}
