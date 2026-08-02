import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:boorunova/data/repository/favorites/user_favorite_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(userFavoritesRepoProvider);
    final favorites = repo.getAll();

    return Scaffold(
      appBar: AppBar(title: const Text(T.favorites)),
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
                return GestureDetector(
                  onTap: () => _showDetail(context, ref, post),
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
                );
              },
            ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref, BooruPost post) {
    final repo = ref.read(userFavoritesRepoProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _FavoriteDetailSheet(post: post, repo: repo),
    );
  }
}

class _FavoriteDetailSheet extends ConsumerWidget {
  const _FavoriteDetailSheet({
    required this.post,
    required this.repo,
  });

  final BooruPost post;
  final UserFavoritesRepo repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = repo.isFavorite(post.id, serverId: post.serverId);
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
                post.sampleUrl.isNotEmpty ? post.sampleUrl : post.originalUrl,
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
              Text('Rating: ${post.rating.toUpperCase()}'),
              const SizedBox(width: 16),
              Text('Score: ${post.score}'),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.red : null,
                ),
                onPressed: () async {
                  await repo.toggle(post);
                  ref.invalidate(userFavoritesRepoProvider);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Tags',
                style: TextStyle(fontWeight: FontWeight.w600)),
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
