// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/site_presets.dart';
import 'package:boorunova/data/repository/server/entity/server_preferences.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/util/batch_ops.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.defaultServerId,
    this.hostsEnabled = false,
    this.viewerSwipeMode = true,
    this.slideshowInterval = 3,
    this.swipeDownAction = 'close',
    this.previewQuality = 'sample',
    this.downloadConcurrency = defaultDownloadConcurrency,
    this.downloadQuality = 'original',
    this.accentColor = 0xFF1976D2,
    this.tapAction = 'detail',
    this.doubleTapAction = 'zoom',
    this.longPressAction = 'fav',
    this.downloadPath = '',
    this.reduceAnimations = false,
    this.gridColumns = defaultGridColumns,
    this.tagSuggestionLimit = defaultTagSuggestionLimit,
    this.language = 'zh',
    this.onboardingComplete = false,
    this.safeMode = kPlayBuild,
    this.ageConfirmed = false,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: AppThemeMode.values.firstWhere(
          (m) => m.name == json['themeMode'],
          orElse: () => AppThemeMode.system,
        ),
        defaultServerId: json['defaultServerId'] as String?,
        hostsEnabled: json['hostsEnabled'] as bool? ?? false,
        viewerSwipeMode: json['viewerSwipeMode'] as bool? ?? true,
        slideshowInterval: json['slideshowInterval'] as int? ?? 3,
        swipeDownAction: json['swipeDownAction'] as String? ?? 'close',
        // 默认 sample：查看器加载缩略级别的图省流量（原行为就是 mediaUrlOf
        // 优先给 sample，这里只是把它变成一个可配置项）
        previewQuality: json['previewQuality'] as String? ?? 'sample',
        // 老设置没有这个键 → 默认 3（与改动前写死的并发一致）
        downloadConcurrency: ((json['downloadConcurrency'] as num?)?.toInt() ??
                defaultDownloadConcurrency)
            .clamp(minDownloadConcurrency, maxDownloadConcurrency),
        downloadQuality: json['downloadQuality'] as String? ?? 'original',
        accentColor: json['accentColor'] as int? ?? 0xFF1976D2,
        tapAction: json['tapAction'] as String? ?? 'detail',
        doubleTapAction: json['doubleTapAction'] as String? ?? 'zoom',
        longPressAction: json['longPressAction'] as String? ?? 'fav',
        downloadPath: json['downloadPath'] as String? ?? '',
        reduceAnimations: json['reduceAnimations'] as bool? ?? false,
        gridColumns: ((json['gridColumns'] as num?)?.toInt()
                .clamp(minGridColumns, maxGridColumns) ??
            defaultGridColumns),
        // 此前这个设置只活在内存里（全应用唯一不持久化的设置）
        tagSuggestionLimit: ((json['tagSuggestionLimit'] as num?)?.toInt() ??
                defaultTagSuggestionLimit)
            .clamp(minTagSuggestionLimit, maxTagSuggestionLimit),
        language: json['language'] as String? ?? 'zh',
        onboardingComplete: json['onboardingComplete'] as bool? ?? false,
        // 老设置里没有这两个键：安全模式回落到「渠道默认」（Play 版开、
        // GitHub 直装版关），年龄确认回落到未确认。
        safeMode: json['safeMode'] as bool? ?? kPlayBuild,
        ageConfirmed: json['ageConfirmed'] as bool? ?? false,
      );

  final AppThemeMode themeMode;
  final String? defaultServerId;
  final bool hostsEnabled;
  final bool viewerSwipeMode;
  final int slideshowInterval;
  final String swipeDownAction;
  /// 查看器预览画质（`sample` / `original`）。
  final String previewQuality;

  final String downloadQuality;

  /// 批量下载并发数（1–6）。默认 3：再多会同时打满带宽与相册写入，
  /// 再少在多图时明显变慢。
  final int downloadConcurrency;
  final int accentColor;
  final String tapAction;
  final String doubleTapAction;
  final String longPressAction;
  final String downloadPath;
  final bool reduceAnimations;

  /// 瀑布流列数（2–6）。此前是内存 StateProvider，杀进程即重置回 3，
  /// 用户调好的布局留不住。clamp 兜住损坏数据，越界值回落到 3。
  final int gridColumns;

  /// 标签建议条数（4–20）。
  final int tagSuggestionLimit;

  /// 界面语言设置：'zh' | 'en' | 'system'。
  ///
  /// 'system' 是**设置值**而不是最终语言：真实语言要用 [resolveLanguage]
  /// 结合系统语言算出来（OPT §5.1）。
  final String language;


  /// 首次启动引导是否已完成
  final bool onboardingComplete;

  /// 安全模式：浏览默认只取安全档内容。
  ///
  /// Play 版默认开启（首启就是安全口径），GitHub 直装版默认关闭（保持既有
  /// 行为）。关闭它需要先完成本地年龄确认——见 [ageConfirmed]。
  final bool safeMode;

  /// 是否已在本机完成年龄确认（无账号，纯本地）。
  final bool ageConfirmed;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    String? defaultServerId,
    bool? hostsEnabled,
    bool? viewerSwipeMode,
    int? slideshowInterval,
    String? swipeDownAction,
    String? previewQuality,
    String? downloadQuality,
    int? downloadConcurrency,
    int? accentColor,
    String? tapAction,
    String? doubleTapAction,
    String? longPressAction,
    String? downloadPath,
    bool? reduceAnimations,
    int? gridColumns,
    int? tagSuggestionLimit,
    String? language,
    bool? onboardingComplete,
    bool? safeMode,
    bool? ageConfirmed,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        defaultServerId: defaultServerId ?? this.defaultServerId,
        hostsEnabled: hostsEnabled ?? this.hostsEnabled,
        viewerSwipeMode: viewerSwipeMode ?? this.viewerSwipeMode,
        slideshowInterval: slideshowInterval ?? this.slideshowInterval,
        swipeDownAction: swipeDownAction ?? this.swipeDownAction,
        previewQuality: previewQuality ?? this.previewQuality,
        downloadQuality: downloadQuality ?? this.downloadQuality,
        downloadConcurrency: downloadConcurrency ?? this.downloadConcurrency,
        accentColor: accentColor ?? this.accentColor,
        tapAction: tapAction ?? this.tapAction,
        doubleTapAction: doubleTapAction ?? this.doubleTapAction,
        longPressAction: longPressAction ?? this.longPressAction,
        downloadPath: downloadPath ?? this.downloadPath,
        reduceAnimations: reduceAnimations ?? this.reduceAnimations,
        gridColumns: gridColumns ?? this.gridColumns,
        tagSuggestionLimit: tagSuggestionLimit ?? this.tagSuggestionLimit,
        language: language ?? this.language,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        safeMode: safeMode ?? this.safeMode,
        ageConfirmed: ageConfirmed ?? this.ageConfirmed,
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'defaultServerId': defaultServerId,
        'hostsEnabled': hostsEnabled,
        'viewerSwipeMode': viewerSwipeMode,
        'slideshowInterval': slideshowInterval,
        'swipeDownAction': swipeDownAction,
        'previewQuality': previewQuality,
        'downloadQuality': downloadQuality,
        'downloadConcurrency': downloadConcurrency,
        'accentColor': accentColor,
        'tapAction': tapAction,
        'doubleTapAction': doubleTapAction,
        'longPressAction': longPressAction,
        'downloadPath': downloadPath,
        'reduceAnimations': reduceAnimations,
        'gridColumns': gridColumns,
        'tagSuggestionLimit': tagSuggestionLimit,
        'language': language,
        'onboardingComplete': onboardingComplete,
        'safeMode': safeMode,
        'ageConfirmed': ageConfirmed,
      };
}

/// 搜索页「全部」选项的哨兵值：显式要求「不加评级过滤」。
///
/// 需要一个独立取值，是因为 `null` 已经在表达「用户没选，用默认」——
/// 两者混为一谈时，「全部」会被当成「用默认」，于是被站点偏好/安全模式
/// 过滤掉，UI 与实际行为不一致。
const String kRatingAny = 'any';

/// 界面语言设置里代表「跟随系统」的值。
const String kLanguageSystem = 'system';

/// 把语言**设置值**解析成实际使用的语言代码（OPT §5.1）。
///
/// 'zh' / 'en' 直接就是结果；'system' 才需要看系统语言。口径与启动降级页
/// 保持一致：**只有**系统语言是 en 才用英文，其余（含不支持的语言）回落中文
/// ——两处不一致的话，英文系统用户在降级页与正常页面会看到不同语言。
String resolveLanguage(String setting, String systemLanguageCode) {
  if (setting == 'zh' || setting == 'en') return setting;
  return systemLanguageCode.toLowerCase().startsWith('en') ? 'en' : 'zh';
}

/// 本次浏览实际使用的评级短码。
///
/// 安全模式开启且用户没有显式选评级时，只取安全档 `s`（各引擎自己把它
/// 映射成 `rating:g` / `rating:safe` / `rating:general`…）。用户显式选了
/// 评级就按他选的来——那是用户在这次搜索里的主动选择，不是「默认放行」。
///
/// 放在这里而不是 UI 里：首页首屏、切站、搜索提交三个入口都要用同一口径，
/// 各算一次必然分叉。
String? effectiveBrowseRating(String? chosen, AppSettings settings) {
  if (chosen != null && chosen.isNotEmpty) return chosen;
  return settings.safeMode ? 's' : null;
}

/// 某站点本次浏览实际使用的评级。
///
/// 优先级（从高到低）：
/// 1. 用户这次搜索**显式**选的评级（当次动作，按他选的来）；
/// 2. 站点级偏好 `visibleRating`；
/// 3. 全局安全模式（开启则安全档）。
///
/// **安全模式不可被站点设置放宽**：站点偏好写了 `e`，Play 版安全模式下仍然
/// 只取 `s`——否则「按站点配置」就成了绕过合规默认的后门。
String? effectiveRatingForServer({
  required AppSettings settings,
  required ServerPreferences preferences,
  String? chosen,
}) {
  // 「全部」是**显式**的「不加评级过滤」：它不能再落回站点默认，否则用户
  // 在搜索页选了「全部」却仍然被站点偏好过滤（等于这个选项骗人）。
  // 安全模式仍然兜底——合规口径不该被一个 UI 选项放宽。
  if (chosen == kRatingAny) return settings.safeMode ? 's' : null;
  if (chosen != null && chosen.isNotEmpty) return chosen;
  if (settings.safeMode) return 's';
  return preferences.visibleRating;
}

/// 某站点实际使用的**预览**画质（站点偏好优先，否则跟随全局）。
String previewQualityFor(
  AppSettings settings,
  ServerPreferences preferences,
) =>
    preferences.previewQuality ?? settings.previewQuality;

/// 某站点实际使用的下载画质（站点偏好优先，否则跟随全局）。
String downloadQualityFor(
  AppSettings settings,
  ServerPreferences preferences,
) =>
    preferences.downloadQuality ?? settings.downloadQuality;

/// 搜索页排序的元标签写法。
///
/// 站点偏好里存语义键（`score`），查询串里需要元标签（`order:score`）。
/// 这层映射只在这里做一次：两处各拼一次必然分叉。
String sortMetaTag(String? sortKey) => switch (sortKey) {
      'score' => 'order:score',
      'date' => 'order:date',
      'rating' => 'order:rating',
      _ => '',
    };

/// 打开搜索页时应当预选的排序：站点有默认就用它，否则沿用当前选择。
String effectiveSortForServer({
  required ServerPreferences preferences,
  required String current,
}) =>
    preferences.defaultSort == null ? current : sortMetaTag(preferences.defaultSort);

/// 瀑布流列数取值范围。UI 循环按钮与设置反序列化共用这组边界。
const int minGridColumns = 2;
const int defaultGridColumns = 3;
const int maxGridColumns = 6;

/// 标签建议条数取值范围。UI 滑杆与反序列化共用这组边界。
const int minTagSuggestionLimit = 4;
const int defaultTagSuggestionLimit = 12;
const int maxTagSuggestionLimit = 20;

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final box = HiveSetup.settingsBox;
    final raw = box.get('app_settings');
    final map = raw is Map ? Map<String, dynamic>.from(raw) : null;
    if (map != null) {
      return AppSettings.fromJson(map);
    }
    return const AppSettings();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _persist();
  }

  Future<void> setDefaultServerId(String? id) async {
    state = state.copyWith(defaultServerId: id);
    await _persist();
  }

  Future<void> setHostsEnabled(bool enabled) async {
    state = state.copyWith(hostsEnabled: enabled);
    await _persist();
  }

  Future<void> setViewerSwipeMode(bool horizontal) async {
    state = state.copyWith(viewerSwipeMode: horizontal);
    await _persist();
  }

  Future<void> setSlideshowInterval(int seconds) async {
    state = state.copyWith(slideshowInterval: seconds);
    await _persist();
  }

  Future<void> setSwipeDownAction(String action) async {
    state = state.copyWith(swipeDownAction: action);
    await _persist();
  }

  /// 批量下载并发数（1–6，越界自动夹紧）。
  Future<void> setDownloadConcurrency(int value) async {
    final clamped = value.clamp(minDownloadConcurrency, maxDownloadConcurrency);
    if (clamped == state.downloadConcurrency) return;
    state = state.copyWith(downloadConcurrency: clamped);
    await _persist();
  }

  Future<void> setPreviewQuality(String quality) async {
    if (quality == state.previewQuality) return;
    state = state.copyWith(previewQuality: quality);
    await _persist();
  }

  Future<void> setDownloadQuality(String quality) async {
    state = state.copyWith(downloadQuality: quality);
    await _persist();
  }

  Future<void> setAccentColor(int color) async {
    state = state.copyWith(accentColor: color);
    await _persist();
  }

  Future<void> setTapAction(String action) async {
    state = state.copyWith(tapAction: action);
    await _persist();
  }

  Future<void> setDoubleTapAction(String action) async {
    state = state.copyWith(doubleTapAction: action);
    await _persist();
  }

  Future<void> setLongPressAction(String action) async {
    state = state.copyWith(longPressAction: action);
    await _persist();
  }

  Future<void> setDownloadPath(String path) async {
    state = state.copyWith(downloadPath: path);
    await _persist();
  }

  Future<void> setReduceAnimations(bool enabled) async {
    state = state.copyWith(reduceAnimations: enabled);
    await _persist();
  }

  /// 设置瀑布流列数，clamp 到 [minColumns]–[maxColumns]。
  Future<void> setGridColumns(int columns) async {
    final clamped = columns.clamp(minGridColumns, maxGridColumns);
    if (clamped == state.gridColumns) return;
    state = state.copyWith(gridColumns: clamped);
    await _persist();
  }

  /// 设置标签建议条数，clamp 到 [minTagSuggestionLimit]–[maxTagSuggestionLimit]。
  Future<void> setTagSuggestionLimit(int limit) async {
    final clamped = limit.clamp(minTagSuggestionLimit, maxTagSuggestionLimit);
    if (clamped == state.tagSuggestionLimit) return;
    state = state.copyWith(tagSuggestionLimit: clamped);
    await _persist();
  }

  /// 切换界面语言并同步 T 静态文案标志。
  ///
  /// [code] 可以是 'zh' / 'en' / 'system'；'system' 在落状态时就要算出真实
  /// 语言再喂给 `T.setLocale`，否则静态文案会停在上一门语言
  /// （`T` 是静态类，不看 MaterialApp 的 locale）。
  Future<void> setLanguage(String code) async {
    T.setLocale(resolveLanguage(
      code,
      WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    ));
    state = state.copyWith(language: code);
    await _persist();
  }

  /// 设置安全模式。
  ///
  /// **调用方**负责在关闭前做年龄确认（见隐私页）；这里只落状态。
  Future<void> setSafeMode(bool enabled) async {
    if (enabled == state.safeMode) return;
    state = state.copyWith(safeMode: enabled);
    await _persist();
  }

  /// 记录一次本地年龄确认。
  Future<void> markAgeConfirmed() async {
    if (state.ageConfirmed) return;
    state = state.copyWith(ageConfirmed: true);
    await _persist();
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(onboardingComplete: true);
    await _persist();
  }

  Future<void> restore(AppSettings settings) async {
    state = settings;
    await _persist();
  }

  Future<void> _persist() async {
    await HiveSetup.settingsBox.put('app_settings', state.toJson());
  }
}
