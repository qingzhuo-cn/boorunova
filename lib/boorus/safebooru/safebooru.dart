import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';

class Safebooru extends Booru {
  const Safebooru();

  @override
  BooruType get type => BooruType.safebooru;

  @override
  String get id => 'safebooru';

  @override
  String get name => 'Safebooru';

  @override
  String get baseUrl => 'https://safebooru.org';

  @override
  BooruCapabilities get capabilities => const BooruCapabilities(        comments: true,
      );

  @override
  Map<String, String> get defaultHeaders => {
        'User-Agent': 'BooruNova/1.0',
        'Accept': 'application/xml',
      };

  @override
  String? get loginUrl => null;
}
