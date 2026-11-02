// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class DownloadProgress {
  const DownloadProgress({
    required this.url,
    required this.postId,
    this.progress = 0.0,
    this.status = DownloadStatus.downloading,
    this.error,
  });

  final String url;
  final String postId;
  final double progress;
  final DownloadStatus status;
  final String? error;

  /// [clearError] 用于显式清空错误：`error ?? this.error` 这种写法永远清不掉
  /// 已经写入的错误（BooruPageState 早就用哨兵值修过同一个坑，这里漏了）。
  DownloadProgress copyWith({
    double? progress,
    DownloadStatus? status,
    String? error,
    bool clearError = false,
  }) =>
      DownloadProgress(
        url: url,
        postId: postId,
        progress: progress ?? this.progress,
        status: status ?? this.status,
        error: clearError ? null : (error ?? this.error),
      );
}

enum DownloadStatus { downloading, completed, failed }

final downloadProgressProvider =
    StateNotifierProvider<DownloadProgressNotifier, List<DownloadProgress>>(
        (ref) {
  return DownloadProgressNotifier();
});

class DownloadProgressNotifier extends StateNotifier<List<DownloadProgress>> {
  DownloadProgressNotifier() : super([]);

  /// 终态条目保留多久后自动消失。`complete` 与 `fail` 都要清：此前只有
  /// 成功会清，失败条目永久堆积（长会话里越攒越多）。
  static const Duration _terminalTtl = Duration(seconds: 3);

  Timer? _sweepTimer;

  @override
  void dispose() {
    _sweepTimer?.cancel();
    super.dispose();
  }

  /// 启动一次下载。身份是 `postId + url`：修复前只按 URL 匹配，同一媒体
  /// 地址被两个帖子并发下载时，后一个 start 会把前一个的进度无条件清零
  /// （两条进度互相打断）。
  void start(String url, String postId) {
    final index = state.indexWhere(
      (d) => d.url == url && (postId.isEmpty || d.postId == postId),
    );
    if (index >= 0) {
      // 已在下载中：重复 start（连点两次下载、重新进入查看器）忽略即可。
      // 修复前无条件重置为 downloading/0，会把正在跑的进度打回起点。
      if (state[index].status == DownloadStatus.downloading) return;
      // 终态后重新下载：复用旧条目，顺带清掉上次的错误与进度。
      final next = [...state];
      next[index] = DownloadProgress(url: url, postId: postId);
      state = next;
      return;
    }
    state = [...state, DownloadProgress(url: url, postId: postId)];
  }

  /// 进度事件。[postId] 可选：只传 URL 的既有调用点按 URL 匹配。
  void update(String url, double progress, {String? postId}) {
    final matched = state.indexWhere((d) => _matches(d, url, postId));
    if (matched < 0) {
      // 未知 URL 不再静默丢弃：迟到的进度事件也补建条目，否则下载图标
      // 会一直停在不确定态（修复前 map 一遍、匹配不上就没了下文）。
      state = [
        ...state,
        DownloadProgress(url: url, postId: postId ?? '', progress: progress),
      ];
      return;
    }
    state = state
        .map((d) => _matches(d, url, postId) ? d.copyWith(progress: progress) : d)
        .toList();
  }

  void complete(String url, {String? postId}) {
    state = state
        .map((d) => _matches(d, url, postId)
            ? d.copyWith(
                status: DownloadStatus.completed,
                progress: 1.0,
                clearError: true,
              )
            : d)
        .toList();
    _scheduleSweep();
  }

  void fail(String url, String error, {String? postId}) {
    state = state
        .map((d) => _matches(d, url, postId)
            ? d.copyWith(status: DownloadStatus.failed, error: error)
            : d)
        .toList();
    _scheduleSweep();
  }

  void remove(String url, {String? postId}) {
    state = state.where((d) => !_matches(d, url, postId)).toList();
  }

  /// [postId] 为空表示「只按 URL」：兼容 post_viewer 只传 URL 的旧调用点，
  /// 也避免同一 URL 的多条记录漏更新。给了 postId 才精确到复合键。
  bool _matches(DownloadProgress d, String url, String? postId) =>
      d.url == url && (postId == null || postId.isEmpty || d.postId == postId);

  /// 一次性清理所有终态条目。用单个 Timer 而不是每条一个 delayed：
  /// 此前每完成一次就挂一个 Future.delayed，批量下载时挂出一堆定时器。
  void _scheduleSweep() {
    _sweepTimer?.cancel();
    _sweepTimer = Timer(_terminalTtl, () {
      if (!mounted) return;
      state = state
          .where((d) => d.status == DownloadStatus.downloading)
          .toList();
    });
  }
}
