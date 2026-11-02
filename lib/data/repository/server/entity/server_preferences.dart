// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/json_coerce.dart';
import 'package:boorunova/foundation/util/download_paths.dart';
import 'package:flutter/foundation.dart';

/// 站点级偏好（文档 §6.4「按站点配置的借鉴」）。
///
/// 设计口径：
/// - **每一项都可以「跟随全局」**（null / 空串），默认就是跟随，所以老数据、
///   新加站点都不需要迁移，行为与从前一致；
/// - **全部免费**：按站点配置属于核心可用性，不做成 Plus 门槛；
/// - 安全模式（Play 合规）**不受**这里的设置放宽——站点选了限制级，安全模式
///   下仍然只取安全档，见 `effectiveRatingForServer`。
@immutable
class ServerPreferences {
  const ServerPreferences({
    this.visibleRating,
    this.previewQuality,
    this.downloadQuality,
    this.downloadSubdir = '',
    this.defaultSort,
  });

  factory ServerPreferences.fromJson(Map<String, dynamic> json) =>
      ServerPreferences(
        // 逐项宽容取值：老的 / 手改过的记录不能让整条站点读取失败
        visibleRating: _rating(asStrOrNull(json['visibleRating'])),
        previewQuality: _quality(asStrOrNull(json['previewQuality'])),
        downloadQuality: _quality(asStrOrNull(json['downloadQuality'])),
        downloadSubdir: sanitizeSubdir(asStrOrNull(json['downloadSubdir']) ?? ''),
        defaultSort: _sort(asStrOrNull(json['defaultSort'])),
      );

  /// 站点默认可见评级（`s` / `q` / `e`）；null = 跟随全局（含安全模式）。
  final String? visibleRating;

  /// 站点默认**预览**画质（`original` / `sample`）；null = 跟随全局。
  ///
  /// 与下载画质分开：预览决定「查看器加载哪张」，下载决定「存下来哪张」。
  /// 常见组合是「预览用 sample 省流量、下载存原图」。
  final String? previewQuality;

  /// 站点默认下载画质（`original` / `sample`）；null = 跟随全局。
  final String? downloadQuality;

  /// 下载子目录（相对全局下载目录）。空串 = 直接放全局目录。
  final String downloadSubdir;

  /// 站点默认排序（`score` / `date` / `rating`）；null = 用搜索页当前选择。
  ///
  /// 存语义键而不是 `order:score` 这类元标签：元标签是「拼进查询串的写法」，
  /// 属于 UI 与引擎之间的约定，偏好里存它会让站点偏好跟着查询语法走。
  final String? defaultSort;

  static const List<String> ratingValues = ['s', 'q', 'e'];
  static const List<String> qualityValues = ['original', 'sample'];
  static const List<String> sortValues = ['score', 'date', 'rating'];

  /// 只接受已知取值，其余按「未设置」处理：脏值不该让 UI 显示一个不存在的档位。
  static String? _rating(String? raw) =>
      raw != null && ratingValues.contains(raw) ? raw : null;

  static String? _quality(String? raw) =>
      raw != null && qualityValues.contains(raw) ? raw : null;

  static String? _sort(String? raw) =>
      raw != null && sortValues.contains(raw) ? raw : null;

  /// 子目录消毒。规则本身住在路径层（[sanitizeSubdirName]）——那是真正
  /// 拼路径、也是真正需要防越权的地方；这里只是转调，保证「存进来的值」
  /// 与「拼出去的值」用同一套口径。
  static String sanitizeSubdir(String raw) => sanitizeSubdirName(raw);

  /// 是否等同于「全部跟随全局」。
  bool get isEmpty =>
      visibleRating == null &&
      previewQuality == null &&
      downloadQuality == null &&
      downloadSubdir.isEmpty &&
      defaultSort == null;

  bool get isNotEmpty => !isEmpty;

  ServerPreferences copyWith({
    String? visibleRating,
    String? previewQuality,
    String? downloadQuality,
    String? downloadSubdir,
    String? defaultSort,
    bool clearVisibleRating = false,
    bool clearPreviewQuality = false,
    bool clearDownloadQuality = false,
    bool clearDefaultSort = false,
  }) =>
      ServerPreferences(
        visibleRating: clearVisibleRating
            ? null
            : (visibleRating ?? this.visibleRating),
        previewQuality: clearPreviewQuality
            ? null
            : (previewQuality ?? this.previewQuality),
        downloadQuality: clearDownloadQuality
            ? null
            : (downloadQuality ?? this.downloadQuality),
        downloadSubdir: downloadSubdir == null
            ? this.downloadSubdir
            : sanitizeSubdir(downloadSubdir),
        defaultSort: clearDefaultSort
            ? null
            : (defaultSort ?? this.defaultSort),
      );

  Map<String, dynamic> toJson() => {
        if (visibleRating != null) 'visibleRating': visibleRating,
        if (previewQuality != null) 'previewQuality': previewQuality,
        if (downloadQuality != null) 'downloadQuality': downloadQuality,
        if (downloadSubdir.isNotEmpty) 'downloadSubdir': downloadSubdir,
        if (defaultSort != null) 'defaultSort': defaultSort,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerPreferences &&
          visibleRating == other.visibleRating &&
          previewQuality == other.previewQuality &&
          downloadQuality == other.downloadQuality &&
          downloadSubdir == other.downloadSubdir &&
          defaultSort == other.defaultSort;

  @override
  int get hashCode => Object.hash(
        visibleRating,
        previewQuality,
        downloadQuality,
        downloadSubdir,
        defaultSort,
      );
}
