import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:dio/dio.dart';

/// Booru 引擎仓库基类，收敛各引擎的公共样板。
///
/// 提供 [dio] / [serverId] 字段与统一构造，子类通过
/// `super(dio: dio, serverId: serverId)` 初始化。
/// 收藏相关方法默认返回「不支持」占位，支持收藏的引擎按需 override。
abstract class BaseBooruRepository implements BooruRepository {
  const BaseBooruRepository({
    required this.dio,
    required this.serverId,
  });

  /// 网络请求客户端（已由 DioFactory 配置好 baseUrl 与拦截器）。
  final Dio dio;

  /// 站点标识，用于跨站点缓存隔离。字段即满足接口 getter，子类无需再 override。
  @override
  final String serverId;

  /// 默认实现：引擎不支持图集时返回空列表。
  @override
  Future<List<BooruPool>> fetchPools({int page = 1, int limit = 20}) async => [];

  /// 拼接搜索标签：把用户输入标签与评级过滤合并为站点查询串。
  ///
  /// [ratingMap] 为引擎特定的评级映射，例如 danbooru 用 `rating:s`，
  /// 多数引擎用 `rating:safe`。不评级过滤时传 null。
  String buildTagsQuery(BooruQuery query, Map<String, String>? ratingMap) {
    return <String>[
      if (query.tags.isNotEmpty) query.tags,
      if (query.rating != null && ratingMap != null)
        ratingMap[query.rating!] ?? 'rating:${query.rating}',
    ].join(' ');
  }

  /// 多数引擎通用的评级映射：safe / questionable / explicit。
  static const Map<String, String> ratingMapLong = {
    's': 'rating:safe',
    'q': 'rating:questionable',
    'e': 'rating:explicit',
  };
}

/// 把解析层 [BooruPost] 转为 UI 层 [PostSummary]。
/// 原先 8 个引擎各有一份逐字节相同的私有扩展，现收敛为一份。
extension BooruPostToSummary on BooruPost {
  PostSummary toSummary(String serverId) => PostSummary(
        id: id,
        serverId: serverId,
        thumbnailUrl: thumbnailUrl,
        sampleUrl: sampleUrl,
        originalUrl: originalUrl,
        tags: tags,
        tagGeneral: tagGeneral,
        tagArtist: tagArtist,
        tagCharacter: tagCharacter,
        tagCopyright: tagCopyright,
        tagMeta: tagMeta,
        aspectRatio: aspectRatio,
        width: width,
        height: height,
        rating: rating,
        score: score,
        source: source,
        postUrl: postUrl,
      );
}
