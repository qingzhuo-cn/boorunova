import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_builder.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:dio/dio.dart';

class BooruEngine {
  const BooruEngine({
    required this.booru,
    required this.repositoryFactory,
    required this.builderFactory,
  });

  final Booru booru;
  final BooruRepository Function(Dio dio, {String? serverId}) repositoryFactory;
  final BooruBuilder Function() builderFactory;
}
