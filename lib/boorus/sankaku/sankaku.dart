// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';

class Sankaku extends Booru {
  const Sankaku();

  @override
  BooruType get type => BooruType.sankaku;

  @override
  String get id => 'sankaku';

  @override
  // UI 显示名：Play 版用中性说法，不出现站点名
  String get name => kPlayBuild ? 'Chan-style tag API' : 'Sankaku Complex';

  @override
  // 出厂默认域名来自 site_presets（Play 版为空串：必须由服务器配置提供）
  String get baseUrl => kSankakuBaseUrl;

  @override
  BooruCapabilities get capabilities => const BooruCapabilities();

  @override
  Map<String, String> get defaultHeaders => {
        // chan.sankakucomplex.com 由 Cloudflare 保护，站点按浏览器 UA 放行；
        // 此前用应用自有 UA（BooruNova/1.0）直连，几乎必然被 CF 挡成 403
        // （搜索/翻页整体失效）。对齐 KvsTube 的既有做法（kvs.dart:34-36）
        // 改用浏览器 UA。Accept 仍保持 JSON：仓库请求的是 /post/index.json。
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
        'Accept': 'application/json',
      };

  @override
  String? get loginUrl => '$baseUrl/user/login';
}
