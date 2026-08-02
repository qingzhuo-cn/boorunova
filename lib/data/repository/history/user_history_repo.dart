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
    this.serverId = '',
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
        serverId: post.serverId,
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
        postId: json['postId']?.toString() ?? '',
        serverId: json['serverId']?.toString() ?? '',
        thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
        sampleUrl: json['sampleUrl']?.toString() ?? '',
        originalUrl: json['originalUrl']?.toString() ?? '',
        tags: json['tags'] is List ? List<String>.from(json['tags'] as List) : [],
        width: json['width'] is int ? json['width'] as int : 0,
        height: json['height'] is int ? json['height'] as int : 0,
        rating: json['rating']?.toString() ?? 'q',
        score: json['score'] is int ? json['score'] as int : 0,
        viewedAt: json['viewedAt'] != null
            ? DateTime.tryParse(json['viewedAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  final String postId;
  final String serverId;
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
        'serverId': serverId,
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
    all.removeWhere((e) => e.postId == post.id && e.serverId == post.serverId);
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
