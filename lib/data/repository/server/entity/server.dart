// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/data/repository/server/credential_store.dart';
import 'package:boorunova/data/repository/server/entity/server_preferences.dart';
import 'package:uuid/uuid.dart';

class BooruServer {
  const BooruServer({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.type,
    this.apiKey,
    this.login,
    required this.createdAt,
    this.preferences = const ServerPreferences(),
  });

  factory BooruServer.fromJson(Map<String, dynamic> json) => BooruServer(
        id: json['id'] as String,
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String,
        type: BooruType.fromValue(json['type'] as String),
        apiKey: json['apiKey'] as String?,
        login: json['login'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        // 缺键 = 老记录，视作「全部跟随全局」
        preferences: json['preferences'] is Map
            ? ServerPreferences.fromJson(
                Map<String, dynamic>.from(json['preferences'] as Map))
            : const ServerPreferences(),
      );

  final String id;
  final String name;
  final String baseUrl;
  final BooruType type;
  final String? apiKey;
  final String? login;
  final DateTime createdAt;

  /// 站点级偏好（评级 / 画质 / 下载子目录）。不含凭据，可随备份导出。
  final ServerPreferences preferences;

  BooruServer copyWith({
    String? id,
    String? name,
    String? baseUrl,
    BooruType? type,
    String? apiKey,
    String? login,
    DateTime? createdAt,
    ServerPreferences? preferences,
  }) {
    return BooruServer(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      type: type ?? this.type,
      apiKey: apiKey ?? this.apiKey,
      login: login ?? this.login,
      createdAt: createdAt ?? this.createdAt,
      preferences: preferences ?? this.preferences,
    );
  }

  /// 用服务器编辑页表单的值覆盖，**保留 id / createdAt / 站点偏好**。
  ///
  /// 存在的理由：编辑页此前是 `BooruServer.create(...)` 再 `copyWith(id:)`，
  /// 于是每编辑一次就会把不在表单里的字段（站点偏好、创建时间）重置成默认值
  /// ——用户改个地址，站点偏好就没了。凭据是可空入参（null = 用户清空了它），
  /// 所以这里不能用 `copyWith`（它的 null 表示「不改」）。
  BooruServer withFormValues({
    required String name,
    required String baseUrl,
    required BooruType type,
    String? apiKey,
    String? login,
  }) =>
      BooruServer(
        id: id,
        name: name,
        baseUrl: baseUrl,
        type: type,
        apiKey: apiKey,
        login: login,
        createdAt: createdAt,
        preferences: preferences,
      );

  /// 去掉凭据的副本。
  ///
  /// **落盘前必须过一遍它**：凭据改存平台安全存储（Android Keystore），
  /// Hive 里再留明文等于加固白做。见 `UserServerRepo.save()`。
  BooruServer withoutCredentials() => BooruServer(
        id: id,
        name: name,
        baseUrl: baseUrl,
        type: type,
        createdAt: createdAt,
        preferences: preferences,
      );

  /// 用给定凭据覆盖（null 也覆盖 —— 用户确实清空了它）。
  BooruServer withCredentials(ServerCredentials credentials) => BooruServer(
        id: id,
        name: name,
        baseUrl: baseUrl,
        type: type,
        login: credentials.login,
        apiKey: credentials.apiKey,
        createdAt: createdAt,
        preferences: preferences,
      );

  /// JSON 序列化（**含凭据**）。直接拿它落盘会把 API Key 写成明文，
  /// 落盘请用 `withoutCredentials().toJson()`。
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'type': type.value,
        'apiKey': apiKey,
        'login': login,
        'createdAt': createdAt.toIso8601String(),
        if (preferences.isNotEmpty) 'preferences': preferences.toJson(),
      };

  /// 落盘用：**连凭据的键都不出现**（而不是写成 null）。
  ///
  /// 与 [toJson] 分开是为了让「这条记录到底会不会带出机密」在类型层面就看清：
  /// 只要走这个出口，凭据不可能随记录进 Hive——而不是依赖调用方记得先
  /// `withoutCredentials()`。
  Map<String, dynamic> toStoredJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'type': type.value,
        'createdAt': createdAt.toIso8601String(),
        // 偏好不是机密，随记录/备份一起走；凭据依然只走安全存储
        if (preferences.isNotEmpty) 'preferences': preferences.toJson(),
      };

  /// 备份导出用：剔除 apiKey / login，避免凭据随 JSON 备份文件明文外泄。
  /// 导入侧也不从备份恢复凭据，需在应用内重新填写。
  Map<String, dynamic> toBackupJson() => toStoredJson();

  /// 规范化服务器基址：去掉末尾多余的斜杠，保留一个干净的可拼接 URL。
  static String _normalizeBaseUrl(String url) {
    var s = url.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  static BooruServer create({
    required String name,
    required String baseUrl,
    required BooruType type,
    String? apiKey,
    String? login,
  }) {
    return BooruServer(
      id: const Uuid().v4(),
      name: name,
      // 去掉尾部斜杠，避免拼接 postUrl/API 路径时出现双斜杠（https://x//posts/1）
      baseUrl: _normalizeBaseUrl(baseUrl),
      type: type,
      apiKey: apiKey,
      login: login,
      createdAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BooruServer && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
