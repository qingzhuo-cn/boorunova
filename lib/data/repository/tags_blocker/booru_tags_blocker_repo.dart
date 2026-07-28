import 'package:boorunova/data/repository/tags_blocker/entity/booru_tag.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';

class BooruTagsBlockerRepo {
  static const _key = 'blocked_tags';

  Map<int, BooruTag> getAll() {
    final raw = HiveSetup.settingsBox.get(_key);
    if (raw is List) {
      final map = <int, BooruTag>{};
      for (int i = 0; i < raw.length; i++) {
        if (raw[i] is Map) {
          map[i] = BooruTag.fromJson(Map<String, dynamic>.from(raw[i] as Map));
        }
      }
      return map;
    }
    return {};
  }

  Future<void> push(BooruTag tag) async {
    final all = getAll();
    if (tag.name.trim().isEmpty) return;
    if (all.values.any((t) => t.name == tag.name.trim())) return;
    final index = all.isEmpty ? 0 : all.keys.reduce((a, b) => a > b ? a : b) + 1;
    all[index] = tag.copyWith(name: tag.name.trim());
    await _save(all);
  }

  Future<void> pushAll({String serverId = '', required List<String> tags}) async {
    for (final tag in tags) {
      await push(BooruTag(serverId: serverId, name: tag));
    }
  }

  Future<void> delete(int key) async {
    final all = getAll();
    all.remove(key);
    await _save(all);
  }

  Future<void> _save(Map<int, BooruTag> tags) async {
    await HiveSetup.settingsBox.put(
      _key,
      tags.values.map((t) => t.toJson()).toList(),
    );
  }

  List<String> getBlockedTagNames({String? serverId}) {
    final all = getAll();
    return all.values
        .where((t) => serverId == null || t.serverId.isEmpty || t.serverId == serverId)
        .map((t) => t.name)
        .toList();
  }
}
