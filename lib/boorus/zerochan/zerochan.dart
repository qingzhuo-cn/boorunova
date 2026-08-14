import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';

class Zerochan extends Booru {
  const Zerochan();

  @override
  BooruType get type => BooruType.zerochan;

  @override
  String get id => 'zerochan';

  @override
  String get name => 'Zerochan';

  @override
  String get baseUrl => 'https://www.zerochan.net';

  @override
  BooruCapabilities get capabilities => const BooruCapabilities(        comments: false,
      );

  @override
  Map<String, String> get defaultHeaders => {
        'User-Agent': 'BooruNova/1.0',
        'Accept': 'application/json',
      };

  @override
  String? get loginUrl => null;
}
