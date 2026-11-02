import 'dart:io';

import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/presentation/provider/server_health.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 关掉测试绑定那个「一律回 400」的 HttpClient 替身：本文件要真连本地
/// HttpServer（同 test/download_http_test.dart 的做法）。
class _RealHttpBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

/// 本地假站点：记录请求并按 responder 应答。
class _FakeSite {
  _FakeSite._(this._server);

  static Future<_FakeSite> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final site = _FakeSite._(server);
    server.listen((request) {
      site.requests.add(request.uri);
      site.responder(request);
    });
    return site;
  }

  final HttpServer _server;
  final List<Uri> requests = [];
  late void Function(HttpRequest request) responder;

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Future<void> close() => _server.close(force: true);
}

Dio _dio(_FakeSite site) => Dio(BaseOptions(baseUrl: site.baseUrl));

BooruServer _server(String id, String baseUrl) => BooruServer(
      id: id,
      name: 'site-$id',
      baseUrl: baseUrl,
      type: BooruType.danbooru,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  _RealHttpBinding();

  group('状态判定（纯函数，穷举各态）', () {
    test('2xx/3xx 且在阈值内 → ok，并带上延迟', () {
      final health = ServerHealthProbe.classify(
        httpStatus: 200,
        elapsed: const Duration(milliseconds: 120),
      );
      expect(health.status, ServerHealthStatus.ok);
      expect(health.latencyMs, 120);
      expect(health.isHealthy, isTrue);
      expect(
        ServerHealthProbe.classify(httpStatus: 301).status,
        ServerHealthStatus.ok,
        reason: '重定向说明站点活着',
      );
    });

    test('超过慢阈值 → slow（但仍算健康）', () {
      final health = ServerHealthProbe.classify(
        httpStatus: 200,
        elapsed: ServerHealthProbe.slowThreshold,
      );
      expect(health.status, ServerHealthStatus.slow);
      expect(health.isHealthy, isTrue, reason: '慢 ≠ 不可用');
    });

    test('401/403 → rejected（Cloudflare/需凭据的形态）', () {
      for (final code in const [401, 403]) {
        expect(
          ServerHealthProbe.classify(httpStatus: code).status,
          ServerHealthStatus.rejected,
          reason: 'HTTP $code',
        );
      }
    });

    test('其余 4xx/5xx → error', () {
      for (final code in const [404, 429, 500, 502]) {
        expect(
          ServerHealthProbe.classify(httpStatus: code).status,
          ServerHealthStatus.error,
          reason: 'HTTP $code',
        );
      }
    });

    test('异常或没有状态码 → unreachable', () {
      expect(
        ServerHealthProbe.classify(error: StateError('boom')).status,
        ServerHealthStatus.unreachable,
      );
      expect(
        ServerHealthProbe.classify().status,
        ServerHealthStatus.unreachable,
        reason: '没有状态码就等于没连上',
      );
    });
  });

  group('真实请求：健康检查最小可用', () {
    late _FakeSite site;

    setUp(() async {
      site = await _FakeSite.start();
      site.responder = (request) {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('ok');
        request.response.close();
      };
    });

    tearDown(() async {
      await site.close();
    });

    test('200 → ok，且只发一次请求', () async {
      final health = await ServerHealthProbe.check(
        site.baseUrl,
        dio: _dio(site),
      );
      expect(health.status, ServerHealthStatus.ok);
      expect(health.httpStatus, 200);
      expect(health.latencyMs, isNotNull);
      expect(site.requests, hasLength(1));
    });

    test('403 → rejected（不是笼统的「连不上」）', () async {
      site.responder = (request) {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.close();
      };

      final health = await ServerHealthProbe.check(
        site.baseUrl,
        dio: _dio(site),
      );

      expect(health.status, ServerHealthStatus.rejected);
      expect(health.httpStatus, 403);
    });

    test('端口没人监听 → unreachable', () async {
      final dead = await _FakeSite.start();
      final deadUrl = dead.baseUrl;
      await dead.close();

      final health = await ServerHealthProbe.check(deadUrl);

      expect(health.status, ServerHealthStatus.unreachable);
    });

    test('只等响应头，不等正文：正文永不结束也要立刻判定', () async {
      // 服务端发出响应头 + 一个字节后**既不结束也不关闭**。
      // 若实现是「把正文读完才算完」（ResponseType.plain 就是），这里会一直
      // 等到超时 → 得到 unreachable，本用例就会失败。
      site.responder = (request) async {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.text;
        request.response.add(const [1]);
        await request.response.flush();
        // 之后什么都不做：正文没有结束标记
      };

      final watch = Stopwatch()..start();
      final health = await ServerHealthProbe.check(
        site.baseUrl,
        dio: _dio(site),
        timeout: const Duration(seconds: 3),
      );
      final elapsed = watch.elapsed;

      expect(health.status, ServerHealthStatus.ok,
          reason: '响应头到了就算连得上');
      expect(elapsed < const Duration(seconds: 2), isTrue,
          reason: '不该等正文结束（实测耗时 $elapsed）');
    });
  });

  group('结果按站点记录', () {
    late _FakeSite site;

    setUp(() async {
      site = await _FakeSite.start();
      site.responder = (request) {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('ok');
        request.response.close();
      };
    });

    tearDown(() async {
      await site.close();
    });

    test('check 写入该站点、checkAll 覆盖全部', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(serverHealthProvider.notifier);
      final a = _server('a', site.baseUrl);
      final b = _server('b', site.baseUrl);

      expect(container.read(serverHealthProvider), isEmpty);
      await notifier.check(a, dio: _dio(site));
      expect(container.read(serverHealthProvider)['a']!.status,
          ServerHealthStatus.ok);
      expect(container.read(serverHealthProvider).containsKey('b'), isFalse);

      await notifier.checkAll([a, b], dio: _dio(site));
      expect(container.read(serverHealthProvider).keys.toSet(), {'a', 'b'});

      notifier.clear();
      expect(container.read(serverHealthProvider), isEmpty);
    });
  });
}
