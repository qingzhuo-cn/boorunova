import 'dart:async';
import 'dart:io';

import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 错误文案映射的**保真**测试（OPT §5.3 / 审查 L-9，AUDIT 复核第 29 轮）。
///
/// 第 29 轮把映射从「字符串嗅探」改成「结构化优先」，但当时的用例是手写的
/// DioException —— 那验证的是**我以为** dio 会给什么。这里换成让真 dio 打真
/// HTTP 服务，拿到它**实际**抛出的异常再断言文案，这样 dio 升级换实现也能
/// 被这几条用例挡住。
void main() {
  late HttpServer server;
  late Dio dio;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dio = Dio(BaseOptions(
      baseUrl: 'http://127.0.0.1:${server.port}',
      connectTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(milliseconds: 300),
    ));
  });

  tearDown(() async {
    await server.close(force: true);
  });

  /// 发一次请求，返回 dio 实际抛出的异常。
  Future<Object> capture(String path) async {
    try {
      await dio.get<Object>(path);
    } catch (e) {
      return e;
    }
    fail('这个请求本该失败');
  }

  test('真 404 → 404 文案', () async {
    server.listen((req) {
      req.response.statusCode = 404;
      req.response.close();
    });

    final e = await capture('/nope');
    expect(e, isA<DioException>(), reason: '前提：dio 抛的是 DioException');
    expect(T.friendlyError(e), T.err404);
  });

  test('真 503 → 5xx 文案', () async {
    server.listen((req) {
      req.response.statusCode = 503;
      req.response.close();
    });

    expect(T.friendlyError(await capture('/down')), T.err5xx);
  });

  test('服务端一直不回 → 接收超时文案', () async {
    final held = Completer<void>();
    addTearDown(held.complete);
    server.listen((req) async {
      // 收到请求但永不响应：receiveTimeout (300ms) 先到
      await held.future;
      try {
        await req.response.close();
      } catch (_) {}
    });

    final error = await capture('/slow');
    expect(
      T.friendlyError(error),
      T.errReceiveTimeout,
      reason: '接收超时必须说清是「等着等着超时了」，不是「连不上」',
    );
  });

  test('端口没人听 → 网络类文案（不是通用兜底）', () async {
    // 先拿到一个确定没人监听的端口：绑定后立刻释放
    final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = probe.port;
    await probe.close(force: true);

    final dead = Dio(BaseOptions(
      baseUrl: 'http://127.0.0.1:$deadPort',
      connectTimeout: const Duration(seconds: 2),
    ));
    Object? error;
    try {
      await dead.get<Object>('/x');
    } catch (e) {
      error = e;
    }
    expect(error, isNotNull);

    final message = T.friendlyError(error!);
    expect(message, isNot(T.errUnknown),
        reason: '连不上是常见失败，必须给具体说法，不能掉进通用兜底');
    // 具体是哪一种由平台决定：本机（Windows loopback）实测 dio 报的是
    // connectionTimeout，所以这里只钉「落在连接类文案里」，不钉死某一条——
    // 钉死会让用例随平台/系统版本随机红。
    // 顺带记一个实测结论：连一个没人监听的端口，在 Windows 上要等到
    // connectTimeout（生产 30s）才失败，而不是立刻「连接被拒绝」。
    expect(
      message,
      anyOf(T.errRefused, T.errNetwork, T.errTimeout, T.errReceiveTimeout),
    );
  });

  test('消息里没有状态码痕迹时，仍能按结构化字段映射（404）', () {
    // 保真测试有个盲区：真 dio 的异常文案里**带** status code，
    // 于是字符串兜底也能命中，看不出结构化分支到底有没有在工作。
    // 这里把 message 换成一句无关的话，只有类型 + statusCode 可用。
    final e = DioException(
      requestOptions: RequestOptions(path: '/posts.json'),
      type: DioExceptionType.badResponse,
      message: 'boom',
      response: Response(
        requestOptions: RequestOptions(path: '/posts.json'),
        statusCode: 404,
      ),
    );
    expect(e.toString(), isNot(contains('404')),
        reason: '前提：文案里确实没有状态码',
    );
    expect(T.friendlyError(e), T.err404);
  });

  test('消息里没有痕迹时，超时同样按类型映射', () {
    final e = DioException(
      requestOptions: RequestOptions(path: '/posts.json'),
      type: DioExceptionType.receiveTimeout,
      message: 'boom',
    );
    expect(T.friendlyError(e), T.errReceiveTimeout);
  });
}
