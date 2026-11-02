import 'dart:io';

import 'package:boorunova/boorus/danbooru/danbooru.dart';
import 'package:boorunova/boorus/danbooru/danbooru_repository.dart';
import 'package:boorunova/boorus/e621/e621.dart';
import 'package:boorunova/boorus/e621/e621_repository.dart';
import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_engine.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/registry.dart';
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
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 能力声明的**诚实性**测试。
///
/// 能力标志的唯一价值是「UI 按它增减入口」。一旦声明与实现不符，就变成
/// 「声明支持评级过滤、实际忽略评级」这类静默错误——用户在安全模式下照样
/// 拿到限制级内容，而界面上一切正常。所以这里对着真实仓库断言：
/// 声明的能力必须在**请求**上看得见（或看不见）。
class _FakeSite {
  _FakeSite._(this._server);

  static Future<_FakeSite> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final site = _FakeSite._(server);
    server.listen((request) {
      site.requests.add(request.uri);
      // 一律回 JSON 空数组：所有仓库对「形状不对」都是降级为空结果，
      // 而我们要断言的是**请求**，不是解析。
      request.response.headers.contentType = ContentType.json;
      request.response.write('[]');
      request.response.close();
    });
    return site;
  }

  final HttpServer _server;
  final List<Uri> requests = [];

  String get baseUrl => 'http://127.0.0.1:${_server.port}';
  Future<void> close() => _server.close(force: true);
}

/// 一条被断言的引擎：能力声明 + 一个用假站点构造的仓库 + 是否存在「评级」参数。
typedef EngineCase = ({
  String name,
  BooruCapabilities capabilities,
  BaseBooruRepository Function(Dio dio) build,
});

List<EngineCase> _engines() => [
      (
        name: 'danbooru',
        capabilities: const Danbooru().capabilities,
        build: (dio) => DanbooruRepository(dio: dio, serverId: 's'),
      ),
      (
        name: 'e621',
        capabilities: const E621().capabilities,
        build: (dio) => E621Repository(dio: dio, serverId: 's'),
      ),
      (
        name: 'gelbooru_v2',
        capabilities: const GelbooruV2().capabilities,
        build: (dio) => GelbooruV2Repository(dio: dio, serverId: 's'),
      ),
      (
        name: 'moebooru',
        capabilities: const Moebooru().capabilities,
        build: (dio) => MoebooruRepository(dio: dio, serverId: 's'),
      ),
      (
        name: 'rule34',
        capabilities: const Rule34().capabilities,
        build: (dio) => Rule34Repository(dio: dio, serverId: 's'),
      ),
      (
        name: 'safebooru',
        capabilities: const Safebooru().capabilities,
        build: (dio) => SafebooruRepository(dio: dio, serverId: 's'),
      ),
      (
        name: 'sankaku',
        capabilities: const Sankaku().capabilities,
        build: (dio) => SankakuRepository(dio: dio, serverId: 's'),
      ),
      (
        name: 'zerochan',
        capabilities: const Zerochan().capabilities,
        build: (dio) => ZerochanRepository(dio: dio, serverId: 's'),
      ),
      (
        name: 'shimmie2',
        capabilities: const Shimmie2().capabilities,
        build: (dio) => Shimmie2Repository(dio: dio, serverId: 's'),
      ),
      (
        name: 'kvs',
        capabilities: const KvsTube().capabilities,
        build: (dio) => KvsRepository(dio: dio, serverId: 's'),
      ),
    ];

/// 请求里是否出现了评级过滤。各站写法不同（rating:g / rating:safe / rating:q…），
/// 所以只看 `rating` 这个词——它正是「站点认不认评级」的分界。
bool _hasRatingFilter(Uri uri) =>
    uri.toString().toLowerCase().contains('rating');

void main() {
  group('ratingFilter 声明与实际请求一致', () {
    test('声明支持 → 带评级的查询必须发出评级过滤', () async {
      for (final engine in _engines().where((e) => e.capabilities.ratingFilter)) {
        final site = await _FakeSite.start();
        addTearDown(site.close);
        final repo = engine.build(Dio(BaseOptions(baseUrl: site.baseUrl)));

        await repo.searchPosts(const BooruQuery(tags: 'cat', rating: 's'));

        expect(site.requests, isNotEmpty, reason: '${engine.name} 没发请求');
        expect(site.requests.any(_hasRatingFilter), isTrue,
            reason: '${engine.name} 声明支持评级过滤，请求里却没有 rating');
      }
    });

    test('声明不支持 → 带评级的查询里不能出现评级过滤（否则是在骗用户）', () async {
      for (final engine in _engines().where((e) => !e.capabilities.ratingFilter)) {
        final site = await _FakeSite.start();
        addTearDown(site.close);
        final repo = engine.build(Dio(BaseOptions(baseUrl: site.baseUrl)));

        await repo.searchPosts(const BooruQuery(tags: 'cat', rating: 'e'));

        expect(site.requests, isNotEmpty, reason: '${engine.name} 没发请求');
        expect(site.requests.any(_hasRatingFilter), isFalse,
            reason: '${engine.name} 声明不支持评级过滤，却发了 rating 参数');
      }
    });
  });

  group('auth 声明与实际凭据消费一致', () {
    /// 凭据由 registry 放进 options.extra，仓库自行决定怎么用。
    const extra = <String, dynamic>{
      'authLogin': 'user1',
      'authApiKey': 'secret1',
    };

    test('声明需要凭据 → 配置后请求里必须出现凭据参数', () async {
      // danbooru / e621 的凭据是 registry 加的 Authorization 头，不在仓库层
      // 体现，故这里只覆盖用查询参数的那几个。
      const withParamAuth = {'gelbooru_v2', 'moebooru', 'rule34', 'safebooru'};
      for (final engine
          in _engines().where((e) => withParamAuth.contains(e.name))) {
        expect(engine.capabilities.auth, isTrue,
            reason: '${engine.name} 用了凭据参数，就该声明 auth: true');

        final site = await _FakeSite.start();
        addTearDown(site.close);
        final repo = engine.build(
          Dio(BaseOptions(baseUrl: site.baseUrl, extra: extra)),
        );

        await repo.searchPosts(const BooruQuery(tags: 'cat'));

        final uri = site.requests.single.toString();
        expect(uri.contains('api_key=secret1') || uri.contains('login=user1'),
            isTrue,
            reason: '${engine.name} 声明 auth 但没把凭据带进请求：$uri');
      }
    });

    test('声明不需要凭据 → 即便配置了也不该出现在请求里', () async {
      const noAuth = {'sankaku', 'zerochan', 'shimmie2', 'kvs'};
      for (final engine in _engines().where((e) => noAuth.contains(e.name))) {
        expect(engine.capabilities.auth, isFalse, reason: engine.name);

        final site = await _FakeSite.start();
        addTearDown(site.close);
        final repo = engine.build(
          Dio(BaseOptions(baseUrl: site.baseUrl, extra: extra)),
        );

        await repo.searchPosts(const BooruQuery(tags: 'cat'));

        final uri = site.requests.map((u) => u.toString()).join(' ');
        expect(uri.contains('api_key='), isFalse, reason: engine.name);
        expect(uri.contains('login='), isFalse, reason: engine.name);
        expect(uri.contains('password_hash='), isFalse, reason: engine.name);
      }
    });
  });

  group('pools 声明与实际实现一致', () {
    test('声明不支持 → fetchPools 不发请求且返回空', () async {
      for (final engine in _engines().where((e) => !e.capabilities.pools)) {
        final site = await _FakeSite.start();
        addTearDown(site.close);
        final repo = engine.build(Dio(BaseOptions(baseUrl: site.baseUrl)));

        final pools = await repo.fetchPools();

        expect(pools, isEmpty, reason: engine.name);
        expect(site.requests, isEmpty,
            reason: '${engine.name} 声明不支持图集，不该为它发请求');
      }
    });
  });


  group('auth 声明与实际凭据消费一致（registry 层级）', () {
    /// danbooru / e621 的凭据是 registry 加的 `Authorization: Basic`，
    /// 不在仓库层体现——这两条补上，`auth` 标志对全部 6 个引擎都验过。
    test('danbooru / e621：填了凭据就必须带 Authorization 头', () {
      for (final entry in <String, BooruEngine Function()>{
            'danbooru': () => BooruEngine(
                  booru: const Danbooru(),
                  repositoryFactory: (dio, {serverId}) =>
                      DanbooruRepository(dio: dio, serverId: serverId ?? 's'),
                ),
            'e621': () => BooruEngine(
                  booru: const E621(),
                  repositoryFactory: (dio, {serverId}) =>
                      E621Repository(dio: dio, serverId: serverId ?? 's'),
                ),
          }.entries) {
        final registry = BooruRegistry();
        final type =
            entry.key == 'danbooru' ? BooruType.danbooru : BooruType.e621;
        registry.register(type, entry.value);
        expect(registry.get(type)!.booru.capabilities.auth, isTrue,
            reason: '${entry.key} 会用凭据，就该声明 auth: true');

        final dio = registry.createDio(
          type,
          baseUrl: 'https://example.test',
          login: 'user1',
          apiKey: 'secret1',
        );
        final auth = dio.options.headers['Authorization'];
        expect(auth, isNotNull, reason: '${entry.key} 没带 Authorization');
        // Basic base64('user1:secret1')
        expect(auth.toString(), startsWith('Basic '));
      }
    });
  });

  group('安全模式闸门', () {
    test('安全模式 + 不支持评级过滤 → 禁止浏览', () {
      expect(
        safeModeBlocksBrowsing(
          safeMode: true,
          capabilities: const BooruCapabilities(ratingFilter: false),
        ),
        isTrue,
      );
    });

    test('支持评级过滤、或安全模式关闭 → 正常浏览', () {
      expect(
        safeModeBlocksBrowsing(
          safeMode: true,
          capabilities: const BooruCapabilities(ratingFilter: true),
        ),
        isFalse,
      );
      expect(
        safeModeBlocksBrowsing(
          safeMode: false,
          capabilities: const BooruCapabilities(ratingFilter: false),
        ),
        isFalse,
      );
    });
  });
}
