// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:convert';

/// 安全解析 JSON 字符串为 List；非列表类型或解析失败返回空列表，
/// 避免某一条脏数据让整个仓库 getAll() 抛错而丢失后续写入。
List<dynamic> decodeJsonList(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded : const [];
  } catch (_) {
    return const [];
  }
}

/// 把元素安全转为 Map<String, dynamic>，否则返回 null。
Map<String, dynamic>? asStringMap(Object? item) {
  if (item is Map<String, dynamic>) return item;
  if (item is Map) return Map<String, dynamic>.from(item);
  return null;
}

/// 只把 String 原样返回，其它类型（含 null）返回 null。
/// 用于 Hive 读取 `get(key) as String?` 的安全版，避免个别键被写入非
/// String（schema 漂移）时整个 getAll() 抛 TypeError。
String? asStringOrNull(Object? v) => v is String ? v : null;
