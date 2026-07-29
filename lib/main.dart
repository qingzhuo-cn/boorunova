import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/presentation/booru_nova.dart';
import 'package:boorunova/presentation/provider/app_version.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveSetup.init();

  final packageInfo = await PackageInfo.fromPlatform();
  final container = ProviderContainer(overrides: [
    appVersionProvider.overrideWith((ref) => packageInfo.version),
  ]);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BooruNova(),
    ),
  );
}