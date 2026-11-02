// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

/// 备份格式的**纯逻辑**：组装导出封套、校验版本、按段合并导入。
///
/// 抽出来的理由：H6 的四类缺陷（可达性/完整性/容错/语义）里，只有最后两类
/// 是可以用单测钉住的——合并语义和逐条容错一旦回归，用户丢的是数据，不是
/// 一次点击。放在页面里就只能靠手工点。
library;

import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/data/repository/history/user_history_repo.dart';
import 'package:boorunova/data/repository/hosts/entity/host_entry.dart';
import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/tags_blocker/entity/booru_tag.dart';

/// 当前支持的备份格式版本。
const int kBackupSchemaVersion = 1;

/// 备份里的数据段名（导出与导入共用一份，避免两边写错字符串）。
const String kBackupSectionSettings = 'settings';
const String kBackupSectionServers = 'servers';
const String kBackupSectionBlockedTags = 'blockedTags';
const String kBackupSectionFavorites = 'favorites';
const String kBackupSectionSearchHistory = 'searchHistory';
const String kBackupSectionDownloads = 'downloads';
const String kBackupSectionHistory = 'history';
const String kBackupSectionHosts = 'hosts';

/// 组装导出封套。
///
/// 不含凭据（apiKey/login）：见 [BooruServer.toBackupJson]。
Map<String, dynamic> buildBackupPayload({
  required Map<String, dynamic> settings,
  required List<BooruServer> servers,
  required List<BooruTag> blockedTags,
  required List<BooruPost> favorites,
  required List<String> searchHistory,
  required List<DownloadEntry> downloads,
  required List<HistoryEntry> history,
  required List<HostEntry> hosts,
  DateTime? timestamp,
}) =>
    {
      'version': kBackupSchemaVersion,
      'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
      'data': {
        kBackupSectionSettings: settings,
        'serverCount': servers.length,
        kBackupSectionServers:
            servers.map((s) => s.toBackupJson()).toList(),
        kBackupSectionBlockedTags:
            blockedTags.map((t) => t.toJson()).toList(),
        kBackupSectionFavorites: favorites.map((f) => f.toJson()).toList(),
        kBackupSectionSearchHistory: searchHistory,
        kBackupSectionDownloads: downloads.map((d) => d.toJson()).toList(),
        kBackupSectionHistory: history.map((h) => h.toJson()).toList(),
        kBackupSectionHosts: hosts.map((h) => h.toJson()).toList(),
      },
    };

/// 备份版本是否可导入：比当前代码更新的格式必须拒绝，
/// 否则等于用新结构的数据去写旧结构。
bool isBackupVersionSupported(Object? version) {
  final value = version is num ? version.toInt() : 1;
  return value <= kBackupSchemaVersion;
}

/// 一段导入的结果：合并后的完整列表 + 成功/跳过计数。
class SectionImport<T> {
  const SectionImport(this.items, {required this.ok, required this.skipped});

  final List<T> items;
  final int ok;
  final int skipped;

  int get total => ok + skipped;
}

/// 各段的合并规则。
///
/// 统一口径：**逐条容错**（坏记录只跳过它自己，不像此前那样一条坏记录就
/// 中断整段并让已写入的部分没有提示），**合并而非替换**（除了设置，
/// 它有覆盖语义是刻意的）。
class BackupMerger {
  BackupMerger._();

  /// 逐条解析：单条坏记录只跳过它自己。
  static SectionImport<T> parse<T>(
    List<dynamic> raw,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final out = <T>[];
    var ok = 0;
    var skipped = 0;
    for (final item in raw) {
      try {
        if (item is! Map) throw const FormatException('not an object');
        out.add(fromJson(Map<String, dynamic>.from(item)));
        ok++;
      } catch (_) {
        skipped++;
      }
    }
    return SectionImport(out, ok: ok, skipped: skipped);
  }

  /// 服务器：按 id 去重合并（同 id 以已有的为准）。
  static SectionImport<BooruServer> servers(
    List<BooruServer> existing,
    List<dynamic> raw,
  ) {
    final parsed = parse(raw, BooruServer.fromJson);
    final merged = [...existing];
    final seen = merged.map((s) => s.id).toSet();
    for (final server in parsed.items) {
      if (seen.add(server.id)) merged.add(server);
    }
    return SectionImport(merged, ok: parsed.ok, skipped: parsed.skipped);
  }

  /// 收藏：按 serverId|id 去重（不同站点的同号帖子是两条）。
  static SectionImport<BooruPost> favorites(
    List<BooruPost> existing,
    List<dynamic> raw,
  ) {
    final parsed = parse(raw, BooruPost.fromJson);
    final merged = [...existing];
    final seen = merged.map(_postKey).toSet();
    for (final post in parsed.items) {
      if (seen.add(_postKey(post))) merged.add(post);
    }
    return SectionImport(merged, ok: parsed.ok, skipped: parsed.skipped);
  }

  /// 下载记录：按 serverId|postId 去重。
  ///
  /// 此前只比 postId：不同站点的同号帖子会被当成重复而少导入。
  static SectionImport<DownloadEntry> downloads(
    List<DownloadEntry> existing,
    List<dynamic> raw,
  ) {
    final parsed = parse(raw, DownloadEntry.fromJson);
    final merged = [...existing];
    final seen = merged.map((d) => '${d.serverId}|${d.postId}').toSet();
    for (final entry in parsed.items) {
      if (seen.add('${entry.serverId}|${entry.postId}')) merged.add(entry);
    }
    return SectionImport(merged, ok: parsed.ok, skipped: parsed.skipped);
  }

  /// 浏览历史：按 serverId|postId 合并，保留 viewedAt **较新**的一条，
  /// 按时间倒序，上限 [max]。
  static SectionImport<HistoryEntry> history(
    List<HistoryEntry> existing,
    List<dynamic> raw, {
    required int max,
  }) {
    final parsed = parse(raw, HistoryEntry.fromJson);
    final merged = <String, HistoryEntry>{
      for (final entry in existing) _historyKey(entry): entry,
    };
    for (final entry in parsed.items) {
      final key = _historyKey(entry);
      final older = merged[key];
      if (older == null || entry.viewedAt.isAfter(older.viewedAt)) {
        merged[key] = entry;
      }
    }
    final list = merged.values.toList()
      ..sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
    if (list.length > max) list.removeRange(max, list.length);
    return SectionImport(list, ok: parsed.ok, skipped: parsed.skipped);
  }

  /// hosts：按 domain（小写）合并，导入侧同域名覆盖。
  static SectionImport<HostEntry> hosts(
    List<HostEntry> existing,
    List<dynamic> raw,
  ) {
    final parsed = parse(raw, HostEntry.fromJson);
    final merged = <String, HostEntry>{
      for (final entry in existing) entry.domain.toLowerCase(): entry,
    };
    for (final entry in parsed.items) {
      merged[entry.domain.toLowerCase()] = entry;
    }
    return SectionImport(
      merged.values.toList(),
      ok: parsed.ok,
      skipped: parsed.skipped,
    );
  }

  /// 搜索历史：**合并**而非替换（此前 replaceAll 会把当前记录静默清空）：
  /// 现有条目在前，导入条目去重后追加，保留前 [max] 条。
  static SectionImport<String> searchHistory(
    List<String> existing,
    List<dynamic> raw, {
    int max = 20,
  }) {
    var skipped = 0;
    final merged = <String>[];
    for (final query in [...existing, ...raw]) {
      if (query is! String || query.isEmpty) {
        skipped++;
        continue;
      }
      if (merged.contains(query)) continue;
      merged.add(query);
    }
    final limited = merged.length > max ? merged.sublist(0, max) : merged;
    return SectionImport(
      limited,
      ok: limited.length,
      skipped: skipped,
    );
  }

  static String _postKey(BooruPost post) => '${post.serverId}|${post.id}';

  static String _historyKey(HistoryEntry entry) =>
      '${entry.serverId}|${entry.postId}';
}
