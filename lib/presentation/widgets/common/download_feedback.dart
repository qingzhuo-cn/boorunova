// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/foundation/util/image_downloader.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:flutter/material.dart';

/// 两次限流提示之间至少隔这么久。
const Duration kRateLimitNoticeGap = Duration(seconds: 5);

/// 上一次提示的时间。放在模块级是因为「同一批下载」没有别的共享作用域：
/// 批量下载并发 3–6 个条目，服务端限流时它们几乎同时命中 429，逐条弹出会
/// 变成十几条排队，下载早就结束了提示还在刷。
DateTime? _lastRateLimitNoticeAt;

/// 仅测试用：重置节流状态，避免用例之间互相影响。
@visibleForTesting
void resetRateLimitNoticeThrottle() => _lastRateLimitNoticeAt = null;

/// 判断这次限流提示是否该真的弹出去，并推进节流时间戳。
///
/// 抽成函数是因为 **SnackBar 会排队**：界面上只数得出正在显示的那一条，
/// 被节流丢掉的几条根本进不了 widget 树，用例没法用「数提示条」来验证
/// 节流是否生效。这里直接断言判断本身。
@visibleForTesting
bool consumeRateLimitNoticeSlot(DateTime at) {
  final last = _lastRateLimitNoticeAt;
  if (last != null && at.difference(last) < kRateLimitNoticeGap) {
    return false;
  }
  _lastRateLimitNoticeAt = at;
  return true;
}

/// 限流等待提示（OPT §3.8）。
///
/// 与 [downloadResultMessage] 同一处的原因相同：下载入口有好几个，
/// 「服务器限流，N 秒后重试」这句话必须哪儿都一样，否则用户读到的
/// 是同一件事的不同说法。
///
/// [now] 只为可测：节流判断需要时间，直接读 DateTime.now() 的话用例没法
/// 稳定地验证「第二次被丢掉」。
///
/// 弹之前必须确认**真有 Scaffold**：[ScaffoldMessenger.maybeOf] 只保证
/// 「有 messenger」（MaterialApp 在根上就装了一个），不保证「有 Scaffold」；
/// 那时 showSnackBar 会因为 `_scaffolds.isNotEmpty` 断言失败直接崩。
/// 这个函数被四个下载入口共用，不能假设调用点一定有 Scaffold。
void showRateLimitNotice(
  BuildContext context,
  Duration retryIn, {
  DateTime? now,
}) {
  if (context.findAncestorWidgetOfExactType<Scaffold>() == null) return;

  // 节流窗口内：同一批里已经提示过了，不再重复打扰
  if (!consumeRateLimitNoticeSlot(now ?? DateTime.now())) return;

  final seconds = retryIn.inSeconds.clamp(1, 60);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(T.rateLimitedRetry(seconds)),
      duration: Duration(seconds: seconds + 1),
    ),
  );
}

/// 下载结果 → 给用户看的一句话。
///
/// 下载入口有四处（查看器 / 收藏 / 详情 / 批量），此前每处各抄一遍同样的
/// if 链。新增一种失败原因（比如「挂起超时」）时必然漏掉几处，用户只看到
/// 笼统的「下载失败」，没法判断该重试还是该去授权。收成一处。
String downloadResultMessage(DownloadResult result) {
  if (!result.success) {
    if (result.error == kGalleryPermissionDenied) {
      return T.galleryPermissionDenied;
    }
    if (result.error == kDownloadStalled) {
      // 与「网络错误」区分：这里要明确告诉用户「重试」是有效动作
      return T.downloadStalled;
    }
    return T.downloadFailed;
  }
  if (result.alreadySaved) return T.alreadySaved;
  if (result.warning == kGalleryRecordFailed) return T.savedWithoutRecord;
  return T.savedToGallery;
}
