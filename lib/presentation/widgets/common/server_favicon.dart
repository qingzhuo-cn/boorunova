// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/presentation/screens/server/booru_site_template.dart';
import 'package:flutter/material.dart';

/// 站点图标：优先拉站点自己的 favicon，失败则回落到引擎品牌图标。
///
/// 抽成共享组件的原因：此前首页与服务器页各写一份。首页那版有失败缓存
/// 和品牌图标兜底，服务器页只有一个 `Icons.public` —— 同一个站点在两个
/// 页面显示不同的占位图标，看起来像加载失败。
///
/// 失败集合是进程级静态，但带 5 分钟 TTL：某次请求失败后短时间内不再
/// 重试（避免每次 rebuild 都发一次注定失败的请求），但一次网络抖动不会
/// 让图标在整个会话里永远退回引擎兜底。
class ServerFavicon extends StatelessWidget {
  const ServerFavicon({
    super.key,
    required this.baseUrl,
    required this.type,
    this.size = 24,
  });

  final String baseUrl;
  final BooruType type;
  final double size;

  /// url → 最近一次失败时间。修复前是 Set<String>：命中一次失败就永久
  /// 拉黑，站点短暂抽风（或用户刚恢复网络）后本次运行再也不重试。
  static final Map<String, DateTime> _failedAt = <String, DateTime>{};

  static const Duration _failureTtl = Duration(minutes: 5);

  /// 失败是否仍在 TTL 内。过期即顺手移除，让下一次渲染重新尝试。
  static bool _hasFailed(String url) {
    final at = _failedAt[url];
    if (at == null) return false;
    if (DateTime.now().difference(at) < _failureTtl) return true;
    _failedAt.remove(url);
    return false;
  }

  static String faviconUrlOf(String baseUrl) {
    final clean =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$clean/favicon.ico';
  }

  @override
  Widget build(BuildContext context) {
    final url = faviconUrlOf(baseUrl);
    if (url.isEmpty || _hasFailed(url)) {
      return EngineIcon(type: type, size: size);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          // 记下失败时间；5 分钟内直接走兜底不再请求，之后允许重试
          _failedAt[url] = DateTime.now();
          return EngineIcon(type: type, size: size);
        },
      ),
    );
  }
}

/// 引擎品牌图标：模板色底 + 模板图标。站点 favicon 不可用时的统一兜底。
class EngineIcon extends StatelessWidget {
  const EngineIcon({super.key, required this.type, this.size = 24});

  final BooruType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final template = BooruSiteTemplate.findByType(type);
    final fallback = Theme.of(context).colorScheme.onSurfaceVariant;
    final color = template?.color ?? fallback;
    return CircleAvatar(
      radius: size / 2 + 2,
      backgroundColor: color.withOpacity(0.2),
      child: Icon(template?.icon ?? Icons.dns_outlined,
          color: color, size: size),
    );
  }
}
