// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

/// 播放时间显示：`mm:ss`，超过一小时给 `h:mm:ss`。
///
/// 单独抽出来是为了可测：播放器控制层依赖真实解码器，不便在单测里跑，
/// 而时间格式有边界（59 秒、60 秒进位、跨小时、负数兜底）值得锁住。
String formatVideoDuration(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}
