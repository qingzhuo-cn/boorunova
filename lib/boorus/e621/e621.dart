import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';

class E621 extends Booru {
  const E621();

  @override
  BooruType get type => BooruType.e621;

  @override
  String get id => 'e621';

  @override
  String get name => 'e621';

  @override
  String get baseUrl => 'https://e621.net';

  @override
  BooruCapabilities get capabilities => const BooruCapabilities(
        pools: true,
        favorites: true,
        comments: true,
      );

  @override
  Map<String, String> get defaultHeaders => {
        'User-Agent': 'BooruNova/1.0 (by boorunova on e621)',
        'Accept': 'application/json',
      };

  @override
  String? get loginUrl => null;
}
