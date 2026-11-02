import 'package:boorunova/boorus/danbooru/danbooru.dart';
import 'package:boorunova/boorus/e621/e621.dart';
import 'package:boorunova/boorus/engine/booru_engine.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/registry.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';
import 'package:boorunova/boorus/moebooru/moebooru.dart';
import 'package:boorunova/boorus/safebooru/safebooru.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/onboarding_state.dart';
import 'package:boorunova/presentation/screens/server/booru_site_template.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 出厂预置的唯一数据面 + 编译期开关的守卫。
///
/// 分两组：
/// - **默认构建**（GitHub 直装版）：预置齐全，且所有消费方确实读的是同一份数据；
/// - **Play 构建**：预置整体为空。这组只在 `--dart-define=boorunova.play=true`
///   下运行（`flutter test --dart-define=boorunova.play=true test/site_presets_test.dart`），
///   否则自动 skip——因为 [kPlayBuild] 是编译期常量，运行时改不了。
void main() {
  const playHint = '需要 --dart-define=boorunova.play=true';

  group('默认构建：预置齐全且只有一个来源', () {
    test('模板/计划模板/域名表都不为空', () {
      expect(kSitePresets, hasLength(16));
      expect(kPlannedSitePresets, hasLength(2));
      expect(kPresetDomains, hasLength(10));
    }, skip: kPlayBuild ? playHint : false);

    test('BooruSiteTemplate 只是给预置补图标，数据同源', () {
      expect(BooruSiteTemplate.all, hasLength(kSitePresets.length));
      for (var i = 0; i < kSitePresets.length; i++) {
        final preset = kSitePresets[i];
        final template = BooruSiteTemplate.all[i];
        expect(template.name, preset.name);
        expect(template.baseUrl, preset.baseUrl);
        expect(template.type, preset.type);
        expect(template.description, preset.description);
      }
    }, skip: kPlayBuild ? playHint : false);

    test('引擎默认域名 == 预置常量（不是各自抄一份）', () {
      expect(const Danbooru().baseUrl, kDanbooruBaseUrl);
      expect(const E621().baseUrl, kE621BaseUrl);
      expect(const Moebooru().baseUrl, kMoebooruBaseUrl);
      expect(const Safebooru().baseUrl, kSafebooruBaseUrl);
    }, skip: kPlayBuild ? playHint : false);

    test('引导默认勾选 = safebooru 一个', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(onboardingProvider).selected,
          kPresetOnboardingSelection);
      expect(kPresetOnboardingSelection, {BooruType.safebooru});
    }, skip: kPlayBuild ? playHint : false);

    test('探测捷径按 host 边界命中', () {
      final registry = BooruRegistry();
      expect(registry.scanner('https://danbooru.donmai.us/x'),
          BooruType.danbooru);
      expect(registry.scanner('https://zerochan.net.evil.com'), isNull);
    }, skip: kPlayBuild ? playHint : false);

    test('界面占位示例不含真实站点域名', () {
      // 这条对两个渠道都成立：BYO 模式下把某个站点当成「默认答案」没有意义，
      // 而 Play 版更不能出现站点名。
      const domains = [
        'donmai.us',
        'gelbooru.com',
        'safebooru.org',
        'yande.re',
        'e621.net',
        'sankakucomplex',
        'zerochan.net',
        'rule34',
        'paheal.net',
        'rule34video.com',
      ];
      final hints = [
        T.serverUrlHint,
        T.urlHint,
        T.domainHint,
        T.hostsEditorExample,
      ];
      for (final hint in hints) {
        for (final domain in domains) {
          expect(hint.contains(domain), isFalse,
              reason: '提示文案里出现了站点域名：$hint');
        }
      }
    });
  });

  group('Play 构建：零预置', () {
    test('模板/计划模板/域名表/引导勾选全部为空', () {
      expect(kSitePresets, isEmpty);
      expect(kPlannedSitePresets, isEmpty);
      expect(kPresetDomains, isEmpty);
      expect(kPresetOnboardingSelection, isEmpty);
      expect(BooruSiteTemplate.all, isEmpty);
      expect(BooruSiteTemplate.planned, isEmpty);
    }, skip: kPlayBuild ? false : playHint);

    test('引擎默认域名是空串（必须由服务器配置提供）', () {
      expect(kDanbooruBaseUrl, isEmpty);
      expect(kE621BaseUrl, isEmpty);
      expect(kGelbooruV2BaseUrl, isEmpty);
      expect(const Danbooru().baseUrl, isEmpty);
      expect(const E621().baseUrl, isEmpty);
    }, skip: kPlayBuild ? false : playHint);

    test('域名捷径置空：全部 URL 走协议探测', () {
      final registry = BooruRegistry();
      expect(registry.scanner('https://danbooru.donmai.us'), isNull);
      expect(registry.scanner('https://e621.net'), isNull);
    }, skip: kPlayBuild ? false : playHint);

    test('缺 baseUrl 时明确抛错，而不是拼出相对路径', () {
      final registry = BooruRegistry()
        ..register(
          BooruType.danbooru,
          () => BooruEngine(
            booru: const Danbooru(),
            repositoryFactory: (dio, {serverId}) =>
                throw UnimplementedError(),
          ),
        );
      expect(() => registry.createDio(BooruType.danbooru), throwsStateError);
    }, skip: kPlayBuild ? false : playHint);

    test('引擎显示名中性化：UI 里不出现站点名', () {
      const siteNames = ['e621', 'Rule34', 'Safebooru', 'Zerochan', 'Sankaku'];
      for (final name in kNeutralEngineNames.values) {
        for (final site in siteNames) {
          expect(name.toLowerCase().contains(site.toLowerCase()), isFalse,
              reason: '中性引擎名里出现了站点名：$name');
        }
      }
    }, skip: kPlayBuild ? false : playHint);
  });
}
