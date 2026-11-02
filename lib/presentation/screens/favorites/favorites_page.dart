// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:boorunova/data/repository/favorites/user_favorite_repo.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/foundation/util/image_downloader.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/widgets/common/download_feedback.dart';
import 'package:boorunova/presentation/widgets/common/rating_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(userFavoritesRepoProvider);
    final favorites = repo.getAll();

    return Scaffold(
      appBar: AppBar(title: Text(T.favorites)),
      body: favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    T.noFavoritesYet,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    T.tapHeartToSave,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.3),
                        ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 1,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final post = favorites[index];
                // 瓦片此前没有任何语义标签：读屏只会念出一个「图片」，
                // 也说不出它可以点开。包一层 Semantics 补上动作与按钮角色。
                return Semantics(
                  button: true,
                  label: T.tapToView,
                  child: GestureDetector(
                    onTap: () => _showDetail(context, ref, post, index,
                        favorites.map(_toSummary).toList(growable: false)),
                    child: Image.network(
                      post.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showDetail(
    BuildContext context,
    WidgetRef ref,
    BooruPost post,
    int index,
    List<PostSummary> gallery,
  ) {
    final repo = ref.read(userFavoritesRepoProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _FavoriteDetailSheet(
        post: post,
        repo: repo,
        gallery: gallery,
        initialIndex: index,
      ),
    );
  }
}

/// 收藏仓库持久化的是 [BooruPost]，查看器要的是 [PostSummary]。
///
/// 字段级转换此前无处可去——收藏页没有查看器入口，这份映射一直不存在。
/// 收藏与历史一样，已经存下了查看所需的全部字段，不需要回站点重拉。
PostSummary _toSummary(BooruPost post) => PostSummary(
      id: post.id,
      serverId: post.serverId,
      thumbnailUrl: post.thumbnailUrl,
      sampleUrl: post.sampleUrl,
      originalUrl: post.originalUrl,
      tags: post.tags,
      tagGeneral: post.tagGeneral,
      tagArtist: post.tagArtist,
      tagCharacter: post.tagCharacter,
      tagCopyright: post.tagCopyright,
      tagMeta: post.tagMeta,
      aspectRatio: post.aspectRatio,
      width: post.width,
      height: post.height,
      rating: post.rating,
      score: post.score,
      source: post.source,
      postUrl: post.postUrl,
      isVideo: post.isVideo,
    );

class _FavoriteDetailSheet extends ConsumerWidget {
  const _FavoriteDetailSheet({
    required this.post,
    required this.repo,
    required this.gallery,
    required this.initialIndex,
  });

  final BooruPost post;
  final UserFavoritesRepo repo;

  /// 当前收藏的完整列表与这条记录的下标。
  ///
  /// 弹层的「查看大图」要带着它们进查看器；此前收藏只有这个弹层，
  /// 既没有查看器入口，进了也只能看到单帖。
  final List<PostSummary> gallery;
  final int initialIndex;

  /// 打开全屏查看器，沿用整份收藏作为画廊，保留当前所在位置。
  void _openViewer(BuildContext context) {
    // 先取 GoRouter 再关弹层：pop 之后这个 context 已失效，
    // 不能再用 context.push。
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    final posts =
        gallery.isEmpty ? <PostSummary>[_toSummary(post)] : gallery;
    router.push('/post/${post.id}', extra: <String, dynamic>{
      'posts': posts,
      'initialIndex': gallery.isEmpty ? 0 : initialIndex,
    });
  }

  /// 从收藏弹层直接下载。与查看器里的单图下载保持同一套四态提示，
  /// 避免「已保存过 / 相册记录失败 / 无权限 / 失败」在收藏入口被压成一句。
  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final settings = ref.read(settingsProvider);
    final prefs = ref.read(userServerRepoProvider).preferencesOf(post.serverId);
    final url = await resolveDownloadUrl(
      _toSummary(post),
      ref.read(booruPageStateProvider.notifier).repository,
      preferSample: downloadQualityFor(settings, prefs) == 'sample',
    );
    if (url.isEmpty) return;
    final result = await ImageDownloader.downloadImage(
      url,
      postId: post.id,
      namespace: post.serverId,
      width: post.width,
      height: post.height,
      downloadPath: settings.downloadPath,
      downloadSubdir: prefs.downloadSubdir,
    );
    messenger.showSnackBar(
      SnackBar(content: Text(downloadResultMessage(result))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = repo.isFavorite(post.id, serverId: post.serverId);
    // 大图预览也要守「预览画质」：这里此前自己写了 sample 优先，于是站点/
    // 全局设成「预览用原图」时，收藏弹层成了唯一不生效的地方。
    final previewPrefs =
        ref.watch(userServerRepoProvider).preferencesOf(post.serverId);
    final previewUrl = previewUrlOf(
      _toSummary(post),
      preferOriginal: previewQualityFor(
            ref.watch(settingsProvider),
            previewPrefs,
          ) ==
          'original',
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: post.aspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                previewUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('${T.rating}: ${post.rating.toUpperCase()}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: ratingColor(post.rating))),
              const SizedBox(width: 16),
              Text('${T.score}: ${post.score}',
                  style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.red : null,
                ),
                tooltip: T.favorites,
                onPressed: () async {
                  await repo.toggle(post);
                  // await 后弹层可能已经被关掉。修复前先 invalidate 再看
                  // context.mounted：弹层已 dispose 时用 ref 会抛异常。
                  if (!context.mounted) return;
                  ref.invalidate(userFavoritesRepoProvider);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  // 修复前收藏只有这个弹层：看完小图只能关掉，没有进入
                  // 全屏查看器的入口。现在带着整份收藏进查看器，可直接翻页。
                  onPressed: () => _openViewer(context),
                  icon: const Icon(Icons.open_in_full, size: 18),
                  label: Text(T.openFullViewer),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _download(context, ref),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(T.downloads),
                ),
              ),
            ],
          ),
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(T.tags, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: post.tags.take(20).map((tag) {
                return Chip(
                  label: Text(tag, style: const TextStyle(fontSize: 11)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
