import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';

class Sankaku extends Booru {
  const Sankaku();

  @override
  BooruType get type => BooruType.sankaku;

  @override
  String get id => 'sankaku';

  @override
  String get name => 'Sankaku Complex';

  @override
  String get baseUrl => 'https://chan.sankakucomplex.com';

  @override
  BooruCapabilities get capabilities => const BooruCapabilities(
        favorites: true,
        comments: true,
      );

  @override
  Map<String, String> get defaultHeaders => {
        'User-Agent': 'BooruNova/1.0',
        'Accept': 'application/json',
      };

  @override
  String? get loginUrl => '${baseUrl}/user/login';
}
