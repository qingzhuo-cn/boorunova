import 'dart:convert';

import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final searchHistoryRepoProvider = Provider<SearchHistoryRepo>((ref) {
  return SearchHistoryRepo();
});

class SearchHistoryRepo {
  static const _key = 'search_history';

  List<String> getAll() {
    final raw = HiveSetup.settingsBox.get(_key) as String?;
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.cast<String>();
  }

  Future<void> add(String query) async {
    final all = getAll();
    all.remove(query);
    all.insert(0, query);
    if (all.length > 20) all.removeRange(20, all.length);
    await HiveSetup.settingsBox.put(_key, jsonEncode(all));
  }

  Future<void> remove(String query) async {
    final all = getAll();
    all.remove(query);
    await HiveSetup.settingsBox.put(_key, jsonEncode(all));
  }

  Future<void> clear() async {
    await HiveSetup.settingsBox.delete(_key);
  }

  Future<void> replaceAll(List<String> items) async {
    await HiveSetup.settingsBox.put(_key, jsonEncode(items.take(20).toList()));
  }
}
