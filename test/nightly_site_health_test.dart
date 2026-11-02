import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/registry.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';
import 'package:boorunova/foundation/network/dio_factory.dart';
import 'package:flutter_test/flutter_test.dart';

/// 真站点协议核验（OPT §6.2）。
///
/// **默认跳过**：只在 nightly workflow（手动触发、海外 runner）里跑。
/// 本机/普通 CI 不碰外网，保证 `flutter test` 依然离线可绿。
///
/// 断言只针对**协议特征**（端点还在不在、响应还符不符合该引擎的特征串），
/// 不断言任何内容、不落盘任何数据。目的很单纯：站点改版时别静默失效——
/// 用户那边表现为「这个站突然刷不出来了」，而我们能提前一晚知道。
const bool kNightly = bool.fromEnvironment('boorunova.nightly');

const String _skipReason =
    'nightly only：flutter test --dart-define=boorunova.nightly=true';

/// 站点可达性的一句话描述，用于把「被墙/被 Cloudflare 挡」和「协议改版」分开。
///
/// 没有它的话，夜里看日志的人分不清该去找网络还是该去改特征串——本机实测
/// （DNS 污染环境）多数失败其实是前者。
Future<String> _reachability(String baseUrl) async {
  final dio = DioFactory.createProbe();
  // 探测用的 dio 只把 200 当成功；这里要看**状态码本身**，所以放开。
  dio.options.validateStatus = (_) => true;
  // 复测是**诊断**，不需要按正式探测的 15s 等：十个站全不通时，这一项会把
  // 夜检时长翻倍。8s 足够区分「有响应」和「连不上」。
  dio.options.connectTimeout = const Duration(seconds: 8);
  dio.options.receiveTimeout = const Duration(seconds: 8);
  try {
    final response = await dio.get<Object>(baseUrl);
    return 'HTTP ${response.statusCode}';
  } catch (e) {
    return '请求失败（未拿到响应）：$e';
  } finally {
    dio.close(force: true);
  }
}

void main() {
  const probes = kSitePresets;

  test('预置站点列表非空（防止夜检空转）', () {
    // 这条平时不加 nightly skip：纯自检，离线也能跑。
    // 但 **Play 版**把站点数据在编译期清空（kPlayBuild），那时列表本来就是空的
    // ——夜检只跑普通渠道构建，所以这里按渠道跳过，而不是断言失败。
    expect(probes, isNotEmpty,
        reason: '夜里一个站点都不检查，等于没有核验');
    expect(
      probes.map((p) => p.baseUrl).where((u) => u.isNotEmpty).length,
      probes.length,
      reason: '每个预置都要有可用于核验的域名',
    );
  }, skip: kPlayBuild ? 'Play 版站点数据编译期清空（夜检只跑普通渠道）' : null);

  for (final preset in probes) {
    group('${preset.name}（${preset.type.value}）', () {
      test('域名捷径不会把它认成别的类型', () {
        // 别名站（TBIB / Realbooru 这类 gelbooru 克隆）在域名表里**没有**条目，
        // scanner 返回 null 是正常的——它们本来就该靠协议探测识别。
        // 真正不能接受的是「认成别的类型」：那会让用户连到错的端点上。
        final byDomain = BooruRegistry().scanner(preset.baseUrl);
        expect(
          byDomain,
          anyOf(isNull, preset.type),
          reason: '域名捷径给出了错误的类型：$byDomain',
        );
      }, skip: kNightly ? null : _skipReason);

      test('按类型实时探测仍能命中协议特征', () async {
        // singleType：跳过域名捷径，**真的发请求**验证特征串
        BooruType? found;
        Object? failure;
        try {
          found = await BooruRegistry().probe(
            preset.baseUrl,
            singleType: preset.type,
          );
        } catch (e) {
          failure = e;
        }

        expect(failure, isNull, reason: '探测抛错（网络栈问题）：$failure');

        // 命中不了时再问一次「站点到底可达吗」，把结论写进失败信息：
        // 状态码非 200 基本就是被挡/被墙，而不是协议改版。
        var reachability = '（未测：已命中）';
        if (found != preset.type) {
          reachability = await _reachability(preset.baseUrl);
        }

        expect(
          found,
          preset.type,
          reason: '站点可达性：$reachability。若不可达/非 200，那是网络或反爬'
              '问题，不是协议改版；若 200，才考虑按新的响应形状更新特征串',
        );
      }, skip: kNightly ? null : _skipReason);
    });
  }
}
