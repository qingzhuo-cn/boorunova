// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:convert';

import 'package:boorunova/boorus/danbooru/danbooru.dart';
import 'package:boorunova/boorus/danbooru/danbooru_repository.dart';
import 'package:boorunova/boorus/e621/e621.dart';
import 'package:boorunova/boorus/e621/e621_repository.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_engine.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';
import 'package:boorunova/boorus/gelbooru_v2/gelbooru_v2.dart';
import 'package:boorunova/boorus/gelbooru_v2/gelbooru_v2_repository.dart';
import 'package:boorunova/boorus/kvs/kvs.dart';
import 'package:boorunova/boorus/kvs/kvs_repository.dart';
import 'package:boorunova/boorus/moebooru/moebooru.dart';
import 'package:boorunova/boorus/moebooru/moebooru_repository.dart';
import 'package:boorunova/boorus/rule34/rule34.dart';
import 'package:boorunova/boorus/rule34/rule34_repository.dart';
import 'package:boorunova/boorus/safebooru/safebooru.dart';
import 'package:boorunova/boorus/safebooru/safebooru_repository.dart';
import 'package:boorunova/boorus/sankaku/sankaku.dart';
import 'package:boorunova/boorus/sankaku/sankaku_repository.dart';
import 'package:boorunova/boorus/shimmie2/shimmie2.dart';
import 'package:boorunova/boorus/shimmie2/shimmie2_repository.dart';
import 'package:boorunova/boorus/zerochan/zerochan.dart';
import 'package:boorunova/boorus/zerochan/zerochan_repository.dart';
import 'package:boorunova/data/repository/hosts/user_hosts_repo.dart';
import 'package:boorunova/foundation/network/dio_factory.dart';
import 'package:boorunova/foundation/network/hosts_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final booruRegistryProvider = Provider<BooruRegistry>((ref) {
  final registry = BooruRegistry();
  _registerDefaults(registry);
  final interceptor = ref.read(hostsInterceptorProvider);
  registry.hostsInterceptor = interceptor;
  // 共享给下载等静态工具类：让下载请求同样命中自定义 hosts 映射
  DioFactory.sharedHostsInterceptor = interceptor;
  return registry;
});

/// 当前活动站点的引擎能力。
///
/// 由 `home_page` 在切站/启动时写入：站点类型在那边才知道（`BooruRepository`
/// 本身不认识能力声明）。UI（搜索页的评级选项、安全模式闸门）读它来决定
/// 「这个入口对当前站点有没有意义」。默认值是最宽松的一组，避免启动早期把
/// 入口误藏起来。
final activeCapabilitiesProvider =
    StateProvider<BooruCapabilities>((ref) => const BooruCapabilities());

final hostsInterceptorProvider = Provider<HostsInterceptor>((ref) {
  final repo = ref.read(userHostsRepoProvider);
  return HostsInterceptor(enabled: false, repo: repo);
});

void _registerDefaults(BooruRegistry registry) {
  registry.register(BooruType.danbooru, () => BooruEngine(
        booru: const Danbooru(),
        repositoryFactory: (dio, {serverId}) =>
            DanbooruRepository(dio: dio, serverId: serverId ?? 'danbooru'),
      ));

  registry.register(BooruType.gelbooruV2, () => BooruEngine(
        booru: const GelbooruV2(),
        repositoryFactory: (dio, {serverId}) => GelbooruV2Repository(
            dio: dio, serverId: serverId ?? 'gelbooru_v2'),
      ));

  registry.register(BooruType.moebooru, () => BooruEngine(
        booru: const Moebooru(),
        repositoryFactory: (dio, {serverId}) =>
            MoebooruRepository(dio: dio, serverId: serverId ?? 'moebooru'),
      ));

  registry.register(BooruType.e621, () => BooruEngine(
        booru: const E621(),
        repositoryFactory: (dio, {serverId}) =>
            E621Repository(dio: dio, serverId: serverId ?? 'e621'),
      ));

  registry.register(BooruType.sankaku, () => BooruEngine(
        booru: const Sankaku(),
        repositoryFactory: (dio, {serverId}) =>
            SankakuRepository(dio: dio, serverId: serverId ?? 'sankaku'),
      ));

  registry.register(BooruType.zerochan, () => BooruEngine(
        booru: const Zerochan(),
        repositoryFactory: (dio, {serverId}) =>
            ZerochanRepository(dio: dio, serverId: serverId ?? 'zerochan'),
      ));

  registry.register(BooruType.rule34, () => BooruEngine(
        booru: const Rule34(),
        repositoryFactory: (dio, {serverId}) =>
            Rule34Repository(dio: dio, serverId: serverId ?? 'rule34'),
      ));

  registry.register(BooruType.safebooru, () => BooruEngine(
        booru: const Safebooru(),
        repositoryFactory: (dio, {serverId}) =>
            SafebooruRepository(dio: dio, serverId: serverId ?? 'safebooru'),
      ));

  // rule34 家族：paheal 系（Shimmie2）与视频站（KVS）
  registry.register(BooruType.shimmie2, () => BooruEngine(
        booru: const Shimmie2(),
        repositoryFactory: (dio, {serverId}) =>
            Shimmie2Repository(dio: dio, serverId: serverId ?? 'shimmie2'),
      ));

  registry.register(BooruType.kvs, () => BooruEngine(
        booru: const KvsTube(),
        repositoryFactory: (dio, {serverId}) =>
            KvsRepository(dio: dio, serverId: serverId ?? 'kvs'),
      ));
}

class BooruRegistry {
  final Map<BooruType, BooruEngine Function()> _factories = {};
  final Map<BooruType, BooruEngine> _singletons = {};

  HostsInterceptor? hostsInterceptor;

  void register(BooruType type, BooruEngine Function() factory) {
    _factories[type] = factory;
  }

  BooruEngine? get(BooruType type) {
    if (!_factories.containsKey(type)) return null;
    if (!_singletons.containsKey(type)) {
      _singletons[type] = _factories[type]!();
    }
    return _singletons[type];
  }

  static const _probePaths = <BooruType, String>{
    BooruType.danbooru: '/posts.json?limit=1',
    BooruType.moebooru: '/post.json?limit=1',
    BooruType.e621: '/posts.json?limit=1',
    BooruType.sankaku: '/post/index.json?limit=1',
    BooruType.zerochan: '/?json=1',
    BooruType.gelbooruV2: '/index.php?page=dapi&s=post&q=index&json=1&limit=1',
    BooruType.rule34: '/index.php?page=dapi&s=post&q=index&json=1&limit=1',
    BooruType.safebooru: '/index.php?page=dapi&s=post&q=index&json=1&limit=1',
    // paheal 系：图库首页（老分支没有 JSON 接口，用列表页探活）
    BooruType.shimmie2: '/post/list/1',
    // 视频站（KVS）：最新更新页
    BooruType.kvs: '/latest-updates/1/',
  };

  /// 探测时的响应体特征校验：**每个类型要求全部标记都出现**。
  ///
  /// 只看状态码会把站点判错：实测 safebooru.org 的 `/?json=1` 返回 200
  /// （HTML 首页），排在前面的 zerochan 因此会把 safebooru 认成自己。
  ///
  /// 标记取自**各自 parser 真正读取的键**，而不是随手挑一个：
  /// - 单个 `"id"` 太弱——任何 JSON API 都可能有它。此前探测走 JSON 解析、
  ///   特征永远匹配不上，所以「过弱」没有后果；修好解析后（取原始字符串）
  ///   弱特征会真的**误认**陌生站点，于是必须收紧（AUDIT M3 的遗留项）。
  /// - 多个标记是 AND：命中要同时满足，误报面小得多。
  static const _probeSignatures = <BooruType, List<String>>{
    // danbooru 用 tag_string + preview_file_url（moebooru/sankaku 用 preview_url）
    BooruType.danbooru: ['"tag_string"', '"preview_file_url"'],
    // moebooru/konachan 的 /post.json
    BooruType.moebooru: ['"preview_url"', '"sample_url"'],
    BooruType.e621: ['"posts"'],
    BooruType.sankaku: ['"file_url"', '"sample_url"', '"preview_url"'],
    BooruType.zerochan: ['"items"'],
    // 这三个的探测路径带 json=1（与仓库实际请求的形态一致），返回的是
    // JSON；此前写 '<post'（XML 特征）→ 按类型探测**必然失败**，只靠
    // scanner 的域名捷径兜底。改用 JSON DAPI 里稳定存在的键。
    // DAPI 的 JSON 里 preview_url 与 file_url 同时存在
    BooruType.gelbooruV2: ['"preview_url"', '"file_url"'],
    BooruType.rule34: ['"preview_url"', '"file_url"'],
    BooruType.safebooru: ['"preview_url"', '"file_url"'],
    BooruType.shimmie2: ['/post/view/'],
    BooruType.kvs: ['/videos/'],
  };

  Future<BooruType?> probe(String baseUrl, {BooruType? singleType}) async {
    final url = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final dio = DioFactory.createProbe(hostsInterceptor: hostsInterceptor);

    // 先按域名判：命中的话根本不用发请求（也避免把 safebooru.org 认成 zerochan
    // ——它的 /?json=1 确实返回 200，只看状态码必然误判）。
    if (singleType == null) {
      final byDomain = scanner(url);
      if (byDomain != null) return byDomain;
    }

    final types = singleType != null
        ? [singleType]
        : _probePaths.keys.toList(growable: false);

    // 全部并发。此前串行 × 单条 15s 超时，10 个引擎最坏 ≈ 150s ——
    // 添加一个站点要站着等两分半钟。并发后上界是**最慢的一条**（15s），
    // 正常站点通常 1s 内出结果。
    //
    // 取结果时仍按 _probePaths 的声明顺序选优先级最高的命中，而不是
    // 「谁先返回谁赢」：顺序是刻意排的（例如 safebooru 的 /?json=1 会返回
    // 200 的 HTML 首页，让 zerochan 抢先命中就会认错站）。
    // 并发**发起**、按优先级**收割**：
    // - 并发发起：最坏耗时是「最慢的一条」，而不是十条之和；
    // - 按序收割：第 k 条命中就返回，**不等** k 之后那些还没回来的请求。
    //   此前是 Future.wait 全收完再看，于是只要有任何一条挂到 15s 超时，
    //   即使第 0 条 200ms 就命中了，用户也要站着等满 15s。
    //
    // 不能「谁先返回谁赢」：顺序是刻意排的（safebooru 的 /?json=1 会返回 200
    // 的 HTML 首页，让 zerochan 抢先命中就会认错站）。
    final pending = [for (final type in types) _matches(dio, url, type)];
    for (var i = 0; i < types.length; i++) {
      if (await pending[i]) return types[i];
    }
    return null;
  }

  /// 单条探测：GET 该类型的探测路径，再用 [matchesProbeResponse] 判定。
  ///
  /// **必须用 ResponseType.plain**：特征串是形如 `"preview_url"` 的**带引号** JSON
  /// 键。用默认的 JSON 解析时 dio 会把响应解成 Map/List，`toString()` 出来的
  /// 是 `{preview_url: x}` —— 引号没了，特征永远匹配不上，于是「按类型探测」
  /// 对**所有** JSON 引擎静默失效（只有域名捷径还在兜底，自建站必判不出来）。
  /// 纯函数单测喂的是原始字符串，所以这个坑一直没被现有的探测测试发现。
  Future<bool> _matches(Dio dio, String url, BooruType type) async {
    final path = _probePaths[type];
    if (path == null) return false;
    try {
      final response = await dio.get(
        '$url$path',
        options: Options(responseType: ResponseType.plain),
      );
      return matchesProbeResponse(
        response.statusCode ?? 0,
        response.data?.toString() ?? '',
        type,
      );
    } catch (_) {
      // 连接失败 / 超时 = 不匹配，不中断其余并发探测
      return false;
    }
  }

  /// 纯函数：状态码 + 响应体特征 → 是否算命中。抽出来是为了能单测
  /// （探测逻辑里有域名顺序陷阱，靠真机试错代价太高）。
  static bool matchesProbeResponse(int statusCode, String body, BooruType type) {
    if (statusCode != 200) return false;
    final markers = _probeSignatures[type];
    if (markers == null) return true;
    // AND：全部标记都要出现。任一缺失就当没命中——宁可让用户手选类型，
    // 也不要把陌生站点认成某个引擎（认错了后续请求全会打错端点）。
    return markers.every(body.contains);
  }

  BooruType? scanner(String url) {
    final host = _hostOf(url);
    if (host.isEmpty) return null;
    // 域名表来自 site_presets（出厂预置的唯一数据面）。Play 版该表为空，
    // 所有 URL 都走 probe()——探测特征是协议层字符串，不含站点名。
    for (final entry in kPresetDomains.entries) {
      final domain = entry.value;
      // 按 host 的边界匹配（精确域名或其子域），不用 contains：
      // `zerochan.net.evil.com` 含 "zerochan.net"，contains 会把它当成
      // zerochan，等于把域名判定交给攻击者。
      if (host == domain || host.endsWith('.$domain')) return entry.key;
    }
    return null;
  }

  /// 从用户输入里取 host：允许没写 scheme（BYO-Server 下用户手填 URL 是
  /// 常态），并丢掉端口与路径。
  static String _hostOf(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    final withScheme =
        trimmed.contains('://') ? trimmed : 'https://$trimmed';
    return (Uri.tryParse(withScheme)?.host ?? '').toLowerCase();
  }

  bool isRegistered(BooruType type) => _factories.containsKey(type);

  List<BooruType> get registeredTypes => _factories.keys.toList();

  Dio createDio(BooruType type,
      {String? baseUrl, String? login, String? apiKey}) {
    final engine = get(type);
    if (engine == null) throw Exception('Engine not registered: $type');

    final headers = Map<String, dynamic>.from(engine.booru.defaultHeaders);

    if (login != null && apiKey != null) {
      final basic = base64Encode(utf8.encode('$login:$apiKey'));
      headers['Authorization'] = 'Basic $basic';
    }

    // 兜底域名来自 site_presets；Play 版它是空串，此时**必须**由调用方
    // 提供 baseUrl（BYO：应用不内置任何来源）。这里明确抛错，而不是让
    // 空 baseUrl 拼出相对路径、最后在某个站点上以一句莫名的 404 收场。
    final resolvedBaseUrl = baseUrl ?? engine.booru.baseUrl;
    if (resolvedBaseUrl.isEmpty) {
      throw StateError(
          '缺少 baseUrl：本构建不内置任何站点，必须由服务器配置提供');
    }

    final dio = DioFactory.create(
      baseUrl: resolvedBaseUrl,
      headers: headers,
      hostsInterceptor: hostsInterceptor,
    );
    // 凭据的注入方式因站而异：danbooru / e621 认 HTTP Basic（上面已写成头），
    // gelbooru / rule34 / safebooru 认 query 参数 api_key + user_id。
    // 把凭据放进 options.extra，由引擎按自己的方式取用——此前只发 Basic，
    // 那三个站即使用户填了凭据也永远 401。
    dio.options.extra = <String, dynamic>{
      if (login != null && login.isNotEmpty) 'authLogin': login,
      if (apiKey != null && apiKey.isNotEmpty) 'authApiKey': apiKey,
    };
    return dio;
  }

  BooruRepository createRepository(BooruType type,
      {String? baseUrl, String? serverId, String? login, String? apiKey}) {
    final engine = get(type);
    if (engine == null) throw Exception('Engine not registered: $type');
    final dio = createDio(type, baseUrl: baseUrl, login: login, apiKey: apiKey);
    return engine.repositoryFactory(dio, serverId: serverId);
  }
}
