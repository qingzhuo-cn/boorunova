import 'dart:convert';

import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

final userServerRepoProvider = Provider<UserServerRepo>((ref) {
  return UserServerRepo();
});

class UserServerRepo {
  Box get _box => HiveSetup.serversBox;
  Box get _settingsBox => HiveSetup.settingsBox;
  static const _orderKey = 'server_order';

  List<String> get _order {
    final raw = _settingsBox.get(_orderKey) as List?;
    if (raw == null) return [];
    return raw.cast<String>();
  }

  Future<void> _saveOrder(List<String> order) async {
    await _settingsBox.put(_orderKey, order);
  }

  List<BooruServer> getAll() {
    final servers = _box.values.map((v) {
      final map = jsonDecode(v as String) as Map<String, dynamic>;
      return BooruServer.fromJson(map);
    }).toList();

    final order = _order;
    if (order.isEmpty) return servers;

    final map = {for (final s in servers) s.id: s};
    final ordered = <BooruServer>[];
    for (final id in order) {
      if (map.containsKey(id)) {
        ordered.add(map.remove(id)!);
      }
    }
    ordered.addAll(map.values);
    return ordered;
  }

  Future<void> reorder(int oldIndex, int newIndex) {
    final order = _order;
    if (order.isEmpty) {
      final all = _box.keys.cast<String>().toList();
      if (newIndex > oldIndex) newIndex--;
      final item = all.removeAt(oldIndex);
      all.insert(newIndex, item);
      return _saveOrder(all);
    }
    if (newIndex > oldIndex) newIndex--;
    final item = order.removeAt(oldIndex);
    order.insert(newIndex, item);
    return _saveOrder(order);
  }

  BooruServer? getById(String id) {
    final raw = _box.get(id) as String?;
    if (raw == null) return null;
    return BooruServer.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(BooruServer server) async {
    await _box.put(server.id, jsonEncode(server.toJson()));
    final order = _order;
    if (!order.contains(server.id)) {
      order.add(server.id);
      await _saveOrder(order);
    }
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
    final order = _order;
    order.remove(id);
    await _saveOrder(order);
  }

  Future<void> update(BooruServer server) async {
    await save(server);
  }

  int get count => _box.length;
}
