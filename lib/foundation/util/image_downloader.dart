// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:async';
import 'dart:io';

import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/foundation/network/dio_factory.dart';
import 'package:boorunova/foundation/util/download_paths.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

typedef OnProgress = void Function(double progress);

/// 相册访问被拒时 [DownloadResult.error] 的哨兵值。
///
/// UI 层据此换成可读的本地化文案（照 [kNoServerSelected] 的模式），
/// 而不是把平台异常原文丢给用户。
const String kGalleryPermissionDenied = 'gallery_permission_denied';

/// 下载挂起：连接建好后长时间收不到任何数据，已由看门狗中止。
///
/// 与「网络错误」分开，UI 才能给出「请重试」而不是把 Dio 异常原文丢出去。
const String kDownloadStalled = 'download_stalled';

/// 「无进展即中止」的看门狗。
///
/// 单独成类是为了**能直接单测**：网络层在测试绑定下不会逐块送达 chunked
/// 响应体（实测：服务端 flush 了、客户端流也要等响应结束才给出数据），
/// 而这段判定恰恰最容易写反——按「总耗时」判会杀掉正常的大文件下载，
/// 按「dio 的进度回调」判又会漏掉所有不带 Content-Length 的响应。
///
/// 口径：每个检查周期内必须至少有一次 [noteProgress]，否则视为挂起。
@visibleForTesting
class StallWatchdog {
  StallWatchdog({
    required this.timeout,
    required this.onStall,
    Duration? interval,
  }) : interval = interval ?? timeout;

  /// 多久没有任何进展就判为挂起。
  final Duration timeout;

  /// 检查周期，默认与 [timeout] 相同。
  final Duration interval;

  final void Function() onStall;

  Timer? _timer;
  bool _progressed = false;
  bool _stalled = false;

  bool get isStalled => _stalled;

  /// 记一次进展（收到数据即调用）。
  void noteProgress() {
    _progressed = true;
  }

  void start() {
    _timer ??= Timer.periodic(interval, (_) {
      if (_progressed) {
        _progressed = false;
        return;
      }
      _stalled = true;
      onStall();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

/// 下载挂起（连接建立后长时间无数据）。
class DownloadStalledException implements Exception {
  const DownloadStalledException();

  @override
  String toString() => 'DownloadStalledException';
}

/// 已进相册但下载记录没写成功（磁盘满 / box 被隔离）。
///
/// 必须与「下载失败」区分：文件确实在相册里，用户按失败处理会重复下载。
const String kGalleryRecordFailed = 'gallery_record_failed';

class ImageDownloader {
  ImageDownloader._();

  /// 相册写入权限的进程内缓存。
  ///
  /// gal 在 SDK ≤ 28（Android 8/9，本项目 minSdk=26）上要求**运行时已授予**的
  /// `WRITE_EXTERNAL_STORAGE`（GalPlugin.hasAccess()），而 putImage/putVideo
  /// 不会自动发起请求；不主动申请的话这几个版本上每次下载都 ACCESS_DENIED，
  /// 用户连授权弹窗都看不到。Android 10 的 legacy 存储同理。
  ///
  /// 只问一次，结果缓存到进程结束——避免每张图都触发一次系统权限检查。
  static bool? _galAccessGranted;

  static Future<bool> _ensureGalleryAccess() async {
    // 只缓存**已授权**：把「拒绝」也缓存下来的话，用户去系统设置里授权后
    // 回到应用仍然被判无权限，整个会话的下载都不可用（只有杀进程才恢复）。
    if (_galAccessGranted ?? false) return true;
    try {
      final ok = await Gal.hasAccess() || await Gal.requestAccess();
      if (ok) _galAccessGranted = true;
      return ok;
    } catch (_) {
      // 平台异常按「无权限」处理：走可读错误路径，而不是掉进通用 catch
      // 变成一句平台异常原文。不缓存，留一次重试机会。
      return false;
    }
  }

  /// 该帖此前是否已经保存过（按 serverId + postId 精确定位）。
  ///
  /// 重复下载会在 MediaStore 里留下重复条目，而文件名相同还会互相覆盖，
  /// 所以这里直接跳过——由 UI 明确告诉用户「已保存过」，而不是点了没反应。
  static bool _alreadySaved(String postId, String? serverId) {
    try {
      return UserDownloadsRepo().getAll().any(
          (d) => d.postId == postId && d.serverId == (serverId ?? ''));
    } catch (_) {
      // 记录读不出来（box 未就绪）不该挡住下载本身
      return false;
    }
  }

  /// 断点续传的临时文件后缀（OPT §3.1）。
  ///
  /// 下载一律先写 `<最终路径>.part`，**完整拿到之后**才改名成最终路径：
  /// 半截文件既不能进相册、也不该被下载记录引用，所以它只能以 .part 的形态
  /// 存在，下次启动拿它的长度当续传起点。
  static const String partialSuffix = '.part';

  /// 半截文件的**保鲜期**：超过它就不再续传。
  ///
  /// 两个理由：
  /// 1. 正确性——隔了很久之后远端内容很可能已经变了（图被替换/删除），拿一周前
  ///    的半截去拼，拼出来的东西谁也不知道是什么；
  /// 2. 卫生——取消后再没回来下的 `.part` 会永远躺在下载目录里（它不被任何下载
  ///    记录引用，「清除记录并删文件」也清不掉它）。
  static const Duration kPartialMaxAge = Duration(days: 7);

  /// 上次留下的半截文件有多大（没有 / 读不到 / 太旧都是 0）。
  ///
  /// 太旧时顺手删掉：反正不会再拿它续传，留着只是占地方。
  static int _partialSize(String partialPath) {
    try {
      final file = File(partialPath);
      if (!file.existsSync()) return 0;
      final age = DateTime.now().difference(file.statSync().modified);
      if (age > kPartialMaxAge) {
        _deleteQuietly(partialPath);
        return 0;
      }
      return file.lengthSync();
    } catch (_) {
      return 0;
    }
  }

  /// 把 `.part` 提升为最终文件。
  ///
  /// 先删目标再改名：Windows 上 `rename` 到**已存在**的文件会失败，而重试
  /// 路径完全可能出现「目标已存在」（上一次尝试已经写完了最终文件）。
  static Future<void> _promote(String partialPath, String path) async {
    final target = File(path);
    try {
      if (target.existsSync()) await target.delete();
    } catch (_) {}
    await File(partialPath).rename(path);
  }

  static void _deleteQuietly(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  /// 无进度超时（挂起看门狗）的默认时长。
  ///
  /// `createDownload` 刻意不设 `receiveTimeout`：大图在服务端偶尔停顿几十秒是
  /// 常态，硬性 receiveTimeout 会把正常下载判死。但**完全**没有进度就是另一回事
  /// ——连接建好后服务端一个字节都不发，进度条会永远停在那里，既不前进也不报错
  /// （用户只能杀进程）。所以改用「两次进度之间超过这个时长即中止」。
  static const Duration kStallTimeout = Duration(seconds: 60);

  /// 下载失败重试：只重「连接类」错误，退避口径与 API 侧共用
  /// [DioFactory.retryDelayFor]（1s / 2s / 4s）。
  ///
  /// 不用拦截器做这件事：dio 的 `download()` 在拦截器之外把响应流写进文件，
  /// 拦截器里 `fetch()` 重发拿到的响应没人落盘，会写出空文件。
  /// 用户主动取消不算失败——取消后重试等于「取消不掉」。
  ///
  /// [stallTimeout] 只为测试缩短用，生产走 [kStallTimeout]。
  static Future<void> _downloadWithRetry(
    Dio client,
    String url,
    String path, {
    CancelToken? cancelToken,
    OnProgress? onProgress,
    /// 因限流而等待时回调（OPT §3.8 的可见性）：界面据此告诉用户
    /// 「服务器限流，N 秒后自动重试」，而不是让进度条一动不动地干等。
    void Function(Duration retryIn)? onRetryWait,
    Duration stallTimeout = kStallTimeout,
  }) async {
    const maxAttempts = 3;
    final partialPath = '$path$partialSuffix';
    for (var attempt = 0;; attempt++) {
      // 每次尝试都用**新的**内部 token：它既转发调用方的取消，也承载挂起
      // 看门狗的中止。复用同一个的话第一次挂起后再重试会立刻失败。
      final internal = CancelToken();
      if (cancelToken != null) {
        if (cancelToken.isCancelled) {
          internal.cancel(cancelToken.cancelError?.message);
        } else {
          unawaited(cancelToken.whenCancel.then((e) => internal.cancel(e.message)));
        }
      }

      var stalled = false;
      // 没进展就中止：判活的唯一依据是「流里有没有送来字节」。
      final watchdog = StallWatchdog(
        timeout: stallTimeout,
        onStall: () {
          stalled = true;
          internal.cancel(kDownloadStalled);
        },
      );

      try {
        watchdog.start();
        // 不用 client.download()：它把「取响应」与「写文件」一起包了，
        // 中间没有可插入进度观测的钩子。这里自己拿流、自己落盘。
        // 续传起点：上次留下的 .part 有多长，就从哪继续
        var start = _partialSize(partialPath);
        final response = await client.get<ResponseBody>(
          url,
          options: Options(
            responseType: ResponseType.stream,
            headers: {if (start > 0) 'Range': 'bytes=$start-'},
          ),
          cancelToken: internal,
        );
        // 服务器不认 Range 时会回 200 + **整份**内容：这时必须从头写，
        // 否则会把新的一份拼在旧的半截后面，得到一个损坏的文件。
        final resuming = start > 0 && response.statusCode == 206;
        if (!resuming) start = 0;

        final sink = File(partialPath)
            .openWrite(mode: resuming ? FileMode.append : FileMode.write);
        final contentLength = int.tryParse(
                response.headers.value(Headers.contentLengthHeader) ?? '') ??
            -1;
        // 续传时 Content-Length 只是**剩余**部分的长度，进度分母要加上起点
        final total = contentLength > 0 ? contentLength + start : -1;
        try {
          var receivedBytes = start;
          await for (final chunk in response.data!.stream) {
            receivedBytes += chunk.length;
            watchdog.noteProgress();
            sink.add(chunk);
            if (total > 0 && onProgress != null) {
              onProgress(receivedBytes / total);
            }
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
        // 完整拿到才改名：半截文件不能进相册、也不该被下载记录引用
        await _promote(partialPath, path);
        return;
      } on DioException catch (e) {
        // 416：`.part` 与服务端给的内容对不上（内容换了 / 比整份还长）。
        // 丢掉半截文件重来一次，而不是把错误抛给用户。
        if (e.response?.statusCode == 416) {
          _deleteQuietly(partialPath);
          if (attempt + 1 < maxAttempts) {
            await Future<void>.delayed(DioFactory.retryDelayFor(attempt));
            continue;
          }
          rethrow;
        }
        // 用户主动取消：不重试（也**不删** .part：下次可以接着下）。
        // 看门狗中止（stalled）属于连接类问题，要重试。
        if (cancelToken?.isCancelled ?? false) rethrow;
        // 429：服务端明确说「稍后再来」。下载侧此前**完全不重试**它，于是
        // 大站限流时用户直接看到失败——而服务端明明给了等待时间（OPT §3.8）。
        final rateLimited = e.response?.statusCode == 429;
        final retryable = stalled ||
            rateLimited ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.receiveTimeout;
        if (!retryable || attempt + 1 >= maxAttempts) {
          // 永久失败（404/403 等）：半截文件是垃圾，删掉，免得下次启动
          // 还拿它当续传起点、反复失败。
          final status = e.response?.statusCode;
          if (status != null && status >= 400 && status != 416) {
            _deleteQuietly(partialPath);
          }
          if (stalled) throw const DownloadStalledException();
          rethrow;
        }
        // 429 用服务端给的等待时间（同 API 侧口径），其余走指数退避。
        final delay = DioFactory.retryAfterOf(e.response) ??
            DioFactory.retryDelayFor(attempt);
        // 只有限流才值得打扰用户：连接类错误的退避很短（1/2/4s），
        // 弹一句反而像出错了。
        if (rateLimited) onRetryWait?.call(delay);
        // 这段等待**必须可打断**：服务端可能给到 60s，而用户在这段时间里
        // 点「取消」时，如果只是干等，界面会有最长一分钟看起来「取消没反应」。
        // 看门狗中止同理（internal 被 cancel）——它意味着这次尝试已经没意义了。
        await Future.any<void>([
          Future<void>.delayed(delay),
          if (cancelToken != null) cancelToken.whenCancel,
          internal.whenCancel,
        ]);
        // 被打断就立刻回到循环开头：那里会把取消转发到新的内部 token 上，
        // 于是这次「重试」会以取消/挂起立刻失败，而不会真的再发一次请求。
        if (cancelToken?.isCancelled ?? false) rethrow;
      } finally {
        watchdog.stop();
      }
    }
  }

  /// 下载单张媒体并存进系统相册，同时写一条下载记录。
  ///
  /// [dio] 用于批量下载复用同一个连接池：此前每张图都 `createDownload()`
  /// 新建一个 HttpClient，N 张图建 N 个连接池，同域 keep-alive 全部作废。
  /// 自己创建时自己负责 `close`。
  static Future<DownloadResult> downloadImage(
    String url, {
    String? postId,
    String? namespace,
    int? width,
    int? height,
    OnProgress? onProgress,
    String downloadPath = '',
    String downloadSubdir = '',
    Dio? dio,
    CancelToken? cancelToken,
    /// 因限流而等待时回调（OPT §3.8 的可见性），见 [_downloadWithRetry]。
    void Function(Duration retryIn)? onRetryWait,
    Duration stallTimeout = kStallTimeout,
  }) async {
    try {
      // 「已保存过」先于权限检查：重复点一张早已存过的图，不该再弹一次
      // 系统权限申请，也不该因为用户此刻没授权而报失败。
      if (postId != null && _alreadySaved(postId, namespace)) {
        return const DownloadResult(success: true, alreadySaved: true);
      }

      // 权限先于网络：没权限就没必要把整张图拉下来再失败。
      // _ensureGalleryAccess 内部有进程级缓存，批量下载不会反复弹窗。
      if (!await _ensureGalleryAccess()) {
        return const DownloadResult(
          success: false,
          error: kGalleryPermissionDenied,
        );
      }

      // 扩展名口径只有一处：这里与文件名生成用同一个函数，避免
      // 「守卫放行 → 文件名无扩展名 → Gal 抛异常 → 报失败但文件已落盘」。
      final extension = extensionOf(url);
      if (extension.isEmpty) {
        return const DownloadResult(
          success: false,
          error: 'No file extension in url',
        );
      }

      // 流清单（m3u8/mpd）不是文件：下载下来只有几十字节的文本，
      // 存进相册也没法播。明确拒绝并给出可读原因，而不是写一个假文件。
      // 播放不受影响——播放器原生支持 HLS。
      if (isStreamManifest(url)) {
        return const DownloadResult(
          success: false,
          error: 'stream manifest is not downloadable',
        );
      }

      final dir =
          await resolveDownloadDir(downloadPath, subdir: downloadSubdir);
      final fileName =
          uniqueFileName(url, postId: postId, namespace: namespace);
      // 文件名生成器对「纯点 / 空主体」的地址会返回空串明确拒绝，
      // 这里必须跟着拒绝，否则会去写一个目录路径。
      if (fileName.isEmpty) {
        return const DownloadResult(
          success: false,
          error: 'No usable file name in url',
        );
      }
      final path = '${dir.path}/$fileName';

      final client = dio ?? DioFactory.createDownload();
      try {
        await _downloadWithRetry(
          client,
          url,
          path,
          cancelToken: cancelToken,
          onProgress: onProgress,
          onRetryWait: onRetryWait,
          stallTimeout: stallTimeout,
        );
      } finally {
        if (dio == null) client.close(force: true);
      }

      // 按媒体类型分派：mp4/webm 必须走视频集合，否则相册里会出现一条
      // 无法播放的"图片"，或被 MediaStore 直接拒绝而报下载失败。
      if (isVideoFile(url)) {
        await Gal.putVideo(path);
      } else {
        await Gal.putImage(path);
      }

      if (postId != null) {
        try {
          final repo = UserDownloadsRepo();
          await repo.add(DownloadEntry(
            postId: postId,
            imageUrl: url,
            localPath: path,
            downloadedAt: DateTime.now(),
            width: width,
            height: height,
            // namespace 就是 serverId：写进记录，删除时才能按站点精确定位。
            serverId: namespace ?? '',
          ));
        } catch (_) {
          // 文件已经在相册里了，只是记录没写成功（磁盘满 / box 被隔离）。
          // 报「下载失败」会让用户以为图没存上、反复重下。
          return const DownloadResult(
            success: true,
            warning: kGalleryRecordFailed,
          );
        }
      }

      return const DownloadResult(success: true);
    } on DownloadStalledException {
      // 挂起超时：给哨兵值让 UI 换成可读文案，而不是把异常原文丢出去
      return const DownloadResult(success: false, error: kDownloadStalled);
    } catch (e) {
      return DownloadResult(success: false, error: e.toString());
    }
  }
}

class DownloadResult {
  const DownloadResult({
    required this.success,
    this.error,
    this.warning,
    this.alreadySaved = false,
  });

  final bool success;
  final String? error;

  /// 成功但有话要说（例如已进相册、写记录失败）。UI 应把它显示出来，
  /// 而不是只说一句「已保存」。
  final String? warning;

  /// 这次没有真下载：该帖此前已保存过。
  final bool alreadySaved;
}
