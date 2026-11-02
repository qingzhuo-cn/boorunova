// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:flutter/material.dart';

/// 分级（rating）展示色。
///
/// 全应用唯一的 s/q/e → 颜色映射。此前详情页内联了这份三元表达式，
/// 收藏页与历史页则完全不配色，同一张图在不同页面颜色不一致。
Color ratingColor(String rating) {
  switch (rating.toLowerCase()) {
    case 'e':
      return Colors.red;
    case 'q':
      return Colors.orange;
    case 's':
      return Colors.green;
    default:
      return Colors.blueGrey;
  }
}
