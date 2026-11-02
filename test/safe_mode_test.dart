import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// 安全模式（Play 合规项）的守卫。
///
/// 分两组按渠道跑：Play 版首启即安全口径，GitHub 直装版保持既有行为。
class _NullRepo implements BooruRepository {
  @override
  String get serverId => 'test';
  @override
  Future<String?> resolveMediaUrl(String postUrl) async => null;
  @override
  Map<String, String> get mediaHeaders => const {};
  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    seen.add((tags: query.tags, rating: query.rating, page: query.page));
    return const BooruPageResult(posts: [], hasMore: false);
  }

  final List<({String tags, String? rating, int page})> seen = [];
  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async => [];
  @override
  Future<List<String>> fetchTrendingTags({int limit = 20}) async => [];
  @override
  Future<List<BooruPool>> fetchPools({int page = 1, int limit = 20}) async => [];
}

void main() {
  const playHint = '需要 --dart-define=boorunova.play=true';

  group('生效评级的口径（两个渠道都成立）', () {
    test('用户显式选了评级就按他选的来', () {
      for (final settings in const [
        AppSettings(safeMode: true),
        AppSettings(safeMode: false),
      ]) {
        for (final chosen in const ['q', 'e', 's']) {
          expect(effectiveBrowseRating(chosen, settings), chosen);
        }
      }
    });

    test('安全模式关闭且没选评级 → 不带评级（既有行为）', () {
      expect(
        effectiveBrowseRating(null, const AppSettings(safeMode: false)),
        isNull,
      );
      expect(
        effectiveBrowseRating('', const AppSettings(safeMode: false)),
        isNull,
      );
    });

    test('安全模式开启且没选评级 → 只取安全档', () {
      expect(
        effectiveBrowseRating(null, const AppSettings(safeMode: true)),
        's',
      );
    });
  });

  group('设置持久化', () {
    test('缺键时回落到渠道默认，且显式值优先', () {
      // 老设置文件里没有这两个键
      final fromEmpty = AppSettings.fromJson(const {});
      expect(fromEmpty.safeMode, kPlayBuild);
      expect(fromEmpty.ageConfirmed, isFalse);

      expect(AppSettings.fromJson(const {'safeMode': false}).safeMode, isFalse);
      expect(AppSettings.fromJson(const {'safeMode': true}).safeMode, isTrue);
      expect(
        AppSettings.fromJson(const {'ageConfirmed': true}).ageConfirmed,
        isTrue,
      );
    });

    test('toJson / fromJson 往返不丢字段', () {
      const src = AppSettings(safeMode: true, ageConfirmed: true);
      final restored = AppSettings.fromJson(src.toJson());
      expect(restored.safeMode, isTrue);
      expect(restored.ageConfirmed, isTrue);
    });
  });

  group('切站时的评级', () {
    test('switchServer 收到评级就写进 currentRating 并用于请求', () async {
      final repo = _NullRepo();
      final notifier = BooruPageNotifier();
      await notifier.switchServer(repo, rating: 's');
      expect(notifier.currentRating, 's');
      expect(repo.seen.single.rating, 's');
    });

    test('不传评级时沿用当前评级（不把安全档悄悄带过去）', () async {
      final repo = _NullRepo();
      final notifier = BooruPageNotifier();
      // search 在没有 repo 时会直接返回（不记评级），先建立站点
      await notifier.switchServer(repo);
      await notifier.search('cat', rating: 'e');
      await notifier.switchServer(repo);
      expect(notifier.currentRating, 'e');
      expect(repo.seen.last.rating, 'e');
    });
  });

  group('Play 版首启即安全口径', () {
    test('默认 AppSettings 的安全模式是开启的', () {
      expect(const AppSettings().safeMode, isTrue);
      expect(const AppSettings().ageConfirmed, isFalse,
          reason: '未确认年龄之前不该能关掉安全模式');
    }, skip: kPlayBuild ? false : playHint);

    test('默认浏览请求带安全档', () async {
      final repo = _NullRepo();
      final notifier = BooruPageNotifier();
      const settings = AppSettings();
      await notifier.switchServer(repo,
          rating: effectiveBrowseRating(null, settings));
      expect(repo.seen.single.rating, 's');
    }, skip: kPlayBuild ? false : playHint);
  });

  group('GitHub 直装版保持既有行为', () {
    test('默认 AppSettings 的安全模式是关闭的', () {
      expect(const AppSettings().safeMode, isFalse);
    }, skip: kPlayBuild ? playHint : false);
  });
}
