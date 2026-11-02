// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'dart:async';

import 'package:boorunova/foundation/network/dio_factory.dart';
import 'package:boorunova/foundation/util/image_downloader.dart';
import 'package:dio/dio.dart';

/// 批量下载并发数的取值范围与默认值。
///
/// 边界只在这里定义：设置 UI（滑杆）、设置反序列化（老数据/手改）与下载分批
/// 三处共用同一组值。各写一遍必然出现「UI 能选 6，实际被夹到 3」这类不一致。
const int minDownloadConcurrency = 1;
const int maxDownloadConcurrency = 6;
const int defaultDownloadConcurrency = 3;

/// 按并发上限把 [total] 个任务切成 `[start, end)` 批次。
///
/// 单独成纯函数是为了能直接测边界：并发 1（串行）、正好整除、最后一批不满、
/// 越界输入被夹紧。
List<(int, int)> concurrencyBatches(int total, int concurrency) {
  if (total <= 0) return const [];
  final parallel =
      concurrency.clamp(minDownloadConcurrency, maxDownloadConcurrency);
  final batches = <(int, int)>[];
  for (var start = 0; start < total; start += parallel) {
    final end = (start + parallel) < total ? start + parallel : total;
    batches.add((start, end));
  }
  return batches;
}

class BatchOps {
  BatchOps._();

  /// 批量下载并写入图库。
  ///
  /// 实际下载、相册入库与记录写入全部交给 [ImageDownloader.downloadImage]：
  /// 此前 BatchOps 自己又写了一遍「扩展名判断 + 落盘 + Gal + 写记录」，
  /// 于是修一处漏一处（例如视频帖要按媒体类型分派，两个实现只改一个）。
  ///
  /// [cancelToken] 用于取消：用户在批量下载途中离开页面时停止后续请求。
  static Future<BatchDownloadResult> downloadAll(
    List<String> urls,
    List<String> postIds, {
    List<String>? namespaces,
    String downloadPath = '',
    /// 并发上限（1–6）。越界自动夹紧。
    int concurrency = defaultDownloadConcurrency,
    /// 每一条的下载子目录（站点级偏好）。整批可能跨站点（收藏、搜索结果），
    /// 所以按条目回调取值，而不是整批一个。
    String Function(String? serverId)? subdirFor,
    /// 某个条目因限流而等待时回调（转发自下载器）。批量下载时多个条目可能
    /// 同时被限流，界面侧自行去重/节流。
    void Function(Duration retryIn)? onRetryWait,
    void Function(int done, int total)? onItemProgress,
    CancelToken? cancelToken,
  }) async {
    final results = <BatchItem?>[];
    results.length = urls.length;
    var done = 0;

    // 整批共用一个 Dio：此前每张图都新建一个 HttpClient，N 张图 = N 个连接池，
    // 同域 keep-alive 全部作废、句柄等到 GC 才回收。
    final dio = DioFactory.createDownload();
    try {
      Future<void> runOne(int i) async {
        if (cancelToken?.isCancelled ?? false) {
          results[i] = BatchItem(
            url: urls[i],
            postId: i < postIds.length ? postIds[i] : null,
            success: false,
            error: 'cancelled',
          );
          done += 1;
          onItemProgress?.call(done, urls.length);
          return;
        }
        final id = i < postIds.length ? postIds[i] : null;
        final namespace =
            namespaces != null && i < namespaces.length ? namespaces[i] : null;
        final result = await ImageDownloader.downloadImage(
          urls[i],
          postId: id,
          namespace: namespace,
          downloadPath: downloadPath,
          downloadSubdir: subdirFor?.call(namespace) ?? '',
          dio: dio,
          cancelToken: cancelToken,
          onRetryWait: onRetryWait,
        );
        results[i] = BatchItem(
          url: urls[i],
          postId: id,
          success: result.success,
          error: result.error,
          warning: result.warning,
          alreadySaved: result.alreadySaved,
        );
        done += 1;
        onItemProgress?.call(done, urls.length);
      }

      // 分块并发：每批最多 concurrency 个，批次内 Future.wait。
      for (final (start, end) in concurrencyBatches(urls.length, concurrency)) {
        final batch = <Future<void>>[
          for (var i = start; i < end; i++) runOne(i),
        ];
        await Future.wait(batch, eagerError: false);
      }
    } finally {
      dio.close(force: true);
    }

    final nonNull = results.whereType<BatchItem>().toList();
    return BatchDownloadResult(
      items: nonNull,
      successCount: nonNull.where((r) => r.success).length,
      failCount: nonNull.where((r) => !r.success).length,
      skippedCount:
          nonNull.where((r) => r.success && r.alreadySaved).length,
      warningCount: nonNull
          .where((r) => r.success && r.warning != null && !r.alreadySaved)
          .length,
    );
  }
}

class BatchDownloadResult {
  const BatchDownloadResult({
    required this.items,
    required this.successCount,
    required this.failCount,
    this.skippedCount = 0,
    this.warningCount = 0,
  });

  final List<BatchItem> items;
  final int successCount;
  final int failCount;

  /// 因为「此前已保存过」而跳过的条数。
  final int skippedCount;

  /// 已进相册但记录没写成功的条数。
  final int warningCount;
}

class BatchItem {
  const BatchItem({
    required this.url,
    required this.success,
    this.postId,
    this.error,
    this.warning,
    this.alreadySaved = false,
  });

  final String url;

  /// 该条对应的帖子 id（可能为空）。
  ///
  /// 持久化队列（OPT §3.3）要按 `postId|url` 精确出队，所以结果里必须带上它
  /// —— 只按 URL 出队会在「同一媒体地址被两个帖子下载」时误删另一条。
  final String? postId;
  final bool success;
  final String? error;

  /// 成功但有瑕疵（已进相册、记录没写成功）。
  final String? warning;

  /// 该帖此前已保存过，本次没有真下载。
  final bool alreadySaved;
}
