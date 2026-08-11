import 'package:boorunova/foundation/network/hosts_interceptor.dart';
import 'package:dio/dio.dart';

/// 统一 Dio 工厂：一处配置超时、UA、hosts 拦截，全项目共用。
class DioFactory {
  DioFactory._();

  /// 引擎 API 请求：长接收超时（图站列表可能慢）
  static Dio create({
    String? baseUrl,
    Map<String, dynamic>? headers,
    HostsInterceptor? hostsInterceptor,
  }) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? '',
      headers: headers,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
    ));
    if (hostsInterceptor != null) dio.interceptors.add(hostsInterceptor);
    return dio;
  }

  /// 引擎探测：短超时快速失败
  static Dio createProbe({
    HostsInterceptor? hostsInterceptor,
  }) {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (s) => s == 200,
    ));
    if (hostsInterceptor != null) dio.interceptors.add(hostsInterceptor);
    return dio;
  }

  /// 文件下载：无接收超时限制，挂 hosts 拦截保证自定义映射生效
  static Dio createDownload({
    HostsInterceptor? hostsInterceptor,
  }) {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
    ));
    if (hostsInterceptor != null) dio.interceptors.add(hostsInterceptor);
    return dio;
  }
}
