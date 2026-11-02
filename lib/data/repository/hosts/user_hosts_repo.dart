// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'dart:io';

import 'package:boorunova/data/repository/hosts/entity/host_entry.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/database/json_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userHostsRepoProvider = Provider<UserHostsRepo>((ref) {
  return UserHostsRepo();
});

class UserHostsRepo {
  static const _key = 'hosts';

  /// 走统一的串行写队列：此前 add/remove 各自「读全量 → 整键覆写」，
  /// 设置页保存与备份导入并发时后写者会把先写者整段覆盖掉。
  static JsonListStore get _store =>
      JsonListStore(HiveSetup.settingsBox, _key);

  /// IP 是否为字面量地址。
  ///
  /// `InternetAddress.tryParse` 只解析字面量、不做 DNS 查询，正是 hosts
  /// 需要的口径。此前任意字符串都能当 IP 存进来（包括 `gelbooru.com`），
  /// 等于把正常解析指向一个根本不存在的地址。
  static bool isValidIp(String value) =>
      InternetAddress.tryParse(value.trim()) != null;

  /// 域名是否合法：至少两段（必须含点）的合法主机名。
  ///
  /// 必须拒绝单标签：`match()` 用 `lower.endsWith('.$domain')` 判定归属，
  /// 一条 `1.2.3.4 com` 会让所有 .com 站点都命中它——用户只加了一行，
  /// 却劫持了整个顶级域。
  static final RegExp _domainPattern = RegExp(
    r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
  );

  static bool isValidDomain(String value) =>
      _domainPattern.hasMatch(value.trim());

  /// 一条映射的最小合法性：IP 与域名都通过。
  static bool isValidEntry(HostEntry entry) =>
      isValidIp(entry.ip) && isValidDomain(entry.domain);

  List<HostEntry> getAll() {
    // JsonListStore.read 已经保证「读取永不抛」：整键畸形会隔离留证并返回
    // 空表，单条畸形会被跳过。这里只需处理 HostEntry 自身的字段校验。
    return _store
        .read()
        .map((m) {
          try {
            return HostEntry.fromJson(m);
          } catch (_) {
            return null;
          }
        })
        .whereType<HostEntry>()
        .toList();
  }

  HostEntry? getByDomain(String domain) {
    final lower = domain.toLowerCase();
    return getAll().where((h) => h.domain.toLowerCase() == lower).firstOrNull;
  }

  HostEntry? match(String urlDomain) {
    final lower = _normalizeDomain(urlDomain);
    return getAll().where((h) {
      final domain = _normalizeDomain(h.domain);
      return lower == domain || lower.endsWith('.$domain');
    }).firstOrNull;
  }

  static String _normalizeDomain(String value) {
    var domain = value.trim().toLowerCase();
    while (domain.endsWith('.')) {
      domain = domain.substring(0, domain.length - 1);
    }
    return domain;
  }

  Future<void> add(HostEntry entry) {
    // 非法条目直接拒绝，避免「加一条错规则」变成整站不可用。
    if (!isValidEntry(entry)) return Future<void>.value();
    return _store.update((items) {
      final next = items
          .where((m) =>
              '${m['domain'] ?? ''}'.toLowerCase() !=
                  entry.domain.toLowerCase())
          .toList()
        ..add(entry.toJson());
      return next;
    });
  }

  Future<void> remove(String domain) {
    final lower = domain.toLowerCase();
    return _store.update((items) => items
        .where((m) => '${m['domain'] ?? ''}'.toLowerCase() != lower)
        .toList());
  }

  Future<void> update(HostEntry entry) => add(entry);

  Future<void> replaceAll(List<HostEntry> entries) =>
      _store.write(_sanitize(entries));

  Future<void> clear() => _store.clear();

  /// 兜底：所有写入路径都不该把非法条目落盘（调用方可能不是设置页，
  /// 比如备份导入）。
  static List<Map<String, dynamic>> _sanitize(List<HostEntry> entries) =>
      [
        for (final entry in entries)
          if (isValidEntry(entry)) entry.toJson(),
      ];
}
