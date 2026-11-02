import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 底层异常 → 用户提示的映射（OPT §5.3 / 审查 L-9）。
///
/// 这是**全应用唯一**的错误文案入口（首页/探索/图集/图集详情/备份/Hosts 都
/// 走它），此前一条测试都没有。它一旦漏掉某个形态，用户看到的就是
/// `DioException [bad response]: ... #0 DioMixin.fetch` 这种英文栈。
void main() {
  DioException dio(int? status, {DioExceptionType type = DioExceptionType.badResponse, String? message}) =>
      DioException(
        requestOptions: RequestOptions(path: '/posts.json'),
        type: type,
        message: message,
        response: status == null
            ? null
            : Response(requestOptions: RequestOptions(path: '/p'), statusCode: status),
      );

  group('已知形态映射成可读文案', () {
    test('未选站点的哨兵错误码', () {
      expect(T.friendlyError('noServerSelected'), T.noServerSelected);
      expect(T.friendlyError('Error: noServerSelected'), T.noServerSelected);
    });

    test('连接/接收超时各自有说法（用户该做的动作不同）', () {
      expect(
        T.friendlyError(dio(null, type: DioExceptionType.connectionTimeout)),
        T.errTimeout,
      );
      expect(
        T.friendlyError(dio(null, type: DioExceptionType.receiveTimeout)),
        T.errReceiveTimeout,
      );
    });

    test('HTTP 状态码：403 / 404 / 429 / 5xx', () {
      expect(T.friendlyError(dio(403)), T.err403);
      expect(T.friendlyError(dio(404)), T.err404);
      expect(T.friendlyError(dio(429)), T.err429);
      expect(T.friendlyError(dio(500)), T.err5xx);
      expect(T.friendlyError(dio(503)), T.err5xx);
    });

    test('网络层：DNS / 拒绝连接 / 证书', () {
      expect(
        T.friendlyError('SocketException: Failed host lookup: x.test'),
        T.errDns,
      );
      expect(
        T.friendlyError('SocketException: Connection refused (OS Error)'),
        T.errRefused,
      );
      expect(
        T.friendlyError('HandshakeException: CERTIFICATE_VERIFY_FAILED'),
        T.errTls,
      );
    });

    test('响应体不是 JSON（自建站常见）', () {
      expect(T.friendlyError('FormatException: Unexpected XML'), T.errBadPayload);
    });
  });

  group('未知形态不得泄露裸异常', () {
    test('多层堆栈只给通用文案', () {
      // 这是修复前会直接显示给用户的东西
      const raw = 'DioException [bad response]: This is an error message\n'
          '#0      DioMixin.fetch (package:dio/src/dio_mixin.dart:488:13)\n'
          '#1      BooruRepository.searchPosts (package:boorunova/x.dart:10:5)';
      final message = T.friendlyError(raw);

      expect(message, T.errUnknown);
      expect(message, isNot(contains('DioException')));
      expect(message, isNot(contains('#0')));
      expect(message, isNot(contains('package:')));
    });

    test('没有任何映射的短异常也走通用文案（不显示英文原文）', () {
      final message = T.friendlyError(StateError('Bad state: something odd'));
      expect(message, T.errUnknown);
      expect(message, isNot(contains('Bad state')));
    });

    test('通用文案本身不为空、不带技术标记', () {
      expect(T.errUnknown.trim(), isNotEmpty);
      expect(T.errUnknown, isNot(contains('Exception')));
    });
  });
}
