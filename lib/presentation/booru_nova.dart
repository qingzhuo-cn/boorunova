import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/app_theme.dart';
import 'package:boorunova/presentation/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BooruNova extends ConsumerStatefulWidget {
  const BooruNova({super.key});

  @override
  ConsumerState<BooruNova> createState() => _BooruNovaState();
}

class _BooruNovaState extends ConsumerState<BooruNova> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      ref.read(appThemeModeProvider.notifier).state = settings.themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    final darkTheme = switch (themeMode) {
      AppThemeMode.midnight || AppThemeMode.system => AppTheme.midnight(),
      _ => AppTheme.dark(),
    };

    return MaterialApp.router(
      title: 'BooruNova',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: darkTheme,
      themeMode: _resolveThemeMode(themeMode),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('zh'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }

  ThemeMode _resolveThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.midnight:
        return ThemeMode.dark;
    }
  }
}
