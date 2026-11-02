import 'dart:async';
import 'dart:typed_data';

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/kvs/kvs_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// KVS（视频站）翻页终止判定的回归。
///
/// 审查点名的两件事：
/// 1. `hasMore` **不能**用 `posts.length >= query.limit`——站点每页固定约 24 条
///    而应用页大小是 40，于是 `24 >= 40` 恒 false，滚动再也不加载；
/// 2. 结束必须靠「服务端把超页请求夹回同一页」与空页来判定，否则 hasMore
///    永远为真、无限滚动反复请求同一地址。
class _HtmlAdapter implements HttpClientAdapter {
  _HtmlAdapter(this.pages);

  /// 依次返回的页面；用尽后一直返回最后一页（模拟服务端夹持）。
  final List<String> pages;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final index = calls < pages.length ? calls : pages.length - 1;
    calls++;
    return ResponseBody.fromString(pages[index], 200, headers: {
      Headers.contentTypeHeader: [Headers.textPlainContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// 一页 HTML：卡片锚点 + data-original 缩略图。
String _page(List<String> ids) => ids
    .map((id) => '''
<div class="thumb video_1">
  <a href="/video/$id/clip-$id/" title="Clip $id">
    <img class="thumb lazy-load" src="data:image/gif;base64,R0lGODlh"
         data-original="/contents/$id/320x180/1.jpg" alt="Clip $id">
  </a>
  <div class="duration">01:00</div>
</div>''')
    .join('\n');

KvsRepository _repo(_HtmlAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://kvs.test'));
  dio.httpClientAdapter = adapter;
  return KvsRepository(dio: dio, serverId: 'kvs');
}

void main() {
  group('kvsHasMore 的口径', () {
    test('拿到了内容且路径支持翻页 → 继续', () {
      expect(KvsRepository.kvsHasMore(returned: 24, paginated: true), isTrue,
          reason: '每页 24 条 < 应用页大小 40，不能用 length >= limit 判定');
    });

    test('空页 → 结束', () {
      expect(KvsRepository.kvsHasMore(returned: 0, paginated: true), isFalse);
    });

    test('路径本身不支持翻页（搜索第一页）→ 结束', () {
      expect(
        KvsRepository.kvsHasMore(returned: 24, paginated: false),
        isFalse,
        reason: '搜索只给一页，宁可只给一页也不要无限请求同一地址');
    });
  });

  group('服务端夹持时终止翻页', () {
    test('第二页首条 id 与第一页相同 → 判为结束，且不再请求第三页', () async {
      final adapter = _HtmlAdapter([
        _page(['111', '222']),
        _page(['111', '222']), // 服务端把 page=2 夹回第 1 页
      ]);
      final repo = _repo(adapter);

      final first = await repo.searchPosts(const BooruQuery(tags: '', limit: 40));
      expect(first.posts, hasLength(2));
      expect(first.hasMore, isTrue, reason: '第一页有内容 → 继续');

      final second =
          await repo.searchPosts(const BooruQuery(tags: '', page: 2, limit: 40));
      expect(second.posts, isEmpty, reason: '夹持页不返回内容');
      expect(second.hasMore, isFalse, reason: '夹持判定为结束');
      expect(adapter.calls, 2);
    });

    test('第二页首条 id 不同 → 正常继续', () async {
      final adapter = _HtmlAdapter([
        _page(['111', '222']),
        _page(['333', '444']),
      ]);
      final repo = _repo(adapter);

      await repo.searchPosts(const BooruQuery(tags: '', limit: 40));
      final second =
          await repo.searchPosts(const BooruQuery(tags: '', page: 2, limit: 40));

      expect(second.posts.map((p) => p.id), ['333', '444']);
      expect(second.hasMore, isTrue);
    });

    test('空页 → 结束（不再有下一页）', () async {
      final adapter = _HtmlAdapter([_page(['111']), '']);
      final repo = _repo(adapter);

      await repo.searchPosts(const BooruQuery(tags: '', limit: 40));
      final second =
          await repo.searchPosts(const BooruQuery(tags: '', page: 2, limit: 40));

      expect(second.posts, isEmpty);
      expect(second.hasMore, isFalse);
    });
  });

  group('不同查询的夹持状态互不串（键是查询签名）', () {
    test('另一个标签的首页不受前一个查询的首条 id 影响', () async {
      final adapter = _HtmlAdapter([_page(['111'])]);
      final repo = _repo(adapter);

      final home = await repo.searchPosts(const BooruQuery(tags: '', limit: 40));
      expect(home.hasMore, isTrue);

      // 带标签的查询走另一条路径（搜索只给一页）
      final search =
          await repo.searchPosts(const BooruQuery(tags: 'cat', limit: 40));
      expect(search.hasMore, isFalse, reason: '搜索路径不支持翻页');
    });
  });
}
