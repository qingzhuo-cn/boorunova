// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 一个站点的凭据。
@immutable
class ServerCredentials {
  const ServerCredentials({this.login, this.apiKey});

  /// 登录名 / 用户 ID（Gelbooru 系的 `user_id`、moebooru 的 `login`）。
  final String? login;

  /// API Key / 密码哈希（Danbooru 系）。
  final String? apiKey;

  /// 两项都空 —— 没配凭据，不该往安全存储里写空记录。
  bool get isEmpty =>
      (login == null || login!.isEmpty) && (apiKey == null || apiKey!.isEmpty);

  bool get isNotEmpty => !isEmpty;
}

/// 凭据的存放位置。
///
/// 抽象出来有两个原因：
/// 1. 生产实现走平台安全存储（Android Keystore），测试需要能在内存里跑；
/// 2. **迁移失败必须能被测出来**——旧明文只在确认写入成功之后才允许抹掉，
///    否则用户会静默失去自己的 API Key。
abstract class CredentialStore {
  Future<ServerCredentials?> read(String serverId);

  Future<void> write(String serverId, ServerCredentials credentials);

  Future<void> delete(String serverId);

  /// 当前存了凭据的全部 serverId。
  ///
  /// 用于清理**孤儿凭据**：服务器记录因为 box 损坏被隔离（或保存到一半失败）
  /// 之后，安全存储里那份密文不会自己消失——不清理就是永久残留的机密。
  Future<Set<String>> ids();
}

/// 平台安全存储实现（Android：Keystore 加密的 SharedPreferences）。
class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Key 前缀带命名空间：安全存储是全应用共享的一层，加前缀才不会和
  /// 将来别的机密（令牌、密码）撞名。
  static const String _keyPrefix = 'server_';
  static const String _loginSuffix = '_login';
  static const String _apiKeySuffix = '_api_key';

  static String _loginKey(String serverId) =>
      '$_keyPrefix$serverId$_loginSuffix';
  static String _apiKeyKey(String serverId) =>
      '$_keyPrefix$serverId$_apiKeySuffix';

  @override
  Future<ServerCredentials?> read(String serverId) async {
    final login = await _storage.read(key: _loginKey(serverId));
    final apiKey = await _storage.read(key: _apiKeyKey(serverId));
    if ((login == null || login.isEmpty) &&
        (apiKey == null || apiKey.isEmpty)) {
      return null;
    }
    return ServerCredentials(login: login, apiKey: apiKey);
  }

  @override
  Future<void> write(String serverId, ServerCredentials credentials) async {
    await _storage.write(key: _loginKey(serverId), value: credentials.login);
    await _storage.write(
        key: _apiKeyKey(serverId), value: credentials.apiKey);
  }

  @override
  Future<void> delete(String serverId) async {
    await _storage.delete(key: _loginKey(serverId));
    await _storage.delete(key: _apiKeyKey(serverId));
  }

  @override
  Future<Set<String>> ids() async {
    final all = await _storage.readAll();
    final out = <String>{};
    for (final key in all.keys) {
      for (final suffix in const [_loginSuffix, _apiKeySuffix]) {
        if (key.startsWith(_keyPrefix) && key.endsWith(suffix)) {
          final id = key.substring(
              _keyPrefix.length, key.length - suffix.length);
          if (id.isNotEmpty) out.add(id);
        }
      }
    }
    return out;
  }
}

/// 内存实现：测试与「安全存储不可用」时的降级用。
class InMemoryCredentialStore implements CredentialStore {
  final Map<String, ServerCredentials> entries = {};

  @override
  Future<ServerCredentials?> read(String serverId) async => entries[serverId];

  @override
  Future<void> write(String serverId, ServerCredentials credentials) async {
    entries[serverId] = credentials;
  }

  @override
  Future<void> delete(String serverId) async {
    entries.remove(serverId);
  }

  @override
  Future<Set<String>> ids() async => entries.keys.toSet();
}
