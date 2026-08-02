import 'package:boorunova/data/repository/hosts/user_hosts_repo.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:dio/dio.dart';

class HostsInterceptor extends Interceptor {
  HostsInterceptor({required this.enabled, required UserHostsRepo repo})
      : _repo = repo;

  final UserHostsRepo _repo;
  bool enabled;

  bool get _isActive {
    if (enabled) return true;
    try {
      final raw = HiveSetup.settingsBox.get('app_settings');
      if (raw is Map) {
        return raw['hostsEnabled'] == true;
      }
    } catch (_) {}
    return false;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_isActive) return handler.next(options);

    final url = options.baseUrl.isNotEmpty
        ? Uri.tryParse(options.baseUrl)
        : null;
    if (url == null || url.host.isEmpty) return handler.next(options);

    final mapping = _repo.match(url.host);
    if (mapping == null) return handler.next(options);

    final path = options.path.startsWith('/')
        ? options.path
        : '/${options.path}';
    final newUrl = Uri(
      scheme: 'http',
      host: mapping.ip,
      path: path,
      queryParameters: options.queryParameters.isNotEmpty
          ? options.queryParameters.map((k, v) => MapEntry(k, v.toString()))
          : null,
    );

    options.baseUrl = 'http://${mapping.ip}';
    options.path = newUrl.path;
    options.queryParameters.clear();
    options.headers['Host'] = url.host;

    handler.next(options);
  }
}
