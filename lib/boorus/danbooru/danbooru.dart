import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';

class Danbooru extends Booru {
  const Danbooru();

  @override
  BooruType get type => BooruType.danbooru;

  @override
  String get id => 'danbooru';

  @override
  String get name => 'Danbooru';

  @override
  String get baseUrl => 'https://danbooru.donmai.us';

  @override
  BooruCapabilities get capabilities => const BooruCapabilities(
        pools: true,
        forums: true,
        comments: true,
        notes: true,
        voting: true,
        artistPages: true,
        characterPages: true,
        favorites: true,
        syntaxHighlighting: true,
      );

  @override
  Map<String, String> get defaultHeaders => {
        'User-Agent': 'BooruNova/1.0',
        'Accept': 'application/json',
      };

  @override
  String? get loginUrl => '$baseUrl/login';
}
