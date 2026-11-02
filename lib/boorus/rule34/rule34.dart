// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';

class Rule34 extends Booru {
  const Rule34();

  @override
  BooruType get type => BooruType.rule34;

  @override
  String get id => 'rule34';

  @override
  // UI 显示名：Play 版用中性说法，不出现站点名
  String get name => kPlayBuild ? 'DAPI JSON board' : 'Rule34';

  @override
  // 出厂默认域名来自 site_presets（Play 版为空串：必须由服务器配置提供）
  String get baseUrl => kRule34BaseUrl;

  @override
  BooruCapabilities get capabilities => const BooruCapabilities(
        auth: true,
      );

  @override
  Map<String, String> get defaultHeaders => {
        'User-Agent': 'BooruNova/1.0',
        'Accept': 'application/json',
      };

  @override
  String? get loginUrl => null;
}
