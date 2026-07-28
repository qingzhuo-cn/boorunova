import 'package:boorunova/data/repository/tags_blocker/booru_tags_blocker_repo.dart';
import 'package:boorunova/data/repository/tags_blocker/entity/booru_tag.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tagsBlockerRepoProvider = Provider<BooruTagsBlockerRepo>((ref) {
  return BooruTagsBlockerRepo();
});

final tagsBlockerStateProvider =
    StateNotifierProvider<TagsBlockerNotifier, Map<int, BooruTag>>((ref) {
  final repo = ref.read(tagsBlockerRepoProvider);
  return TagsBlockerNotifier(repo);
});

class TagsBlockerNotifier extends StateNotifier<Map<int, BooruTag>> {
  TagsBlockerNotifier(this._repo) : super(_repo.getAll());

  final BooruTagsBlockerRepo _repo;

  Future<void> push({String serverId = '', required String tag}) async {
    await _repo.push(BooruTag(serverId: serverId, name: tag));
    state = _repo.getAll();
  }

  Future<void> pushAll({String serverId = '', required List<String> tags}) async {
    await _repo.pushAll(serverId: serverId, tags: tags);
    state = _repo.getAll();
  }

  Future<void> delete(int key) async {
    await _repo.delete(key);
    state = _repo.getAll();
  }
}
