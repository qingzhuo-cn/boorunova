// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppThemeMode {
  system,
  light,
  dark,
  midnight,
}

// 主题不是独立状态：唯一来源是 AppSettings.themeMode。此前这里另有一个
// StateProvider，两份状态各自更新（启动时从 settings 同步一次、切换时双写），
// 备份恢复的主题必须重启才生效——删掉它，让 MaterialApp 直接 select settings。

class AppTheme {
  /// ThemeData 构建不便宜（ColorScheme.fromSeed 要跑一遍调和算法），而
  /// MaterialApp 每次重建都会取两份主题。这里按 (模式, 强调色) 记忆化：
  /// 调列数 / 切语言 / 改任意其它设置时不再重复构建。
  static final Map<String, ThemeData> _cache = <String, ThemeData>{};

  static ThemeData _memo(String key, ThemeData Function() build) {
    final cached = _cache[key];
    if (cached != null) return cached;
    // 色板是有限集合，加个上限防止意外注入大量不同 seed 时无界增长
    if (_cache.length >= 24) _cache.clear();
    return _cache[key] = build();
  }

  /// MaterialApp 用的亮色主题（缓存版）。
  static ThemeData lightFor(int accent) =>
      _memo('light:$accent', () => light(accentColor: Color(accent)));

  /// MaterialApp 用的暗色主题（缓存版）：system 跟随系统时用午夜观感，
  /// 显式 dark 用普通暗色（与既有行为一致）。
  static ThemeData darkFor(AppThemeMode mode, int accent) {
    final midnight = mode == AppThemeMode.midnight || mode == AppThemeMode.system;
    return _memo(
      '${midnight ? 'midnight' : 'dark'}:$accent',
      () => midnight
          ? AppTheme.midnight(accentColor: Color(accent))
          : dark(accentColor: Color(accent)),
    );
  }

  static ThemeData light({Color accentColor = const Color(0xFF951EE5)}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData dark({Color accentColor = const Color(0xFF951EE5)}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData midnight({Color accentColor = const Color(0xFF951EE5)}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF121212),
      surfaceContainerLow: const Color(0xFF1A1A1A),
      surfaceContainer: const Color(0xFF1E1E1E),
      surfaceContainerHigh: const Color(0xFF252525),
      surfaceContainerHighest: const Color(0xFF2C2C2C),
    );
    return dark(accentColor: accentColor).copyWith(
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: const Color(0xFF1E1E1E),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    // 系统栏图标亮度跟随主题：浅色主题用深色图标，深色主题用浅色图标，
    // 修复浅色模式下状态栏白色图标不可见的问题。
    final dark = colorScheme.brightness == Brightness.dark;
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        // 滚动时不做表面着色，保持与午夜主题一致的纯平面观感
        scrolledUnderElevation: 0,
        systemOverlayStyle: overlay,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
      ),
      // 按键统一胶囊形：与液态玻璃圆角语言一致，触控高度不低于 44dp
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 44),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 44),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(48, 40),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
