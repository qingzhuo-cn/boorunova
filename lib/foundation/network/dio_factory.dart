// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:io';

import 'package:boorunova/foundation/network/hosts_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 统一 Dio 工厂：一处配置超时、UA、hosts 拦截，全项目共用。
class DioFactory {
  DioFactory._();

  /// 全局共享的 hosts 映射，由 registry 初始化时注入。
  /// 下载请求通过此静态持有者默认附加（下载是纯静态工具类，拿不到 Riverpod ref）。
  static HostsInterceptor? sharedHostsInterceptor;

  /// 默认 User-Agent 的兜底值。
  ///
  /// 版本号不取 Riverpod 的 appVersionProvider：探测/下载是静态工具，拿不到
  /// ref，且探测常发生在 App 启动早期（provider 还没被赋值）。
  static const String fallbackUserAgent = 'BooruNova/1.0';

  static String _userAgent = fallbackUserAgent;
  static bool _userAgentRequested = false;

  /// 当前默认 User-Agent（测试可直接读取）。
  static String get userAgent => _userAgent;

  /// 首次使用时后台取一次版本号并静态缓存。
  ///
  /// 修复前的故障：createProbe/createDownload 完全没有 User-Agent，
  /// e621/sankaku 的 CDN 会直接 403，探测也会因默认 UA 被挡而误判。
  ///
  /// Dio 的构造是同步的，而 PackageInfo.fromPlatform() 是异步的，同步 API
  /// 等不了：这里先用兜底值把 Dio 建出来，取到真实版本后覆盖缓存，之后创建
  /// 的 Dio 都会带 BooruNova/版本号。取不到（测试/桌面无平台通道）就永久
  /// 使用兜底常量，绝不把异常抛给调用方。
  static void _primeUserAgent() {
    if (_userAgentRequested) return;
    _userAgentRequested = true;
    PackageInfo.fromPlatform().then((info) {
      final version = info.version;
      if (version.isNotEmpty) _userAgent = 'BooruNova/$version';
    }).catchError((Object _) {
      // 平台通道不可用：保留兜底值
    });
  }

  /// 合并默认 UA 与调用方 headers：调用方同名键优先，引擎仍可覆盖 UA。
  static Map<String, dynamic> _mergeDefaultHeaders(
    Map<String, dynamic>? headers,
  ) {
    _primeUserAgent();
    return <String, dynamic>{
      'User-Agent': _userAgent,
      ...?headers,
    };
  }

  /// 引擎 API 请求：长接收超时（图站列表可能慢）
  static Dio create({
    String? baseUrl,
    Map<String, dynamic>? headers,
    HostsInterceptor? hostsInterceptor,
  }) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? '',
      headers: _mergeDefaultHeaders(headers),
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
    ));
    _installHostsAdapter(dio, hostsInterceptor);
    dio.interceptors.add(RetryInterceptor(dio));
    return dio;
  }

  /// 第 [attempt] 次重试前应等待的时长（0 基）：1s / 2s / 4s。
  ///
  /// 下载不在拦截器里重试（dio 的 download() 在拦截器之外把流写进文件，
  /// 用 fetch 重发拿到的响应没人落盘），所以下载侧自己用它做退避——
  /// 两处共用同一个口径，不会各自长出一套。
  /// 从响应里读服务器的 `Retry-After`（OPT §3.8）。
  ///
  /// RFC 7231 允许两种写法，都要认：
  /// - 秒数：`Retry-After: 120`
  /// - HTTP 日期：`Retry-After: Wed, 21 Oct 2015 07:28:00 GMT`
  ///
  /// 读不出来（没给/写错）返回 null，调用方回退到指数退避 [retryDelayFor]。
  /// 上限 60s：站点偶尔回 `3600`（「一小时后再来」），照做的话界面看起来就是
  /// 卡死——宁可退化成重试失败，也不要让用户对着不动的进度条等一小时。
  static Duration? retryAfterOf(Response<dynamic>? response) {
    final raw = response?.headers.value('retry-after')?.trim();
    if (raw == null || raw.isEmpty) return null;

    var seconds = int.tryParse(raw);
    if (seconds == null) {
      // HTTP 日期写法：算出还有多久
      try {
        final at = HttpDate.parse(raw);
        seconds = at.difference(DateTime.now()).inSeconds;
      } catch (_) {
        return null;
      }
    }
    return Duration(seconds: seconds.clamp(1, 60));
  }

  static Duration retryDelayFor(int attempt) =>
      const Duration(seconds: 1) * (1 << attempt.clamp(0, 5));

  /// 引擎探测：短超时快速失败。
  ///
  /// headers 供引擎覆盖探测请求头；不传时也会带上默认 UA。
  /// 探测请求：短超时、只把 200 当成功，并**同样挂 hosts 映射**。
  ///
  /// 与 [createDownload] 一样回落到 [sharedHostsInterceptor]：探测（站点识别、
  /// 健康检查）如果不走用户配的映射，就会出现「浏览正常、探测说连不上」的
  /// 自相矛盾——用户按面板的结论去排查一个不存在的问题。
  static Dio createProbe({
    Map<String, dynamic>? headers,
    HostsInterceptor? hostsInterceptor,
  }) {
    final dio = Dio(BaseOptions(
      headers: _mergeDefaultHeaders(headers),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (s) => s == 200,
    ));
    _installHostsAdapter(dio, hostsInterceptor ?? sharedHostsInterceptor);
    return dio;
  }

  /// 文件下载：无接收超时限制，挂 hosts 映射保证自定义 hosts 生效。
  ///
  /// headers 供调用方覆盖；不传时也会带上默认 UA（此前裸下载没有 UA，
  /// e621/sankaku 等 CDN 直接 403）。
  static Dio createDownload({
    Map<String, dynamic>? headers,
    HostsInterceptor? hostsInterceptor,
  }) {
    final dio = Dio(BaseOptions(
      headers: _mergeDefaultHeaders(headers),
      connectTimeout: const Duration(seconds: 30),
    ));
    // 优先用显式传入的映射，否则用全局共享单例（下载请求同样命中 hosts）
    _installHostsAdapter(dio, hostsInterceptor ?? sharedHostsInterceptor);
    return dio;
  }

  static void _installHostsAdapter(Dio dio, HostsInterceptor? hosts) {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => createHostsHttpClient(hosts),
    );
  }
}

/// 连接类错误的统一重试策略。
///
/// 只重试两类：**连接没建起来**（connectError/connectTimeout/receiveTimeout）
/// 与**服务端明确说稍后再来**（429）。它们与请求内容无关，重试是安全的。
/// 其余 4xx 与业务错误不重试——重试只会把同一次失败重复一遍。
///
/// 仅用于 API 请求（[DioFactory.create]）。文件下载不能用拦截器重试：
/// dio 的 `download()` 在拦截器之外把响应流写进文件，拦截器里用
/// `fetch()` 重发得到的响应没有人落盘，会写出空文件。
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.maxAttempts = 3,
    this.delayFor = DioFactory.retryDelayFor,
  });

  final Dio _dio;

  /// 最多重试几次（不含首次请求）。
  final int maxAttempts;

  /// 退避时长的来源。默认与下载侧共用 [DioFactory.retryDelayFor]；
  /// 测试注入零延迟，避免用例真的要等 1s+2s。
  final Duration Function(int attempt) delayFor;

  static const String _attemptKey = 'boorunovaRetryAttempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 0;
    if (attempt >= maxAttempts || !_shouldRetry(err)) {
      return handler.next(err);
    }
    // 429 听服务器的 Retry-After，其余走 1s / 2s / 4s。
    // 解析收在 [DioFactory.retryAfterOf]：下载侧要走同一份口径。
    final delay = DioFactory.retryAfterOf(err.response) ?? delayFor(attempt);
    await Future<void>.delayed(delay);

    final options = err.requestOptions;
    options.extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    } catch (e) {
      handler.next(DioException(requestOptions: options, error: e));
    }
  }

  bool _shouldRetry(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.badResponse:
        return err.response?.statusCode == 429;
      default:
        return false;
    }
  }
}

/// 构造带 hosts 映射的 [HttpClient]。
///
/// 映射只作用在 TCP 连接层：真正建立连接时用映射后的 IP，URL 与 TLS
/// 的 host 始终是原始域名。旧实现靠改写 URL 换 host，会连带丢掉 query
/// 与 Host 头，并让 HTTPS 的 SNI 和证书校验指向 IP 而失败。
///
/// 独立成函数是为了能被直接测试——经过 Dio 的 IOHttpClientAdapter 包装
/// 之后，connectionFactory 的行为无法在测试里单独断言。
///
/// [onBadCertificate] 是证书校验失败时的放行回调。必须显式传入而不是
/// 事后设置 [HttpClient.badCertificateCallback]：接管 connectionFactory
/// 之后 SecureSocket 由我们亲手创建，HttpClient 不会自动接上它自己的
/// 证书回调，只写属性是读不回来的，传不进来。
HttpClient createHostsHttpClient(
  HostsInterceptor? hosts, {
  bool Function(X509Certificate certificate, String host, int port)?
      onBadCertificate,
}) {
  // 保留 HttpClient 默认的 idleTimeout：图站大图下载中间可能长时间没有
  // 数据流，收紧这个值会在服务器正常停顿时直接掐断连接。
  final client = HttpClient();
  if (onBadCertificate != null) {
    client.badCertificateCallback = onBadCertificate;
  }
  client.connectionFactory = (url, proxyHost, proxyPort) {
    // 代理连接必须交给 HttpClient 自己处理 CONNECT 和 TLS 隧道。
    if (proxyHost != null && proxyPort != null) {
      return Socket.startConnect(proxyHost, proxyPort);
    }

    final mapped = hosts?.resolve(url.host);
    final target = mapped == null
        ? url.host
        : (InternetAddress.tryParse(mapped) ?? mapped);
    final rawFuture = Socket.startConnect(target, url.port);

    // connectionFactory 接管后，直连 HTTPS 需要显式建立 TLS；host 保持
    // 原始域名以确保 SNI 和证书校验不会因 hosts 映射而改变。
    if (url.scheme != 'https') return rawFuture;
    return rawFuture.then((rawTask) {
      // SecureSocket 的回调只收证书，HttpClient 的收证书+host+port，
      // 这里补上被省略的 host/port，语义与 HttpClient 内部一致。
      final onBad = onBadCertificate == null
          ? null
          : (cert) => onBadCertificate(cert, url.host, url.port);
      final tlsFuture = rawTask.socket.then<Socket>(
        (socket) => SecureSocket.secure(
          socket,
          host: url.host,
          onBadCertificate: onBad,
        ),
      );
      return ConnectionTask.fromSocket<Socket>(tlsFuture, () {
        rawTask.cancel();
        tlsFuture.then((socket) => socket.destroy(), onError: (_) {});
      });
    });
  };
  return client;
}
