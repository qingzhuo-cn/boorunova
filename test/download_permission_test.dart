import 'dart:io';

import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/util/image_downloader.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// 同 download_http_test.dart：真网络 + 方法通道打桩。
///
/// 必须独占一个测试文件：ImageDownloader 把权限结果缓存进进程级静态字段
/// （_galAccessGranted），同一 isolate 内一旦授过权就再也测不到拒绝分支。
class _RealHttpBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

const MethodChannel _galChannel = MethodChannel('gal');

void main() {
  _RealHttpBinding();

  late Directory tempDir;
  late HttpServer server;
  late List<Uri> requests;
  late List<MethodCall> galCalls;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('boorunova_perm_test');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveSetup.settingsBoxName);

    requests = <Uri>[];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      requests.add(request.uri);
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write('should never be reached');
      request.response.close();
    });

    galCalls = <MethodCall>[];
    // 平台侧拒绝授权：hasAccess 与 requestAccess 都回 false。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_galChannel, (call) async {
      galCalls.add(call);
      if (call.method == 'hasAccess' || call.method == 'requestAccess') {
        return false;
      }
      return null;
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await Hive.deleteFromDisk();
    tempDir.deleteSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_galChannel, null);
  });

  test('相册权限被拒时返回哨兵错误且不发起网络请求', () async {
    final baseUrl = 'http://127.0.0.1:${server.port}';

    final result = await ImageDownloader.downloadImage(
      '$baseUrl/photo.jpg',
      postId: '1',
      namespace: 'srv',
      downloadPath: tempDir.path,
      dio: Dio(BaseOptions(baseUrl: baseUrl)),
    );

    expect(result.success, isFalse);
    expect(result.error, kGalleryPermissionDenied,
        reason: 'UI 依赖这个哨兵换成可读文案，而不是平台异常原文');
    expect(requests, isEmpty,
        reason: '权限检查在网络之前，没权限就不该把整张图拉下来再失败');
    expect(galCalls.map((c) => c.method), contains('hasAccess'),
        reason: '必须先问过权限；直接 putImage 在 Android 8/9 上必然失败');
  });
}
