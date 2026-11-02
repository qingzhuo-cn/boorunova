// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:async';

import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/foundation/network/dio_factory.dart';
import 'package:boorunova/foundation/util/batch_ops.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 站点连通性状态（OPT §5.4 站点健康面板）。
enum ServerHealthStatus {
  /// 还没检查过。
  unknown,

  /// 正在检查。
  checking,

  /// 连得上且够快。
  ok,

  /// 连得上但偏慢（≥ [ServerHealthProbe.slowThreshold]）。
  slow,

  /// 连得上但被拒绝：401/403。常见于 Cloudflare 拦截或需要凭据的站点。
  rejected,

  /// 连得上但服务端报错（4xx/5xx）。
  error,

  /// 连不上（超时 / DNS / 连接被拒）。
  unreachable,
}

@immutable
class ServerHealth {
  const ServerHealth({
    required this.status,
    this.latencyMs,
    this.httpStatus,
  });

  final ServerHealthStatus status;
  final int? latencyMs;
  final int? httpStatus;

  bool get isHealthy =>
      status == ServerHealthStatus.ok || status == ServerHealthStatus.slow;
}

class ServerHealthProbe {
  ServerHealthProbe._();

  /// 单次检查的超时。取 8s：比引擎请求（30s/60s）短得多——健康检查问的是
  /// 「现在连得上吗」，让用户等一分钟就失去意义了。
  static const Duration timeout = Duration(seconds: 8);

  /// 超过这个耗时算「慢」。1s 是移动网络下「响应头到达」的合理分界。
  static const Duration slowThreshold = Duration(seconds: 1);

  /// 把「状态码 + 耗时 + 异常」判定成健康状态。
  ///
  /// **纯函数**：这条映射有五个分支（正常/慢/被拒/服务端错/连不上），穷举各态
  /// 的测试只需调它，不必真起服务器。真实请求那部分只负责发一次 GET、把三样
  /// 东西交给它。
  static ServerHealth classify({
    int? httpStatus,
    Duration elapsed = Duration.zero,
    Object? error,
  }) {
    if (error != null) {
      return const ServerHealth(status: ServerHealthStatus.unreachable);
    }
    final code = httpStatus ?? 0;
    if (code == 0) {
      return const ServerHealth(status: ServerHealthStatus.unreachable);
    }
    final latency = elapsed.inMilliseconds;
    if (code == 401 || code == 403) {
      return ServerHealth(
        status: ServerHealthStatus.rejected,
        httpStatus: code,
        latencyMs: latency,
      );
    }
    if (code >= 200 && code < 400) {
      return ServerHealth(
        status: elapsed >= slowThreshold
            ? ServerHealthStatus.slow
            : ServerHealthStatus.ok,
        httpStatus: code,
        latencyMs: latency,
      );
    }
    return ServerHealth(
      status: ServerHealthStatus.error,
      httpStatus: code,
      latencyMs: latency,
    );
  }

  /// 对站点根路径发一次轻量 GET。
  ///
  /// 只关心「连得上吗、多快、被挡没」，所以：
  /// - 非 2xx 不抛异常（validateStatus 全放行），错误码本身就是要看的信息；
  /// - 拿到响应头就断开，**不把首页整页拉下来**——健康检查不该花用户的流量；
  /// - 用 [DioFactory.createProbe]（已带 UA 与 hosts 拦截），否则 Cloudflare
  ///   保护的站点会因缺 UA 被 403，面板把它们误报成「被拒绝」。
  static Future<ServerHealth> check(
    String baseUrl, {
    Dio? dio,
    Duration timeout = ServerHealthProbe.timeout,
  }) async {
    final client = dio ?? DioFactory.createProbe();
    final watch = Stopwatch()..start();
    try {
      final response = await client.get<ResponseBody>(
        baseUrl,
        options: Options(
          responseType: ResponseType.stream,
          validateStatus: (_) => true,
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );
      final elapsed = watch.elapsed;
      final body = response.data;
      if (body != null) {
        // 只测到响应头为止，正文直接丢掉
        unawaited(body.stream.listen(null).cancel());
      }
      return classify(httpStatus: response.statusCode, elapsed: elapsed);
    } catch (e) {
      return classify(error: e, elapsed: watch.elapsed);
    } finally {
      if (dio == null) client.close(force: true);
    }
  }
}

/// serverId → 最近一次检查结果。
final serverHealthProvider =
    NotifierProvider<ServerHealthNotifier, Map<String, ServerHealth>>(
  ServerHealthNotifier.new,
);

class ServerHealthNotifier extends Notifier<Map<String, ServerHealth>> {
  /// 并发上限：面板一次检查全部站点，串行在多站时慢得离谱，无上限又会同时
  /// 打十几个请求（用户可能正在浏览）。
  ///
  /// 分批走 [concurrencyBatches]（批量下载也用它）：分段逻辑不该有两份实现。
  static const int _maxConcurrency = defaultDownloadConcurrency;

  @override
  Map<String, ServerHealth> build() => const {};

  void _set(String serverId, ServerHealth health) {
    state = {...state, serverId: health};
  }

  /// 检查单个站点。[dio] 只为测试注入。
  Future<void> check(
    BooruServer server, {
    Dio? dio,
    Duration timeout = ServerHealthProbe.timeout,
  }) async {
    _set(
      server.id,
      const ServerHealth(status: ServerHealthStatus.checking),
    );
    final health = await ServerHealthProbe.check(
      server.baseUrl,
      dio: dio,
      timeout: timeout,
    );
    _set(server.id, health);
  }

  /// 检查全部站点（分块并发）。
  Future<void> checkAll(
    List<BooruServer> servers, {
    Dio? dio,
    Duration timeout = ServerHealthProbe.timeout,
  }) async {
    for (final (start, end)
        in concurrencyBatches(servers.length, _maxConcurrency)) {
      await Future.wait([
        for (var i = start; i < end; i++)
          check(servers[i], dio: dio, timeout: timeout),
      ]);
    }
  }

  void clear() => state = const {};
}
