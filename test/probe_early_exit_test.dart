import 'dart:io';

import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// 关掉测试绑定那个「一律回 400」的 HttpClient 替身（要真连本地 HttpServer）。
class _RealHttpBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

/// 探测的**早退**行为（OPT §2.6）。
///
/// 并发已经做过了，但收结果的方式同样决定耗时：`Future.wait` 要等**每一条**
/// 回来才判断。真实场景里只要有一条探测路径挂到超时（站点不认这个路径、
/// 也不回 404，而是挂着），用户就要多等一个超时周期——即使第 0 条早就命中了。
void main() {
  _RealHttpBinding();

  late HttpServer server;
  late String baseUrl;
  final hang = <HttpRequest>[];

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';
    server.listen((request) {
      final path = request.uri.path;
      final query = request.uri.queryParameters;
      // danbooru 的探测路径（_probePaths 里排第一）快速命中
      if (path == '/posts.json' && query['limit'] == '1') {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          // 真实的 danbooru /posts.json 形态（特征要求 tag_string 与 preview_file_url）
          ..write('[{"id":1,"tag_string":"a","preview_file_url":"p.jpg"}]');
        request.response.close();
        return;
      }
      // 其余路径一直挂着：模拟「站点不认这个探测路径但也不回 404」
      hang.add(request);
    });
  });

  tearDown(() async {
    for (final request in hang) {
      try {
        await request.response.close();
      } catch (_) {}
    }
    await server.close(force: true);
  });

  test('第 0 条命中就返回，不等其余挂起的探测', () async {
    final watch = Stopwatch()..start();
    final type = await BooruRegistry().probe(baseUrl);
    final elapsed = watch.elapsed;

    expect(type, BooruType.danbooru);
    expect(
      elapsed,
      lessThan(const Duration(seconds: 5)),
      reason: '命中优先级最高的类型后应立即返回；实测 $elapsed'
          '（退回 Future.wait 的话这里是超时级）',
    );
  });

  test('JSON 响应的特征串必须能命中（ResponseType.plain 回归）', () async {
    // 真实 bug：默认 JSON 解析把响应解成 Map/List，`toString()` 出来的
    // `[{preview_url: x}]` **没有引号**，于是 `"preview_url"` 永远匹配不上，
    // 所有 JSON 引擎的「按类型探测」静默失效（只剩域名捷径兜底，自建站判不出来）。
    // 纯函数单测喂的是原始字符串，所以这个坑一直没被现有测试发现。
    final site = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => site.close(force: true));
    site.listen((request) {
      final path = request.uri.path;
      final isDapi = path == '/index.php' &&
          request.uri.queryParameters['page'] == 'dapi';
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        // 真实 DAPI JSON：preview_url 与 file_url 同时存在
        ..write(isDapi ? '[{"preview_url":"x","file_url":"y"}]' : '{}');
      request.response.close();
    });

    final type =
        await BooruRegistry().probe('http://127.0.0.1:${site.port}');

    expect(type, BooruType.gelbooruV2,
        reason: 'DAPI 的 JSON 响应里确实有 preview_url，就该认出来');
  });
}
