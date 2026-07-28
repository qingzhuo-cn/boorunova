import 'package:boorunova/boorus/engine/booru_builder.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:flutter/widgets.dart';

class DanbooruBuilder extends BooruBuilder {
  @override
  Widget buildHomeScreen() {
    throw UnimplementedError('Danbooru uses default home screen');
  }

  @override
  Widget buildPostViewer(List<PostSummary> posts, int initialIndex) {
    throw UnimplementedError('Danbooru uses default post viewer');
  }

  @override
  Widget buildPostDetails(PostSummary post) {
    throw UnimplementedError('Danbooru uses default post details');
  }
}
