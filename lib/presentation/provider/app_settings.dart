import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/presentation/provider/app_theme.dart';
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
    this.downloadQuality = 'original',
    this.accentColor = 0xFF1976D2,
    this.tapAction = 'detail',
    this.doubleTapAction = 'zoom',
    this.longPressAction = 'fav',
    this.downloadPath = '',
    this.reduceAnimations = false,
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
        downloadQuality: json['downloadQuality'] as String? ?? 'original',
        accentColor: json['accentColor'] as int? ?? 0xFF1976D2,
        tapAction: json['tapAction'] as String? ?? 'detail',
        doubleTapAction: json['doubleTapAction'] as String? ?? 'zoom',
        longPressAction: json['longPressAction'] as String? ?? 'fav',
        downloadPath: json['downloadPath'] as String? ?? '',
        reduceAnimations: json['reduceAnimations'] as bool? ?? false,
      );

  final AppThemeMode themeMode;
  final String? defaultServerId;
  final bool hostsEnabled;
  final bool viewerSwipeMode;
  final int slideshowInterval;
  final String swipeDownAction;
  final String downloadQuality;
  final int accentColor;
  final String tapAction;
  final String doubleTapAction;
  final String longPressAction;
  final String downloadPath;
  final bool reduceAnimations;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    String? defaultServerId,
    bool? hostsEnabled,
    bool? viewerSwipeMode,
    int? slideshowInterval,
    String? swipeDownAction,
    String? downloadQuality,
    int? accentColor,
    String? tapAction,
    String? doubleTapAction,
    String? longPressAction,
    String? downloadPath,
    bool? reduceAnimations,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        defaultServerId: defaultServerId ?? this.defaultServerId,
        hostsEnabled: hostsEnabled ?? this.hostsEnabled,
        viewerSwipeMode: viewerSwipeMode ?? this.viewerSwipeMode,
        slideshowInterval: slideshowInterval ?? this.slideshowInterval,
        swipeDownAction: swipeDownAction ?? this.swipeDownAction,
        downloadQuality: downloadQuality ?? this.downloadQuality,
        accentColor: accentColor ?? this.accentColor,
        tapAction: tapAction ?? this.tapAction,
        doubleTapAction: doubleTapAction ?? this.doubleTapAction,
        longPressAction: longPressAction ?? this.longPressAction,
        downloadPath: downloadPath ?? this.downloadPath,
        reduceAnimations: reduceAnimations ?? this.reduceAnimations,
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'defaultServerId': defaultServerId,
        'hostsEnabled': hostsEnabled,
        'viewerSwipeMode': viewerSwipeMode,
        'slideshowInterval': slideshowInterval,
        'swipeDownAction': swipeDownAction,
        'downloadQuality': downloadQuality,
        'accentColor': accentColor,
        'tapAction': tapAction,
        'doubleTapAction': doubleTapAction,
        'longPressAction': longPressAction,
        'downloadPath': downloadPath,
        'reduceAnimations': reduceAnimations,
      };
}

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

  Future<void> _persist() async {
    await HiveSetup.settingsBox.put('app_settings', state.toJson());
  }
}
