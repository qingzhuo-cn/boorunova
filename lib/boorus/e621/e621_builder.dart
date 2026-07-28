import 'package:boorunova/boorus/engine/booru_builder.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:flutter/widgets.dart';

class E621Builder extends BooruBuilder {
  const E621Builder();

  @override
  Widget buildHomeScreen() {
    throw UnimplementedError('Uses default home screen');
  }

  @override
  Widget buildPostViewer(List<PostSummary> posts, int initialIndex) {
    throw UnimplementedError('Uses default post viewer');
  }

  @override
  Widget buildPostDetails(PostSummary post) {
    throw UnimplementedError('Uses default post details');
  }
}
