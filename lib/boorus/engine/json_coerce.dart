// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

/// 各引擎 JSON 解析共用的**宽容**取值工具。
///
/// 站点响应并不守约：`score` 可能是 `3.5`（double）或 `"12"`（字符串），
/// `width` 可能是 double。此前解析器一律 `as int?` / `as String?` 硬转型，
/// 单条这样的记录会让**整页搜索**抛 TypeError —— 用户看到的是「搜索失败」，
/// 而不是少一条。取值一律宽容，配合 [parseEach] 的逐条 try/catch 丢条保页。
library;

/// 宽容取 int：int 原样；num 截断；字符串 parse；其余或解析失败用 [fallback]。
int asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

/// 宽容取 int，**解析失败返回 null**（区别于 [asInt] 的 0）。
///
/// 需要区分「站点没给这个字段」与「字段就是 0」时用它；只想要一个能参与
/// 计算的值就用 [asInt]。
int? asIntOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// 宽容取 double。
double asDouble(Object? value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? fallback;
  return fallback;
}

/// 宽容取 String：null → [fallback]；数字 / bool 走 toString。
String asStr(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

/// 非空字符串（trim 后）：空或缺失返回 null，省掉调用点的 `isEmpty ? null : x`。
String? asStrOrNull(Object? value) {
  final text = asStr(value).trim();
  return text.isEmpty ? null : text;
}

/// 宽容取字符串列表：非 List → 空表；元素里的非字符串跳过。
///
/// 此前用 `List<String>.from(v)`：只要列表里混进一个数字元素（站点确实会
/// 这么干）就抛 TypeError。
List<String> asStrList(Object? value) =>
    value is List ? value.whereType<String>().toList() : <String>[];

/// 宽容取 Map：非 Map 或键不是 String（`Map.from` 会抛）都返回空表。
Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    try {
      return Map<String, dynamic>.from(value);
    } catch (_) {
      return <String, dynamic>{};
    }
  }
  return <String, dynamic>{};
}

/// 宽容取 Map 列表（跳过非 Map 元素）。
List<Map<String, dynamic>> asMapList(Object? value) => value is List
    ? value.whereType<Map<String, dynamic>>().toList()
    : <Map<String, dynamic>>[];

/// 逐条解析并**丢条保页**：单条记录无论如何都不该让整页搜索失败。
///
/// [build] 返回 null 表示这条不算有效记录（例如 id 缺失），同样跳过。
List<T> parseEach<T>(
  Iterable<dynamic> json,
  T? Function(Map<String, dynamic> raw) build,
) {
  final out = <T>[];
  for (final item in json) {
    if (item is! Map<String, dynamic>) continue;
    try {
      final built = build(item);
      if (built != null) out.add(built);
    } catch (_) {
      // 丢一条，保住整页
    }
  }
  return out;
}
