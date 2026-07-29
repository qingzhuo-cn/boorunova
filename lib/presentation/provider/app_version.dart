import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final packageInfoProvider = Provider<PackageInfo>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

final appVersionProvider = Provider<String>((ref) {
  return ref.watch(packageInfoProvider).version;
});
