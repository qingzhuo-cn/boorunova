import 'dart:async';
import 'dart:io';

import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/util/download_paths.dart';
import 'package:boorunova/foundation/util/image_downloader.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// 关掉测试绑定的 HttpClient 替身。
///
/// [AutomatedTestWidgetsFlutterBinding] 默认把 `HttpOverrides.global` 换成
/// 一个一律回 400 的假客户端，真实 loopback 请求到不了本地 HttpServer；
/// 本文件需要真网络，所以显式声明 `overrideHttpClient => false`。
class _RealHttpBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

/// gal 插件的原生方法通道名（gal 2.3.3 的 `MethodChannel('gal')`）。
///
/// gal 没有可注入的平台实现（GalPlatform.instance 藏在 src/ 下，直接 import
/// 会踩 implementation_imports lint），所以这里按插件测试的通行做法在
/// 方法通道层打桩：hasAccess/requestAccess 返回授权，putImage/putVideo 成功。
const MethodChannel _galChannel = MethodChannel('gal');

void _installGalMock({
  required bool granted,
  required List<MethodCall> calls,
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_galChannel, (call) async {
    calls.add(call);
    if (call.method == 'hasAccess' || call.method == 'requestAccess') {
      return granted;
    }
    return null;
  });
}

/// 本地假站点：记录请求，按 responder 应答（默认 500，方便把"不该发请求"
/// 变成显式失败）。
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

void _unexpected(HttpRequest request) {
  request.response
    ..statusCode = HttpStatus.internalServerError
    ..write('unexpected request');
  request.response.close();
}


/// 某个下载的最终路径与半截路径（`.part`）。
///
/// 文件名规则与下载器一致：`uniqueFileName` + 站点子目录，所以测试要断言的
/// 落盘位置和实现算出来的是同一个。
Future<(String, String)> _pathsFor(
  String downloadPath,
  String url,
  String postId,
) async {
  final dir = await resolveDownloadDir(downloadPath);
  final name = uniqueFileName(url, postId: postId, namespace: 'srv');
  final sep = Platform.pathSeparator;
  return ('${dir.path}$sep$name', '${dir.path}$sep$name.part');
}

void main() {
  // 必须在任何 ensureInitialized 之前构造，否则会拿到默认的 400 假客户端。
  _RealHttpBinding();

  late Directory tempDir;
  late _FakeSite site;
  late List<MethodCall> galCalls;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('boorunova_download_test');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveSetup.settingsBoxName);
    site = await _FakeSite.start();
    site.responder = _unexpected;
    galCalls = <MethodCall>[];
    // 授权成功：process 级静态缓存会记住 true，同文件后续用例都不再走原生。
    _installGalMock(granted: true, calls: galCalls);
  });

  tearDown(() async {
    await site.close();
    await Hive.deleteFromDisk();
    tempDir.deleteSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_galChannel, null);
  });

  test('该帖已保存过时返回 alreadySaved 且不再发请求', () async {
    await UserDownloadsRepo().add(DownloadEntry(
      postId: '42',
      imageUrl: '${site.baseUrl}/old.jpg',
      localPath: '${tempDir.path}/old.jpg',
      downloadedAt: DateTime.now(),
      serverId: 'srv',
    ));

    final result = await ImageDownloader.downloadImage(
      '${site.baseUrl}/image.jpg',
      postId: '42',
      namespace: 'srv',
      downloadPath: tempDir.path,
      dio: _dio(site),
    );

    expect(result.success, isTrue);
    expect(result.alreadySaved, isTrue,
        reason: '同一 (serverId, postId) 已保存过：UI 要能明说「已保存过」，'
            '而不是重复写一条 MediaStore 条目');
    expect(site.requests, isEmpty,
        reason: '已保存过就不该再打网络请求');
  });

  test('URL 没有扩展名时被拒绝且不发请求', () async {
    final result = await ImageDownloader.downloadImage(
      '${site.baseUrl}/image',
      downloadPath: tempDir.path,
      dio: _dio(site),
    );

    expect(result.success, isFalse);
    expect(result.error, isNotNull);
    expect(result.error, contains('extension'),
        reason: '成功但文件名无扩展名会让 Gal 抛异常，必须提前拒绝');
    expect(site.requests, isEmpty, reason: '扩展名守卫应在网络请求之前生效');
  });

  test('流清单（.m3u8 / .mpd）被拒绝且不发请求', () async {
    for (final ext in ['.m3u8', '.mpd']) {
      final result = await ImageDownloader.downloadImage(
        '${site.baseUrl}/playlist$ext',
        downloadPath: tempDir.path,
        dio: _dio(site),
      );

      expect(result.success, isFalse, reason: '流清单 $ext 不是可存相册的文件');
      expect(result.error, contains('stream manifest'));
    }
    expect(site.requests, isEmpty,
        reason: '流清单只该用播放器播放，下载应在发请求前拒绝');
  });

  test('正常下载写入相册并落一条下载记录', () async {
    site.responder = (request) {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('image', 'jpeg')
        ..write('fake-image-bytes');
      request.response.close();
    };

    final result = await ImageDownloader.downloadImage(
      '${site.baseUrl}/photo.jpg',
      postId: '7',
      namespace: 'srv',
      width: 100,
      height: 200,
      downloadPath: tempDir.path,
      dio: _dio(site),
    );

    expect(result.success, isTrue);
    expect(result.alreadySaved, isFalse);
    expect(result.error, isNull);
    expect(site.requests, hasLength(1));
    expect(galCalls.map((c) => c.method), contains('putImage'),
        reason: '图片必须走相册图片集合（视频才走 putVideo）');

    final entries = UserDownloadsRepo().getAll();
    expect(entries, hasLength(1));
    expect(entries.single.postId, '7');
    expect(entries.single.serverId, 'srv');
    expect(File(entries.single.localPath).existsSync(), isTrue,
        reason: '记录里的 localPath 必须真的落盘');
  });

  test('下载中途取消（CancelToken.cancel）返回失败且不落记录', () async {
    final received = Completer<void>();
    site.responder = (request) {
      // 收到请求但不响应，模拟慢速下载，等测试主动取消。
      if (!received.isCompleted) received.complete();
    };

    final cancelToken = CancelToken();
    final pending = ImageDownloader.downloadImage(
      '${site.baseUrl}/slow.jpg',
      postId: '9',
      namespace: 'srv',
      downloadPath: tempDir.path,
      dio: _dio(site),
      cancelToken: cancelToken,
    );
    await received.future;
    cancelToken.cancel('user cancelled');

    final result = await pending;

    expect(result.success, isFalse, reason: '取消必须走失败路径，不能永远挂着');
    expect(result.error, isNotNull);
    expect(site.requests, hasLength(1));
    expect(UserDownloadsRepo().getAll(), isEmpty,
        reason: '被取消的下载不应落下记录');
  });

  test('站点级下载子目录真的被用上（落盘路径在子目录里）', () async {
    site.responder = (request) {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('image', 'jpeg')
        ..write('bytes');
      request.response.close();
    };

    final result = await ImageDownloader.downloadImage(
      '${site.baseUrl}/photo.jpg',
      postId: '21',
      namespace: 'srv',
      downloadPath: tempDir.path,
      downloadSubdir: 'danbooru',
      dio: _dio(site),
    );

    expect(result.success, isTrue, reason: result.error ?? '');
    final entry = UserDownloadsRepo().getAll().single;
    expect(entry.localPath.contains('danbooru'), isTrue,
        reason: '站点偏好里的子目录必须体现在落盘路径上');
    expect(File(entry.localPath).existsSync(), isTrue);
  });

  test('非法子目录不越权：退回基目录而不是写到外面', () async {
    site.responder = (request) {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('image', 'jpeg')
        ..write('bytes');
      request.response.close();
    };

    final result = await ImageDownloader.downloadImage(
      '${site.baseUrl}/photo2.jpg',
      postId: '22',
      namespace: 'srv',
      downloadPath: tempDir.path,
      downloadSubdir: '../../escape',
      dio: _dio(site),
    );

    expect(result.success, isTrue, reason: result.error ?? '');
    final entry = UserDownloadsRepo().getAll().single;
    expect(File(entry.localPath).parent.path, tempDir.path,
        reason: '越权输入必须退回基目录');
  });

  test('挂起（连接建立后一直无数据）→ 中止、重试、给可读哨兵', () async {
    // 服务端收到请求后一个字节都不发（也永远不响应头）：修复前它会一直等，
    // 进度条永远停在那里，用户只能杀进程。
    site.responder = (request) {};

    final result = await ImageDownloader.downloadImage(
      '${site.baseUrl}/hang.jpg',
      postId: '11',
      namespace: 'srv',
      downloadPath: tempDir.path,
      dio: _dio(site),
      // 生产是 60s，这里缩短到 200ms 才能进自动化测试
      stallTimeout: const Duration(milliseconds: 200),
    );

    expect(result.success, isFalse);
    expect(result.error, kDownloadStalled,
        reason: '挂起要走哨兵值，UI 才能给「请重试」而不是 Dio 异常原文');
    expect(site.requests, hasLength(3),
        reason: '挂起属连接类问题，应当退避重试满 3 次再放弃');
    expect(UserDownloadsRepo().getAll(), isEmpty);
  });

  test('正常下载不会被看门狗误杀（超时设得很短也一样）', () async {
    // 带 Content-Length 的普通响应：看门狗必须放行。
    // 「慢但在动」的字节流没法在这里复现（测试绑定下 chunked 响应体要等响应
    // 结束才交给客户端，见 test/stall_watchdog_test.dart 的说明），所以那条
    // 语义由看门狗的单元测试覆盖，这里只钉「别误杀正常下载」。
    site.responder = (request) {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('image', 'jpeg')
        ..headers.contentLength = 4096
        ..add(List<int>.filled(4096, 7));
      request.response.close();
    };

    final result = await ImageDownloader.downloadImage(
      '${site.baseUrl}/fast.jpg',
      postId: '12',
      namespace: 'srv',
      downloadPath: tempDir.path,
      dio: _dio(site),
      stallTimeout: const Duration(milliseconds: 300),
    );

    expect(result.success, isTrue,
        reason: '正常下载不能被看门狗杀掉（error=${result.error}）');
    expect(result.error, isNull);
    expect(UserDownloadsRepo().getAll(), hasLength(1));
  });

  group('断点续传（OPT §3.1）', () {
    // 路径助手定义在文件末尾（_pathsFor），见那里的说明。

    test('有 .part 时带 Range 续写，完成后改名到最终路径', () async {
      const url = '/resume.jpg';
      final (finalPath, partialPath) = await _pathsFor(tempDir.path, url, '41');
      File(partialPath).writeAsBytesSync([1, 2, 3, 4]);

      String? rangeHeader;
      site.responder = (request) {
        rangeHeader = request.headers.value('range');
        request.response
          ..statusCode = 206
          ..headers.contentType = ContentType('image', 'jpeg');
        request.response.headers.set('content-range', 'bytes 4-7/8');
        request.response.add([5, 6, 7, 8]);
        request.response.close();
      };

      final result = await ImageDownloader.downloadImage(
        '${site.baseUrl}$url',
        postId: '41',
        namespace: 'srv',
        downloadPath: tempDir.path,
        dio: _dio(site),
      );

      expect(result.success, isTrue, reason: result.error ?? '');
      expect(rangeHeader, 'bytes=4-', reason: '必须告诉服务端从哪继续');
      expect(File(finalPath).readAsBytesSync(), [1, 2, 3, 4, 5, 6, 7, 8],
          reason: '前 4 字节要接上新拿到的 4 字节');
      expect(File(partialPath).existsSync(), isFalse,
          reason: '完成后不该留下 .part');
    });

    test('服务器不认 Range（回 200 整份）→ 整写，不拼接', () async {
      const url = '/norange.jpg';
      final (finalPath, partialPath) = await _pathsFor(tempDir.path, url, '42');
      // 半截内容与这次拿到的完全不同：拼接会得到损坏文件
      File(partialPath).writeAsBytesSync([1, 2, 3, 4]);

      site.responder = (request) {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType('image', 'jpeg')
          ..add([9, 9, 9, 9]);
        request.response.close();
      };

      final result = await ImageDownloader.downloadImage(
        '${site.baseUrl}$url',
        postId: '42',
        namespace: 'srv',
        downloadPath: tempDir.path,
        dio: _dio(site),
      );

      expect(result.success, isTrue, reason: result.error ?? '');
      expect(File(finalPath).readAsBytesSync(), [9, 9, 9, 9],
          reason: '服务端给了整份就整份覆盖，绝不能追加成 8 字节');
      expect(File(partialPath).existsSync(), isFalse);
      expect(File(finalPath).lengthSync(), 4);
    });

    test('取消后保留 .part（下次可以接着下），不产生最终文件', () async {
      const url = '/cancelled.jpg';
      final (finalPath, partialPath) = await _pathsFor(tempDir.path, url, '43');
      final received = Completer<void>();
      site.responder = (request) async {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add([1, 2, 3, 4]);
        await request.response.flush();
        if (!received.isCompleted) received.complete();
        // 之后不结束：等测试取消
      };

      final token = CancelToken();
      final pending = ImageDownloader.downloadImage(
        '${site.baseUrl}$url',
        postId: '43',
        namespace: 'srv',
        downloadPath: tempDir.path,
        dio: _dio(site),
        cancelToken: token,
      );
      await received.future;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      token.cancel('user cancelled');

      final result = await pending;

      expect(result.success, isFalse);
      expect(File(finalPath).existsSync(), isFalse,
          reason: '半截文件不能改名成最终文件');
      expect(File(partialPath).existsSync(), isTrue,
          reason: '取消要保留半截文件，否则「断点续传」无从谈起');
    });
  });

    test('416（半截与服务端对不上）→ 丢掉半截重来一次，而不是直接失败', () async {
      const url = '/stale.jpg';
      final (finalPath, partialPath) = await _pathsFor(tempDir.path, url, '44');
      // 模拟「上次其实已经下完了，但改名之前进程被杀」：.part 比整份还长

      File(partialPath).writeAsBytesSync(List<int>.filled(16, 7));

      var calls = 0;
      site.responder = (request) {
        calls++;
        final range = request.headers.value('range');
        if (range != null) {
          // 服务端：你要的起点超出文件长度 → 416

          request.response.statusCode = 416;
          request.response.close();
          return;
        }
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType('image', 'jpeg')
          ..add([1, 2, 3]);
        request.response.close();
      };

      final result = await ImageDownloader.downloadImage(
        '${site.baseUrl}$url',
        postId: '44',
        namespace: 'srv',
        downloadPath: tempDir.path,
        dio: _dio(site),
      );

      expect(result.success, isTrue, reason: result.error ?? '');
      expect(calls, greaterThanOrEqualTo(2), reason: '应当丢掉半截后重来');
      expect(File(finalPath).readAsBytesSync(), [1, 2, 3]);
      expect(File(partialPath).existsSync(), isFalse);
    });

    test('过旧的 .part 不再续传（内容可能已变，也避免半截文件堆积）', () async {
      const url = '/old-partial.jpg';
      final (finalPath, partialPath) = await _pathsFor(tempDir.path, url, '45');
      File(partialPath).writeAsBytesSync([1, 2, 3, 4]);
      // 把 mtime 拨到保鲜期之外

      File(partialPath).setLastModifiedSync(
        DateTime.now().subtract(const Duration(days: 30)),
      );

      String? rangeHeader;
      site.responder = (request) {
        rangeHeader = request.headers.value('range');
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType('image', 'jpeg')
          ..add([8, 8, 8]);
        request.response.close();
      };

      final result = await ImageDownloader.downloadImage(
        '${site.baseUrl}$url',
        postId: '45',
        namespace: 'srv',
        downloadPath: tempDir.path,
        dio: _dio(site),
      );

      expect(result.success, isTrue, reason: result.error ?? '');
      expect(rangeHeader, isNull, reason: '过旧的半截不续传，直接整份重下');
      expect(File(finalPath).readAsBytesSync(), [8, 8, 8],
          reason: '过旧的半截必须被丢掉，不能拼进来');
    });

  group('下载侧限流（OPT §3.8）', () {
    test('429 + Retry-After → 重试一次后成功', () async {
      const url = '/limited.jpg';
      final (finalPath, partialPath) =
          await _pathsFor(tempDir.path, url, '51');
      var calls = 0;
      site.responder = (request) {
        calls++;
        if (calls == 1) {
          // 服务端说「稍后再来」：0 秒会被夹到 1s，用例只为 1s
          request.response
            ..statusCode = 429
            ..headers.set('retry-after', '0');
          request.response.close();
          return;
        }
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType('image', 'jpeg')
          ..add([4, 5, 6]);
        request.response.close();
      };

      final result = await ImageDownloader.downloadImage(
        '${site.baseUrl}$url',
        postId: '51',
        namespace: 'srv',
        downloadPath: tempDir.path,
        dio: _dio(site),
      );

      expect(result.success, isTrue, reason: result.error ?? '');
      expect(calls, 2, reason: '被限流后应当按服务端给的时间重试，而不是直接失败');
      expect(File(finalPath).readAsBytesSync(), [4, 5, 6]);
      expect(File(partialPath).existsSync(), isFalse,
          reason: '限流不是永久失败，别删掉半截文件');
    });

    test('403（不是限流）不重试：照旧失败', () async {
      const url = '/forbidden.jpg';
      var calls = 0;
      site.responder = (request) {
        calls++;
        request.response.statusCode = 403;
        request.response.close();
      };

      final result = await ImageDownloader.downloadImage(
        '${site.baseUrl}$url',
        postId: '52',
        namespace: 'srv',
        downloadPath: tempDir.path,
        dio: _dio(site),
      );

      expect(result.success, isFalse);
      expect(calls, 1, reason: '403 重试只会把同一次失败重复一遍');
    });
  });

    test('限流等待期间点取消 → 立刻返回，不等满 Retry-After', () async {
      const url = '/limited-cancel.jpg';
      final (finalPath, partialPath) =
          await _pathsFor(tempDir.path, url, '53');
      var calls = 0;
      site.responder = (request) {
        calls++;
        // 服务端要 30 秒后再来：干等的话用户最长要等 30s 才看到「已取消」
        request.response
          ..statusCode = 429
          ..headers.set('retry-after', '30');
        request.response.close();
      };

      final token = CancelToken();
      final stopwatch = Stopwatch()..start();
      final pending = ImageDownloader.downloadImage(
        '${site.baseUrl}$url',
        postId: '53',
        namespace: 'srv',
        downloadPath: tempDir.path,
        dio: _dio(site),
        cancelToken: token,
      );
      // 等第一次 429 回来进入等待，再取消
      await Future<void>.delayed(const Duration(milliseconds: 200));
      token.cancel('user cancelled');

      final result = await pending;
      stopwatch.stop();

      expect(result.success, isFalse);
      expect(calls, 1, reason: '取消后不该再发请求');
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 5)),
        reason: '取消要立刻生效，不能等满 Retry-After（这里是 30s）',
      );
      expect(File(finalPath).existsSync(), isFalse);
      expect(File(partialPath).existsSync(), isFalse,
          reason: '连一个字节都没下到，不该留下半截文件');
  });

    test('限流时回调告知等待时长（界面据此提示用户）', () async {
      const url = '/notice.jpg';
      var calls = 0;
      site.responder = (request) {
        calls++;
        if (calls == 1) {
          request.response
            ..statusCode = 429
            ..headers.set('retry-after', '2');
          request.response.close();
          return;
        }
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType('image', 'jpeg')
          ..add([1]);
        request.response.close();
      };

      final notices = <Duration>[];
      final result = await ImageDownloader.downloadImage(
        '${site.baseUrl}$url',
        postId: '54',
        namespace: 'srv',
        downloadPath: tempDir.path,
        dio: _dio(site),
        onRetryWait: notices.add,
      );

      expect(result.success, isTrue, reason: result.error ?? '');
      expect(notices, [const Duration(seconds: 2)],
          reason: '要按服务端给的时间提示「几秒后重试」');
    });

    test('挂起重试不打扰用户：只有限流才提示', () async {
      const url = '/silent-retry.jpg';
      var calls = 0;
      site.responder = (request) {
        calls++;
        if (calls == 1) {
          // 第一次：连上就不说话 → 看门狗判挂起（属于会重试的连接类问题）
          return;
        }
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType('image', 'jpeg')
          ..add([1]);
        request.response.close();
      };

      final notices = <Duration>[];
      final result = await ImageDownloader.downloadImage(
        '${site.baseUrl}$url',
        postId: '55',
        namespace: 'srv',
        downloadPath: tempDir.path,
        dio: _dio(site),
        onRetryWait: notices.add,
        stallTimeout: const Duration(milliseconds: 200),
      );

      expect(result.success, isTrue, reason: result.error ?? '');
      expect(calls, greaterThanOrEqualTo(2), reason: '前提：这条路径真的重试了');
      expect(notices, isEmpty,
          reason: '退避只有 1/2/4s，为它弹「限流重试」反而像出错');
    });
}
