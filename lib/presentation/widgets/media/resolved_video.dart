// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/widgets/media/video_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 视频帖的播放入口：先看帖子自带的 URL，拿不到就**按需向站点解析**。
///
/// 为什么需要这一层：视频站（KVS 家族的 rule34video 等）的列表页只有缩略图，
/// 真正的 mp4/HLS 地址藏在详情页的播放器配置里。若直接在列表条目上用
/// `mediaUrlOf(post)`，拿到的是缩略图 URL——播放器会去「播一张 jpg」。
///
/// 图片站不受影响：它们的 originalUrl 本身就是 mp4/webm，第一层判定即命中，
/// 不会多发任何请求（`resolveMediaUrl` 默认返回 null，也不会被调用）。
class ResolvedVideo extends ConsumerStatefulWidget {
  const ResolvedVideo({super.key, required this.post});

  final PostSummary post;

  @override
  ConsumerState<ResolvedVideo> createState() => _ResolvedVideoState();
}

/// 一次成功解析的结果：播放地址 + 该站点需要的防盗链请求头。
///
/// 头也一起缓存：命中缓存时当前页仓库可能已经切到别的站点（从历史/下载
/// 重新打开旧帖），此时拿不到正确的 Referer 与 UA，播放会 403。
class _ResolvedMedia {
  const _ResolvedMedia(this.url, this.headers, this.at);

  final String url;
  final Map<String, String> headers;
  final DateTime at;
}

class _ResolvedVideoState extends ConsumerState<ResolvedVideo> {
  /// 解析结果缓存：key 是 `postKeyOf(post)`（serverId/postId）。
  ///
  /// 修复前每次进入查看器都会重抓一遍详情页：同一个视频来回看几次就发几次
  /// 网络请求，站点慢时每次都要重新等。缓存按帖子身份隔离，不同站点/帖子
  /// 不会串。
  ///
  /// 带 TTL 的原因：部分视频站（KVS）的媒体地址带一次性 token，永久缓存
  /// 会在 token 过期后一直播不了；10 分钟后自动失效重抓。容量上限 32 条，
  /// 防止长会话里无界增长。
  static final Map<String, _ResolvedMedia> _cache = <String, _ResolvedMedia>{};
  static const Duration _cacheTtl = Duration(minutes: 10);
  static const int _cacheLimit = 32;

  String? _resolved;
  bool _loading = false;

  /// 面向用户的错误文案（已本地化）。修复前这里存 Object，界面用
  /// `'$error'` 直出，'no playback source' / 'playback url not found'
  /// 这类英文串对中文用户完全不可读。
  String? _error;

  /// 播放时附带的请求头（防盗链的站点需要站点的 UA 与 Referer）。
  Map<String, String> _headers = const {};

  /// 解析请求序号：post 变化或重试时自增，迟到的旧请求直接丢弃，
  /// 避免旧帖的解析结果盖到新帖上（M17 后半段）。
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant ResolvedVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    // post 变了必须重来：查看器的 PageView 会复用同一个元素位置，缺这个
    // 判断时切到下一个帖子仍显示上一个帖子的视频（M17）。
    if (!_samePost(oldWidget.post, widget.post)) _start();
  }

  /// 帖子身份 + 所有影响解析的字段。URL 变了（同一帖子的地址被修正）
  /// 也要重解析，不能只比 id。
  bool _samePost(PostSummary a, PostSummary b) =>
      postKeyOf(a) == postKeyOf(b) &&
      permalinkOf(a) == permalinkOf(b) &&
      mediaUrlOf(a) == mediaUrlOf(b) &&
      a.serverId == b.serverId;

  /// 统一入口：initState 与 didUpdateWidget 都走这里。
  ///
  /// 这里直接改字段而不 setState 是安全的：两个调用点之后都必然紧跟一次
  /// build（didUpdateWidget 之后框架一定会重建）。
  void _start() {
    // 让在途的旧请求作废
    _requestSeq++;
    final inline = mediaUrlOf(widget.post);
    if (isVideoUrl(inline)) {
      // 帖子里直接带视频地址：不需要解析，也不占缓存
      _resolved = inline;
      _loading = false;
      _error = null;
      return;
    }
    _resolved = null;
    _loading = false;
    _error = null;
    _resolve();
  }

  _ResolvedMedia? _readCache(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > _cacheTtl) {
      _cache.remove(key);
      return null;
    }
    return entry;
  }

  void _writeCache(String key, _ResolvedMedia entry) {
    if (_cache.length >= _cacheLimit) _cache.clear();
    _cache[key] = entry;
  }

  Future<void> _resolve({bool force = false}) async {
    final key = postKeyOf(widget.post);
    // 缓存命中：不再抓详情页。重试按钮传 force，绕过缓存强制刷新。
    if (!force) {
      final cached = _readCache(key);
      if (cached != null) {
        setState(() {
          _resolved = cached.url;
          _loading = false;
          _error = null;
          _headers = cached.headers;
        });
        return;
      }
    }

    final repo = ref.read(booruPageStateProvider.notifier).repository;
    final pageUrl = permalinkOf(widget.post);
    // 必须确认仓库属于这个帖子的站点：切换站点后从历史/下载重开旧帖时，
    // 当前页仓库可能是另一个站点的，拿它去抓详情页只会得到 404 或垃圾。
    final mismatch = repo == null ||
        pageUrl.isEmpty ||
        (widget.post.serverId.isNotEmpty && repo.serverId != widget.post.serverId);
    if (mismatch) {
      setState(() {
        _loading = false;
        _error = T.videoNoSource;
      });
      return;
    }
    // 视频站的媒体地址多数带防盗链：把站点自己的 UA 与「详情页」作为
    // Referer 交给播放器，否则会拿到 403 或 HTML 错误页（表现为播不了）。
    final headers = <String, String>{
      ...repo.mediaHeaders,
      'Referer': pageUrl,
    };
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
      _headers = headers;
    });
    try {
      final url = await repo.resolveMediaUrl(pageUrl);
      if (!mounted || seq != _requestSeq) return;
      if (url == null || url.isEmpty) {
        setState(() {
          _loading = false;
          _error = T.videoSourceNotFound;
        });
        return;
      }
      _writeCache(key, _ResolvedMedia(url, headers, DateTime.now()));
      setState(() {
        _loading = false;
        _resolved = url;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        // 底层异常统一走全应用映射，不再 '${e}' 直出英文栈
        _error = T.friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined,
                  size: 44, color: Colors.white54),
              const SizedBox(height: 12),
              Text(
                T.videoPlayFailed,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                error,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                // 重试绕过缓存：上次解析到的地址可能已经失效（token 过期）
                onPressed: () => _resolve(force: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(T.retry),
              ),
            ],
          ),
        ),
      );
    }

    final url = _resolved;
    if (_loading || url == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return VideoViewer(
      url: url,
      headers: _headers.isEmpty ? null : _headers,
    );
  }
}
