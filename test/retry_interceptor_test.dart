import 'dart:async';
import 'dart:typed_data';

import 'package:boorunova/foundation/network/dio_factory.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// OPT 3.8 的守卫：连接类错误按 1s/2s/4s 退避重试，429 听 Retry-After，
/// 其余错误不重试（重试只是把同一次失败重复一遍）。
class _FlakyAdapter implements HttpClientAdapter {
  _FlakyAdapter(this.failures);

  /// 前 [failures] 次请求抛连接错误，之后返回 200。
  int failures;
  int calls = 0;
  DioExceptionType errorType = DioExceptionType.connectionError;
  int? statusCode;
  Map<String, List<String>> headers = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (calls <= failures) {
      if (statusCode != null) {
        throw DioException.badResponse(
          statusCode: statusCode!,
          requestOptions: options,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: statusCode,
            headers: Headers.fromMap(headers),
          ),
        );
      }
      throw DioException(requestOptions: options, type: errorType);
    }
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('退避口径：1s / 2s / 4s / 8s', () {
    expect(DioFactory.retryDelayFor(0), const Duration(seconds: 1));
    expect(DioFactory.retryDelayFor(1), const Duration(seconds: 2));
    expect(DioFactory.retryDelayFor(2), const Duration(seconds: 4));
    expect(DioFactory.retryDelayFor(3), const Duration(seconds: 8));
  });

  group('RetryInterceptor', () {
    Dio buildDio(_FlakyAdapter adapter, {int maxAttempts = 2}) {
      final dio = Dio(BaseOptions(baseUrl: 'https://retry.test'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(RetryInterceptor(
        dio,
        maxAttempts: maxAttempts,
        delayFor: (_) => Duration.zero,
      ));
      return dio;
    }

    test('连接错误会重试并最终成功', () async {
      final adapter = _FlakyAdapter(1);
      final dio = buildDio(adapter);
      final response = await dio.get<dynamic>('/x');
      expect(response.statusCode, 200);
      expect(adapter.calls, 2, reason: '第一次失败 + 重试一次');
    });

    test('重试次数用尽后把原始错误抛出来', () async {
      final adapter = _FlakyAdapter(99);
      final dio = buildDio(adapter, maxAttempts: 2);
      await expectLater(
        dio.get<dynamic>('/x'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls, 3, reason: '首次 + 2 次重试');
    });

    test('4xx（非 429）不重试', () async {
      final adapter = _FlakyAdapter(99)
        ..statusCode = 404
        ..headers = const {};
      final dio = buildDio(adapter);
      await expectLater(dio.get<dynamic>('/x'), throwsA(isA<DioException>()));
      expect(adapter.calls, 1, reason: '404 重试没有意义');
    });

    test('429 会重试（服务端说稍后再来）', () async {
      final adapter = _FlakyAdapter(1)
        ..statusCode = 429
        ..headers = const {
          'retry-after': ['1'],
        };
      final dio = buildDio(adapter, maxAttempts: 1);
      final response = await dio.get<dynamic>('/x');
      expect(response.statusCode, 200);
      expect(adapter.calls, 2);
    });
  });
}
