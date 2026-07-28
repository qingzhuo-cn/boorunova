import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';

class GelbooruV2 extends Booru {
  const GelbooruV2();

  @override
  BooruType get type => BooruType.gelbooruV2;

  @override
  String get id => 'gelbooru_v2';

  @override
  String get name => 'Gelbooru v2';

  @override
  String get baseUrl => 'https://gelbooru.com';

  @override
  BooruCapabilities get capabilities => const BooruCapabilities(
        favorites: true,
        comments: true,
      );

  @override
  Map<String, String> get defaultHeaders => {
        'User-Agent': 'BooruNova/1.0',
        'Accept': 'application/xml',
      };

  @override
  String? get loginUrl => null;
}
