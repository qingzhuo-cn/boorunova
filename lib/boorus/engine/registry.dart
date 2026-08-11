import 'dart:convert';

import 'package:boorunova/boorus/danbooru/danbooru.dart';
import 'package:boorunova/boorus/danbooru/danbooru_repository.dart';
import 'package:boorunova/boorus/e621/e621.dart';
import 'package:boorunova/boorus/e621/e621_repository.dart';
import 'package:boorunova/boorus/engine/booru_engine.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/gelbooru_v2/gelbooru_v2.dart';
import 'package:boorunova/boorus/gelbooru_v2/gelbooru_v2_repository.dart';
import 'package:boorunova/boorus/moebooru/moebooru.dart';
import 'package:boorunova/boorus/moebooru/moebooru_repository.dart';
import 'package:boorunova/boorus/rule34/rule34.dart';
import 'package:boorunova/boorus/rule34/rule34_repository.dart';
import 'package:boorunova/boorus/safebooru/safebooru.dart';
import 'package:boorunova/boorus/safebooru/safebooru_repository.dart';
import 'package:boorunova/boorus/sankaku/sankaku.dart';
import 'package:boorunova/boorus/sankaku/sankaku_repository.dart';
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
  return registry;
});

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
  };

  Future<BooruType?> probe(String baseUrl, {BooruType? singleType}) async {
    final url = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final dio = DioFactory.createProbe(hostsInterceptor: hostsInterceptor);

    final types = singleType != null ? [singleType] : _probePaths.keys;
    for (final type in types) {
      final path = _probePaths[type];
      if (path == null) continue;
      try {
        final response = await dio.get('$url$path');
        if (response.statusCode == 200) {
          return type;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  BooruType? scanner(String url) {
    final lower = url.toLowerCase();
    final defaultUrls = <BooruType, String>{
      BooruType.danbooru: 'danbooru.donmai.us',
      BooruType.gelbooruV2: 'gelbooru.com',
      BooruType.moebooru: 'yande.re',
      BooruType.e621: 'e621.net',
      BooruType.sankaku: 'sankakucomplex.com',
      BooruType.zerochan: 'zerochan.net',
      BooruType.rule34: 'rule34.xxx',
      BooruType.safebooru: 'safebooru.org',
    };
    for (final entry in defaultUrls.entries) {
      if (lower.contains(entry.value)) return entry.key;
    }
    return null;
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

    return DioFactory.create(
      baseUrl: baseUrl ?? engine.booru.baseUrl,
      headers: headers,
      hostsInterceptor: hostsInterceptor,
    );
  }

  BooruRepository createRepository(BooruType type,
      {String? baseUrl, String? serverId, String? login, String? apiKey}) {
    final engine = get(type);
    if (engine == null) throw Exception('Engine not registered: $type');
    final dio = createDio(type, baseUrl: baseUrl, login: login, apiKey: apiKey);
    return engine.repositoryFactory(dio, serverId: serverId);
  }
}
