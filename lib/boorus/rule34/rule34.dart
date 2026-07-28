import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';

class Rule34 extends Booru {
  const Rule34();

  @override
  BooruType get type => BooruType.rule34;

  @override
  String get id => 'rule34';

  @override
  String get name => 'Rule34';

  @override
  String get baseUrl => 'https://api.rule34.xxx';

  @override
  BooruCapabilities get capabilities => const BooruCapabilities(
        favorites: false,
        comments: false,
      );

  @override
  Map<String, String> get defaultHeaders => {
        'User-Agent': 'BooruNova/1.0',
        'Accept': 'application/json',
      };

  @override
  String? get loginUrl => null;
}
