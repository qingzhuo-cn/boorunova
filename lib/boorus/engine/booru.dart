import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';

abstract class Booru {
  const Booru();

  BooruType get type;
  String get id;
  String get name;
  String get baseUrl;
  BooruCapabilities get capabilities;
  Map<String, String> get defaultHeaders;

  String? get loginUrl;
}
