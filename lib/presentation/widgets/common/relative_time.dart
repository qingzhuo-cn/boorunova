// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/presentation/l10n/app_strings.dart';

/// 相对时间格式化（「刚刚 / 5 分钟前 / 3 小时前 / 2 天前」）。
///
/// 下载记录与浏览历史此前各写一份逐行相同的实现。抽到这里后，
/// 调整粒度或措辞只需改一处。
String formatRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return T.justNow;
  if (diff.inHours < 1) return '${diff.inMinutes}${T.minutesAgo}';
  if (diff.inDays < 1) return '${diff.inHours}${T.hoursAgo}';
  return '${diff.inDays}${T.daysAgo}';
}
