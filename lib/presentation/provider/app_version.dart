import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

final appVersionProvider = Provider<String>((ref) {
  final info = ref.watch(packageInfoProvider).asData?.value;
  return info?.version ?? '1.0.0';
});
