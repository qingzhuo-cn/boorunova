import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:dio/dio.dart';

class BooruEngine {
  const BooruEngine({
    required this.booru,
    required this.repositoryFactory,
  });

  final Booru booru;
  final BooruRepository Function(Dio dio, {String? serverId}) repositoryFactory;
}
