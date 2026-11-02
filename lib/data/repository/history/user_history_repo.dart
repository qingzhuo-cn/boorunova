// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/database/json_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

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
    this.postUrl,
    this.isVideo = false,
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
        postUrl: post.postUrl,
        // 视频标记必须一起存：否则从历史重开视频帖又会被当成图片帖
        isVideo: post.isVideo,
      );

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        postId: json['postId']?.toString() ?? '',
        serverId: json['serverId']?.toString() ?? '',
        thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
        sampleUrl: json['sampleUrl']?.toString() ?? '',
        originalUrl: json['originalUrl']?.toString() ?? '',
        tags:
            json['tags'] is List ? List<String>.from(json['tags'] as List) : [],
        width: json['width'] is int ? json['width'] as int : 0,
        height: json['height'] is int ? json['height'] as int : 0,
        rating: json['rating']?.toString() ?? 'q',
        score: json['score'] is int ? json['score'] as int : 0,
        viewedAt: json['viewedAt'] != null
            ? DateTime.tryParse(json['viewedAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        postUrl: json['postUrl']?.toString(),
        isVideo: json['isVideo'] == true,
      );

  /// 还原为 [PostSummary]，让历史记录能直接喂给查看器。
  /// 历史里已经存了查看所需的全部字段（缩略图/大图/标签/尺寸/分级），
  /// 不需要回站点重新拉取——历史页此前没有 onTap，等于这些字段白存。
  PostSummary toPostSummary() => PostSummary(
        id: postId,
        serverId: serverId,
        thumbnailUrl: thumbnailUrl,
        sampleUrl: sampleUrl,
        originalUrl: originalUrl,
        tags: tags,
        width: width,
        height: height,
        rating: rating,
        score: score,
        postUrl: postUrl,
        isVideo: isVideo,
        // 历史不存 aspectRatio；用真实像素兜底，避免退化成 1:1 拉伸。
        aspectRatio: (width > 0 && height > 0) ? width / height : 1.0,
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
  final String? postUrl;

  /// 视频帖标记：跟着历史一起存，重开时才知道该拉播放地址而不是当图片显示。
  final bool isVideo;

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
        'postUrl': postUrl,
        'isVideo': isVideo,
      };
}

class UserHistoryRepo {
  static const _key = 'history';

  /// 历史上限。
  static const int maxEntries = 200;

  static JsonListStore get _store => JsonListStore(HiveSetup.settingsBox, _key);

  /// 内存缓存：与收藏同理，做成 static（仓库实例会随 invalidate 重建，
  /// 缓存跟着实例走就会出现两个快照互相覆盖）。写入统一走串行事务，
  /// 事务里读的是存储的最新值，不是这份缓存。
  static Box? _cacheBox;
  static List<HistoryEntry>? _cache;

  static List<HistoryEntry> _load() {
    final box = HiveSetup.settingsBox;
    if (!identical(_cacheBox, box)) {
      _cacheBox = box;
      _cache = null;
    }
    final cached = _cache;
    if (cached != null) return cached;
    _adopt(_store.read());
    return _cache!;
  }

  static void _adopt(List<Map<String, dynamic>> items) {
    _cache = items
        .map((m) {
          try {
            return HistoryEntry.fromJson(m);
          } catch (_) {
            return null;
          }
        })
        .whereType<HistoryEntry>()
        .toList();
  }

  /// 返回缓存内容的**不可变副本**。
  ///
  /// 此前直接返回内部缓存引用：任何调用方一句 `getAll().remove(...)` 或
  /// `getAll().add(...)` 都会绕过写队列改动缓存，下次 `add/remove`
  /// 事务里读到的就不是存储的真实内容。收藏侧早就用 `List.unmodifiable`
  /// 防住了同样的模式，历史这边漏了。
  List<HistoryEntry> getAll() => List.unmodifiable(_load());

  Future<void> add(PostSummary post) async {
    final written = await _store.update((items) {
      final next = items
          .where((m) =>
              !('${m['postId'] ?? ''}' == post.id &&
                  '${m['serverId'] ?? ''}' == post.serverId))
          .toList();
      next.insert(0, HistoryEntry.fromPost(post).toJson());
      if (next.length > maxEntries) {
        next.removeRange(maxEntries, next.length);
      }
      return next;
    });
    _adopt(written);
  }

  /// 删除单条历史。[serverId] 传入时按 postId + serverId 精确定位——
  /// 不同站点的 post id 会重复，只按 postId 删会误伤同名条目。
  /// 传 null 则删除所有站点下该 id 的条目。
  Future<void> remove(String postId, {String? serverId}) async {
    final written = await _store.update((items) {
      return items.where((m) {
        if ('${m['postId'] ?? ''}' != postId) return true;
        if (serverId == null) return false;
        return '${m['serverId'] ?? ''}' != serverId;
      }).toList();
    });
    _adopt(written);
  }

  Future<void> clear() async {
    await _store.clear();
    _cache = [];
  }

  /// 覆盖写入（备份导入用）。
  Future<void> replaceAll(List<HistoryEntry> entries) async {
    final encoded = entries.map((e) => e.toJson()).toList();
    await _store.write(encoded);
    _adopt(encoded);
  }

  int get count => _load().length;
}
