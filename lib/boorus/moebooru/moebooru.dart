// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';

class Moebooru extends Booru {
  const Moebooru();

  @override
  BooruType get type => BooruType.moebooru;

  @override
  String get id => 'moebooru';

  @override
  // UI 显示名：Play 版用中性说法，不出现站点名
  String get name => kPlayBuild ? 'Moebooru API' : 'Moebooru';

  @override
  // 出厂默认域名来自 site_presets（Play 版为空串：必须由服务器配置提供）
  String get baseUrl => kMoebooruBaseUrl;

  @override
  BooruCapabilities get capabilities => const BooruCapabilities(
        pools: true,
        auth: true,
      );

  @override
  Map<String, String> get defaultHeaders => {
        'User-Agent': 'BooruNova/1.0',
        'Accept': 'application/json',
      };

  @override
  String? get loginUrl => '$baseUrl/user/login';
}
