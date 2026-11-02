// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';

/// KVS（Kernel Video Sharing）视频站引擎。
///
/// 这一族站点（rule34video.com、以及大量同 CMS 的 tube 站）不是 booru：
/// 没有 DAPI，列表是 HTML，媒体地址藏在详情页的 `flashvars` 里，
/// 而且常常只给 HLS 流（`.m3u8`）而不是 mp4。因此：
/// - 列表页只拿缩略图与标题（标签从 URL slug 反推）；
/// - 真正的播放地址在打开时按需解析（见 resolveMediaUrl）；
/// - 流清单不能当文件下载，由下载层明确拒绝。
class KvsTube extends Booru {
  const KvsTube();

  @override
  BooruType get type => BooruType.kvs;

  @override
  String get id => 'kvs';

  @override
  // UI 显示名：Play 版用中性说法，不出现站点名
  String get name => kPlayBuild ? 'KVS video site' : 'Video (KVS)';

  @override
  // 出厂默认域名来自 site_presets（Play 版为空串：必须由服务器配置提供）
  String get baseUrl => kKvsBaseUrl;

  /// 能力位只声明真正被消费的：视频站没有图集。
  @override
  BooruCapabilities get capabilities => const BooruCapabilities(
        ratingFilter: false,
      );

  @override
  Map<String, String> get defaultHeaders => {
        // 视频站基本都按浏览器 UA 放行，用应用自定义 UA 会被挡成 403。
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml',
      };

  @override
  String? get loginUrl => null;
}
