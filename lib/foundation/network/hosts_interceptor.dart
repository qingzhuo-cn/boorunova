// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/data/repository/hosts/user_hosts_repo.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';

/// 为网络连接提供用户配置的域名到 IP 映射。
///
/// 映射只用于建立 TCP 连接；请求 URL 始终保留原始域名，确保 query、Host、
/// HTTPS SNI 与证书校验均保持正确。
class HostsInterceptor {
  HostsInterceptor({required this.enabled, required UserHostsRepo repo})
      : _repo = repo;

  final UserHostsRepo _repo;
  bool enabled;

  bool get _isActive {
    if (enabled) return true;
    try {
      final raw = HiveSetup.settingsBox.get('app_settings');
      if (raw is Map) {
        return raw['hostsEnabled'] == true;
      }
    } catch (_) {}
    return false;
  }

  String? resolve(String host) {
    if (!_isActive) return null;
    return _repo.match(host)?.ip;
  }
}
