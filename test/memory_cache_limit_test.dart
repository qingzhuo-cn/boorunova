import 'package:boorunova/foundation/util/image_cache_manager.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// 内存图片缓存上限（OPT §2.1）。
///
/// Flutter 默认 1000 张 / 100MB。大瀑布流一屏 20–40 张，长会话下这个上限
/// 会让内存涨得很高；收紧之后既覆盖回滚几屏，又让峰值可预测。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('收紧到比 Flutter 默认更严（否则等于没设、甚至是放宽）', () {
    // 直接读框架默认值比对：写死数字的话，将来 Flutter 改了默认值，
    // 这条用例会继续通过而我们的「收紧」可能早已名不副实。
    final defaults = ImageCache();
    expect(
      ImageCacheManager.memoryCacheMaxImages,
      lessThanOrEqualTo(defaults.maximumSize),
      reason: '张数上限必须不比默认宽',
    );
    expect(
      ImageCacheManager.memoryCacheMaxBytes,
      lessThanOrEqualTo(defaults.maximumSizeBytes),
      reason: '字节上限必须不比默认宽',
    );
  });

  test('configureMemoryCache 真的应用到框架缓存上', () {
    final cache = PaintingBinding.instance.imageCache;
    final originalImages = cache.maximumSize;
    final originalBytes = cache.maximumSizeBytes;
    addTearDown(() {
      cache.maximumSize = originalImages;
      cache.maximumSizeBytes = originalBytes;
    });

    ImageCacheManager.configureMemoryCache();
    expect(cache.maximumSize, ImageCacheManager.memoryCacheMaxImages);
    expect(cache.maximumSizeBytes, ImageCacheManager.memoryCacheMaxBytes);
  });

  test('可以按参数覆盖（便于以后做设置项）', () {
    final cache = PaintingBinding.instance.imageCache;
    final originalImages = cache.maximumSize;
    final originalBytes = cache.maximumSizeBytes;
    addTearDown(() {
      cache.maximumSize = originalImages;
      cache.maximumSizeBytes = originalBytes;
    });

    ImageCacheManager.configureMemoryCache(maxImages: 32, maxBytes: 8 << 20);
    expect(cache.maximumSize, 32);
    expect(cache.maximumSizeBytes, 8 << 20);
  });
}
