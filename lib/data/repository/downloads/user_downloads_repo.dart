import 'dart:convert';

import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userDownloadsRepoProvider = Provider<UserDownloadsRepo>((ref) {
  return UserDownloadsRepo();
});

class DownloadEntry {
  const DownloadEntry({
    required this.postId,
    required this.imageUrl,
    required this.localPath,
    required this.downloadedAt,
    this.width,
    this.height,
  });

  factory DownloadEntry.fromJson(Map<String, dynamic> json) => DownloadEntry(
        postId: json['postId'] as String,
        imageUrl: json['imageUrl'] as String,
        localPath: json['localPath'] as String,
        downloadedAt: DateTime.parse(json['downloadedAt'] as String),
        width: json['width'] as int?,
        height: json['height'] as int?,
      );

  final String postId;
  final String imageUrl;
  final String localPath;
  final DateTime downloadedAt;
  final int? width;
  final int? height;

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'imageUrl': imageUrl,
        'localPath': localPath,
        'downloadedAt': downloadedAt.toIso8601String(),
        'width': width,
        'height': height,
      };
}

class UserDownloadsRepo {
  static const _key = 'downloads';

  List<DownloadEntry> getAll() {
    final raw = HiveSetup.settingsBox.get(_key) as String?;
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => DownloadEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(DownloadEntry entry) async {
    final all = getAll();
    all.insert(0, entry);
    if (all.length > 500) all.removeRange(500, all.length);
    await _save(all);
  }

  Future<void> remove(String postId) async {
    final all = getAll();
    all.removeWhere((e) => e.postId == postId);
    await _save(all);
  }

  Future<void> clear() async {
    await HiveSetup.settingsBox.delete(_key);
  }

  Future<void> saveAll(List<DownloadEntry> entries) async {
    final json = entries.map((e) => e.toJson()).toList();
    await HiveSetup.settingsBox.put(_key, jsonEncode(json));
  }

  int get count => getAll().length;

  Future<void> _save(List<DownloadEntry> entries) async {
    final json = entries.map((e) => e.toJson()).toList();
    await HiveSetup.settingsBox.put(_key, jsonEncode(json));
  }
}
