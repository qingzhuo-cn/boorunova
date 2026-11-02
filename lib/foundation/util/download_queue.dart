// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/database/json_store.dart';
import 'package:flutter/foundation.dart';

/// 一条待完成的下载（OPT §3.3）。
@immutable
class PendingDownload {
  const PendingDownload({
    required this.url,
    required this.postId,
    required this.namespace,
    required this.addedAt,
  });

  final String url;
  final String postId;

  /// 所属站点（下载子目录按它取）。
  final String namespace;

  final DateTime addedAt;

  /// 身份是 `postId|url`：同一媒体被两个帖子下载时不能互相顶掉。
  String get key => '$postId|$url';

  Map<String, dynamic> toJson() => {
        'url': url,
        'postId': postId,
        'namespace': namespace,
        'addedAt': addedAt.millisecondsSinceEpoch,
      };

  static PendingDownload? fromJson(Map<String, dynamic> json) {
    final url = json['url'];
    if (url is! String || url.isEmpty) return null;
    final added = json['addedAt'];
    return PendingDownload(
      url: url,
      postId: json['postId'] is String ? json['postId'] as String : '',
      namespace:
          json['namespace'] is String ? json['namespace'] as String : '',
      addedAt: added is int
          ? DateTime.fromMillisecondsSinceEpoch(added)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// 队列的纯策略：合并与移除。抽出来是为了能穷举边界（重复入队、乱序完成），
/// Hive 那层只负责读写。
class DownloadQueueOps {
  DownloadQueueOps._();

  /// 队列上限：够大（一次批量最多几十条），但不会无界增长。
  static const int maxEntries = 200;

  /// 超过这个年龄的条目不再提示续跑：与断点续传的 `.part` 保鲜期同口径，
  /// 隔太久的半截文件本来也不会被用来续传了。
  static const Duration maxAge = Duration(days: 7);

  /// 合并入队：按 [PendingDownload.key] 去重，新的覆盖旧的（保留最新时间），
  /// 丢掉过旧的条目，并按时间升序截断到 [maxEntries]。
  static List<PendingDownload> merge(
    List<PendingDownload> existing,
    List<PendingDownload> incoming, {
    required DateTime now,
  }) {
    final byKey = <String, PendingDownload>{};
    for (final item in [...existing, ...incoming]) {
      if (now.difference(item.addedAt) > maxAge) continue;
      byKey[item.key] = item;
    }
    final merged = byKey.values.toList()
      ..sort((a, b) => a.addedAt.compareTo(b.addedAt));
    if (merged.length <= maxEntries) return merged;
    return merged.sublist(merged.length - maxEntries);
  }

  /// 移除已完成/已放弃的条目。
  static List<PendingDownload> remove(
    List<PendingDownload> existing, {
    required String url,
    required String postId,
  }) {
    final key = '$postId|$url';
    return existing.where((e) => e.key != key).toList();
  }
}

/// 本次运行是否已经问过「要不要续跑」。
///
/// 放在这里（而不是页面 State 里）是因为它是**进程级**状态：HomeContent 会随
/// 导航重建（从设置页回到首页、切站点等），实例字段会让用户在每次回到首页时
/// 又被问一遍；而下载失败后条目本来就还留在队列里。
bool _resumePromptShownThisRun = false;

/// 领取「本次运行问一次」的额度：第一次 true，之后 false。
bool consumeResumePromptSlot() {
  if (_resumePromptShownThisRun) return false;
  _resumePromptShownThisRun = true;
  return true;
}

/// 仅测试用：重置「本次运行已问过」的标记。
@visibleForTesting
void resetResumePromptSlot() => _resumePromptShownThisRun = false;

/// 「未完成的下载」落盘（OPT §3.3）。
///
/// 此前进度只在内存里，重启即丢：用户点了批量下载、中途被杀进程或退出，
/// 回来时既没有任何提示、也没有续跑入口，得自己回忆哪些还没下。
/// 这里只存**恢复所需的最小信息**（URL / 帖子 / 站点），路径与子目录在恢复时
/// 按当时的设置重新算——存下来的路径很可能已经过期。
///
/// 两个刻意的取舍：
/// - **恢复用的是当初存下的 URL**（即当初那份画质），而不是按现在的设置重解析。
///   用户当时要的就是那个文件，半截的 `.part` 也是按它下的；重解析会让续传
///   找不到半截文件、等于从头再下一份。
/// - **失败/取消的条目留在队列里**（只有下载成功才出队）：它们是可续跑的，
///   而且有 7 天保鲜期与「每运行只问一次」两道闸，不会变成无限骚扰。
class DownloadQueueStore {
  /// 默认落到设置 box 的一个独立键：与其它仓库同源，复用同一套串行事务。
  factory DownloadQueueStore([JsonListStore? store]) => DownloadQueueStore._(
        store ?? JsonListStore(HiveSetup.settingsBox, 'pending_downloads'),
      );

  DownloadQueueStore._(this._store);

  final JsonListStore _store;

  Future<List<PendingDownload>> pending() async {
    final rows = _store.read();
    return rows
        .map(PendingDownload.fromJson)
        .whereType<PendingDownload>()
        .toList();
  }

  /// 入队（并入已有条目）。
  ///
  /// 走 update 的事务式读改写：并发的「入队 / 出队」不会互相覆盖
  /// （这正是 JsonListStore 存在的理由）。
  Future<void> add(List<PendingDownload> items, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    await _store.update((current) {
      final existing = current
          .map(PendingDownload.fromJson)
          .whereType<PendingDownload>()
          .toList();
      final merged = DownloadQueueOps.merge(existing, items, now: at);
      return [for (final item in merged) item.toJson()];
    });
  }

  /// 出队（下载成功或用户放弃后调用）。
  Future<void> remove({required String url, required String postId}) async {
    await _store.update((current) {
      final existing = current
          .map(PendingDownload.fromJson)
          .whereType<PendingDownload>()
          .toList();
      final next = DownloadQueueOps.remove(
        existing,
        url: url,
        postId: postId,
      );
      return [for (final item in next) item.toJson()];
    });
  }

  Future<void> clear() => _store.write(const []);
}
