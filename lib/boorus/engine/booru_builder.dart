import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:flutter/widgets.dart';

abstract class BooruBuilder {
  const BooruBuilder();

  Widget buildHomeScreen();
  Widget buildPostViewer(List<PostSummary> posts, int initialIndex);
  Widget buildPostDetails(PostSummary post);
}
