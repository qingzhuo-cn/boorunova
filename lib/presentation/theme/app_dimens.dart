// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:flutter/material.dart';

/// 设计令牌：全局统一的间距与圆角。
///
/// 各页面请优先引用这里的常量，避免魔法数字漂移
/// （此前项目中圆角有 2/4/6/8/11/12/16/20 八种取值并存）。
class AppDimens {
  AppDimens._();

  // ---- 间距 ----
  static const double spaceXS = 4;
  static const double spaceS = 8;
  static const double spaceM = 12;
  static const double spaceL = 16;
  static const double spaceXL = 20;
  static const double spaceXXL = 24;

  // ---- 圆角 ----
  /// 小元素：缩略图、内嵌图片
  static const double radiusS = 6;

  /// 中等元素：卡片、输入框、SnackBar
  static const double radiusM = 12;

  /// 大元素：底部弹层、预览浮层
  static const double radiusL = 16;

  static const BorderRadius brS = BorderRadius.all(Radius.circular(radiusS));
  static const BorderRadius brM = BorderRadius.all(Radius.circular(radiusM));
  static const BorderRadius brL = BorderRadius.all(Radius.circular(radiusL));
}
