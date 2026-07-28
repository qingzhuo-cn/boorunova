import 'dart:convert';

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userHistoryRepoProvider = Provider<UserHistoryRepo>((ref) {
  return UserHistoryRepo();
});

class HistoryEntry {
  const HistoryEntry({
    required this.postId,
    required this.thumbnailUrl,
    required this.sampleUrl,
    required this.originalUrl,
    required this.tags,
    required this.width,
    required this.height,
    required this.rating,
    required this.score,
    required this.viewedAt,
  });

  factory HistoryEntry.fromPost(PostSummary post) => HistoryEntry(
        postId: post.id,
        thumbnailUrl: post.thumbnailUrl,
        sampleUrl: post.sampleUrl,
        originalUrl: post.originalUrl,
        tags: post.tags,
        width: post.width,
        height: post.height,
        rating: post.rating,
        score: post.score,
        viewedAt: DateTime.now(),
      );

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        postId: json['postId'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String,
        sampleUrl: json['sampleUrl'] as String,
        originalUrl: json['originalUrl'] as String,
        tags: List<String>.from(json['tags'] as List),
        width: json['width'] as int,
        height: json['height'] as int,
        rating: json['rating'] as String,
        score: json['score'] as int,
        viewedAt: DateTime.parse(json['viewedAt'] as String),
      );

  final String postId;
  final String thumbnailUrl;
  final String sampleUrl;
  final String originalUrl;
  final List<String> tags;
  final int width;
  final int height;
  final String rating;
  final int score;
  final DateTime viewedAt;

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'thumbnailUrl': thumbnailUrl,
        'sampleUrl': sampleUrl,
        'originalUrl': originalUrl,
        'tags': tags,
        'width': width,
        'height': height,
        'rating': rating,
        'score': score,
        'viewedAt': viewedAt.toIso8601String(),
      };
}

class UserHistoryRepo {
  static const _key = 'history';

  List<HistoryEntry> getAll() {
    final raw = HiveSetup.settingsBox.get(_key) as String?;
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(PostSummary post) async {
    final all = getAll();
    all.removeWhere((e) => e.postId == post.id);
    all.insert(0, HistoryEntry.fromPost(post));
    if (all.length > 200) all.removeRange(200, all.length);
    await _save(all);
  }

  Future<void> clear() async {
    await HiveSetup.settingsBox.delete(_key);
  }

  int get count => getAll().length;

  Future<void> _save(List<HistoryEntry> entries) async {
    final json = entries.map((e) => e.toJson()).toList();
    await HiveSetup.settingsBox.put(_key, jsonEncode(json));
  }
}
