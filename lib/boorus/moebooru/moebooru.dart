import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';

class Moebooru extends Booru {
  const Moebooru();

  @override
  BooruType get type => BooruType.moebooru;

  @override
  String get id => 'moebooru';

  @override
  String get name => 'Moebooru';

  @override
  String get baseUrl => 'https://yande.re';

  @override
  BooruCapabilities get capabilities => const BooruCapabilities(
        favorites: true,
        comments: true,
        tagTranslation: true,
      );

  @override
  Map<String, String> get defaultHeaders => {
        'User-Agent': 'BooruNova/1.0',
        'Accept': 'application/json',
      };

  @override
  String? get loginUrl => '${baseUrl}user/login';
}
