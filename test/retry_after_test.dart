import 'dart:io';

import 'package:boorunova/foundation/network/dio_factory.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// `Retry-After` 解析（OPT §3.8）。
///
/// 这个头有两种合法写法，站点两种都在用。解析错的表现是「重试时机不对」：
/// 太早会继续被限流，太晚则界面像卡死。
Response<dynamic> _response(String? retryAfter) {
  final options = RequestOptions(path: '/x');
  return Response<dynamic>(
    requestOptions: options,
    statusCode: 429,
    headers: Headers.fromMap({
      if (retryAfter != null) 'retry-after': [retryAfter],
    }),
  );
}

void main() {
  group('Retry-After 解析', () {
    test('秒数写法', () {
      expect(DioFactory.retryAfterOf(_response('3')),
          const Duration(seconds: 3));
      expect(DioFactory.retryAfterOf(_response(' 5 ')),
          const Duration(seconds: 5), reason: '两端空格要容忍');
    });

    test('HTTP 日期写法（RFC 7231 的另一种）', () {
      final at = DateTime.now().toUtc().add(const Duration(seconds: 10));
      final parsed = DioFactory.retryAfterOf(_response(HttpDate.format(at)));
      expect(parsed, isNotNull, reason: '日期写法也要认，不能只认秒数');
      expect(parsed!.inSeconds, inInclusiveRange(8, 11));
    });

    test('日期已经过去 → 立刻重试（1s）', () {
      final at = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
      expect(
        DioFactory.retryAfterOf(_response(HttpDate.format(at))),
        const Duration(seconds: 1),
      );
    });

    test('超大值被夹到 60s（别让界面像卡死一小时）', () {
      expect(DioFactory.retryAfterOf(_response('3600')),
          const Duration(seconds: 60));
    });

    test('0 / 负数 → 1s（不能立即狂刷）', () {
      expect(DioFactory.retryAfterOf(_response('0')),
          const Duration(seconds: 1));
      expect(DioFactory.retryAfterOf(_response('-5')),
          const Duration(seconds: 1));
    });

    test('没给 / 读不懂 → null（调用方回退指数退避）', () {
      expect(DioFactory.retryAfterOf(_response(null)), isNull);
      expect(DioFactory.retryAfterOf(_response('')), isNull);
      expect(DioFactory.retryAfterOf(_response('soon')), isNull);
      expect(DioFactory.retryAfterOf(null), isNull);
    });
  });
}
