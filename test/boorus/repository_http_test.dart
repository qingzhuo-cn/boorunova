import 'dart:convert';
import 'dart:io';

import 'package:boorunova/boorus/danbooru/danbooru_repository.dart';
import 'package:boorunova/boorus/e621/e621_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/gelbooru_v2/gelbooru_v2_repository.dart';
import 'package:boorunova/boorus/gelbooru_v2/parser/gelbooru_v2_parser.dart';
import 'package:boorunova/boorus/moebooru/moebooru_repository.dart';
import 'package:boorunova/boorus/rule34/rule34_repository.dart';
import 'package:boorunova/boorus/safebooru/safebooru_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 本地假站点：记录收到的每个请求 URI，并按当前 [responder] 应答。
///
/// 与 test/hosts_network_test.dart 同一模式（HttpServer.bind + 注入 dio），
/// 区别是这个测试文件里一个用例可能要处理多个请求，所以把应答交给可替换的
/// responder；请求 URI 全部留档，用来断言仓库层实际发出的查询参数。
class _FakeSite {
  _FakeSite._(this._server);

  static Future<_FakeSite> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final site = _FakeSite._(server);
    server.listen((request) {
      site.requests.add(request.uri);
      site.responder(request);
    });
    return site;
  }

  final HttpServer _server;
  final List<Uri> requests = [];
  late void Function(HttpRequest request) responder;

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Uri get lastRequest => requests.last;

  Future<void> close() => _server.close(force: true);
}

Dio _dioFor(_FakeSite site, {Map<String, dynamic>? extra}) => Dio(
      BaseOptions(baseUrl: site.baseUrl, extra: extra),
    );

void _respondJson(HttpRequest request, Object? body) {
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  request.response.close();
}

void _respondXml(HttpRequest request, String body) {
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType('text', 'xml')
    ..write(body);
  request.response.close();
}

Map<String, dynamic> _danbooruPost(int id) => {
      'id': id,
      'file_url': 'https://cdn.test/$id.jpg',
      'large_file_url': 'https://cdn.test/s$id.jpg',
      'preview_file_url': 'https://cdn.test/p$id.jpg',
      'image_width': 100,
      'image_height': 200,
      'tag_string': 'solo',
      'tag_string_general': 'solo',
      'rating': 'g',
      'score': 1,
    };

Map<String, dynamic> _e621Post(int id) => {
      'id': id,
      'file': {
        'url': 'https://static.test/$id.png',
        'width': 100,
        'height': 200,
      },
      'sample': {'url': 'https://static.test/s$id.jpg'},
      'preview': {'url': 'https://static.test/p$id.jpg'},
      'tags': {
        'general': ['solo'],
      },
      'rating': 'g',
      'score': {'total': 1},
      'sources': <String>[],
    };

Map<String, dynamic> _moebooruPost(int id) => {
      'id': id,
      'file_url': 'https://yande.re/$id.jpg',
      'sample_url': 'https://yande.re/s$id.jpg',
      'preview_url': 'https://yande.re/p$id.jpg',
      'jpeg_url': 'https://yande.re/j$id.jpg',
      'tags': 'solo',
      'width': 100,
      'height': 200,
      'rating': 'safe',
      'score': 1,
      'source': '',
      'author': 'artist',
    };

/// 一条字段完整的 gelbooru DAPI XML 帖子。
const String _validPostXml = '<post id="1" file_url="https://img.test/1.jpg" '
    'sample_url="https://img.test/1s.jpg" preview_url="https://img.test/1t.jpg" '
    'tags="solo" width="100" height="200" rating="safe" score="3" source="" />';

/// 字段不完整（file_url 为空）的帖子，解析时会被过滤掉。
const String _invalidPostXml = '<post id="2" file_url="" sample_url="" '
    'preview_url="" tags="" width="0" height="0" rating="safe" score="0" source="" />';

void main() {
  late _FakeSite site;

  setUp(() async {
    site = await _FakeSite.start();
    site.responder = (request) => _respondJson(request, const []);
  });

  tearDown(() async {
    await site.close();
  });

  group('danbooru 仓库', () {
    test('searchPosts 合并 tags 与评级：安全档映射到 rating:g', () async {
      site.responder = (request) => _respondJson(request, const []);
      final repo = DanbooruRepository(dio: _dioFor(site), serverId: 'danbooru');

      await repo.searchPosts(const BooruQuery(
        tags: 'hatsune_miku',
        page: 3,
        limit: 20,
        rating: 's',
      ));

      expect(site.lastRequest.path, '/posts.json');
      final q = site.lastRequest.queryParameters;
      // 四档世界：UI 的「安全」= general(g)；s 已经是 sensitive，
      // 发 rating:s 会拉到擦边内容或 0 结果。
      expect(q['tags'], 'hatsune_miku rating:g',
          reason: '评级必须合并进同一个 tags 参数，且 s 映射为 rating:g');
      expect(q['page'], '3', reason: 'page 应原样透传');
      expect(q['limit'], '20', reason: 'limit 应原样透传');
    });

    test('searchPosts 评级 q/e 分别映射 rating:q / rating:e', () async {
      site.responder = (request) => _respondJson(request, const []);
      final repo = DanbooruRepository(dio: _dioFor(site), serverId: 'danbooru');

      await repo.searchPosts(const BooruQuery(tags: 'solo', rating: 'q'));
      expect(site.lastRequest.queryParameters['tags'], 'solo rating:q');

      await repo.searchPosts(const BooruQuery(tags: 'solo', rating: 'e'));
      expect(site.lastRequest.queryParameters['tags'], 'solo rating:e');
    });

    test('searchPosts 不选评级时不追加 rating 词', () async {
      site.responder = (request) => _respondJson(request, const []);
      final repo = DanbooruRepository(dio: _dioFor(site), serverId: 'danbooru');

      await repo.searchPosts(const BooruQuery(tags: 'solo'));

      expect(site.lastRequest.queryParameters['tags'], 'solo',
          reason: 'rating 为 null 时不应凭空拼一个 rating 过滤');
    });

    test('hasMore：返回满页为 true，不满页为 false', () async {
      site.responder = (request) =>
          _respondJson(request, [_danbooruPost(1), _danbooruPost(2)]);
      final repo = DanbooruRepository(dio: _dioFor(site), serverId: 'danbooru');

      final full =
          await repo.searchPosts(const BooruQuery(tags: 'solo', limit: 2));
      expect(full.posts, hasLength(2));
      expect(full.hasMore, isTrue,
          reason: '本页条数 == limit，站点可能还有下一页');

      final partial =
          await repo.searchPosts(const BooruQuery(tags: 'solo', limit: 3));
      expect(partial.posts, hasLength(2));
      expect(partial.hasMore, isFalse,
          reason: '本页条数 < limit，说明已到末页');
    });

    test('suggestTags 请求 search[name_matches] 形态并回填结果', () async {
      site.responder = (request) => _respondJson(request, [
            {'name': 'hatsune_miku'},
            {'name': 'hatsune_miku_wallpaper'},
          ]);
      final repo = DanbooruRepository(dio: _dioFor(site), serverId: 'danbooru');

      final tags = await repo.suggestTags('hatsune', limit: 5);

      expect(site.lastRequest.path, '/tags.json');
      final q = site.lastRequest.queryParameters;
      expect(q['search[name_matches]'], '*hatsune*',
          reason: 'danbooru 的模糊匹配语法是 search[name_matches]=*词*');
      expect(q['search[order]'], 'count');
      expect(q['limit'], '5');
      expect(tags, ['hatsune_miku', 'hatsune_miku_wallpaper']);
    });
  });

  group('e621 仓库', () {
    test('searchPosts 解析 {"posts":[...]} 包裹形态', () async {
      site.responder = (request) =>
          _respondJson(request, {'posts': [_e621Post(11)]});
      final repo = E621Repository(dio: _dioFor(site), serverId: 'e621');

      final result =
          await repo.searchPosts(const BooruQuery(tags: 'solo', limit: 1));

      expect(site.lastRequest.path, '/posts.json');
      expect(result.posts, hasLength(1));
      expect(result.posts.single.id, '11');
      expect(result.posts.single.serverId, 'e621');
    });

    test('searchPosts 顶层不是对象（形态不符）时返回空结果而不是抛异常', () async {
      site.responder = (request) => _respondJson(request, [_e621Post(1)]);
      final repo = E621Repository(dio: _dioFor(site), serverId: 'e621');

      final result = await repo.searchPosts(const BooruQuery(tags: 'solo'));

      expect(result.posts, isEmpty,
          reason: 'e621 一律包一层对象，裸数组说明响应形态变了，应按空结果降级');
      expect(result.hasMore, isFalse);
    });

    test('searchPosts 的 {"posts": ...} 不是数组时同样降级为空', () async {
      site.responder =
          (request) => _respondJson(request, {'posts': 'not-a-list'});
      final repo = E621Repository(dio: _dioFor(site), serverId: 'e621');

      final result = await repo.searchPosts(const BooruQuery(tags: 'solo'));

      expect(result.posts, isEmpty);
      expect(result.hasMore, isFalse);
    });

    test('searchPosts 评级过滤同样走四档：s -> rating:g', () async {
      site.responder = (request) => _respondJson(request, {'posts': const []});
      final repo = E621Repository(dio: _dioFor(site), serverId: 'e621');

      await repo.searchPosts(const BooruQuery(tags: 'wolf', rating: 's'));

      expect(site.lastRequest.queryParameters['tags'], 'wolf rating:g',
          reason: 'e621 同 danbooru，rating:safe 已过时且语义错误');
    });

    test('hasMore：满页为 true，不满页为 false', () async {
      site.responder = (request) => _respondJson(request, {
            'posts': [_e621Post(1), _e621Post(2)],
          });
      final repo = E621Repository(dio: _dioFor(site), serverId: 'e621');

      final full =
          await repo.searchPosts(const BooruQuery(tags: 'solo', limit: 2));
      expect(full.hasMore, isTrue);

      final partial =
          await repo.searchPosts(const BooruQuery(tags: 'solo', limit: 5));
      expect(partial.hasMore, isFalse);
    });
  });

  group('gelbooru_v2 仓库', () {
    test('searchPosts 构造 DAPI 参数并注入 authQueryParams', () async {
      site.responder = (request) => _respondXml(
            request,
            '<posts count="5" offset="0">$_validPostXml</posts>',
          );
      final dio = _dioFor(site, extra: {
        'authApiKey': 'KEY',
        'authLogin': 'USER',
      });
      final repo = GelbooruV2Repository(dio: dio, serverId: 'gelbooru');

      await repo.searchPosts(const BooruQuery(
        tags: 'cat',
        page: 2,
        limit: 20,
        rating: 's',
      ));

      expect(site.lastRequest.path, '/index.php');
      final q = site.lastRequest.queryParameters;
      expect(q['page'], 'dapi');
      expect(q['s'], 'post');
      expect(q['q'], 'index');
      expect(q['tags'], 'cat rating:safe',
          reason: 'gelbooru DAPI 用三档长名 rating:safe');
      expect(q['pid'], '1', reason: 'pid 是 0 基页号：第 2 页 -> pid=1');
      expect(q['limit'], '20');
      expect(q['api_key'], 'KEY',
          reason: 'gelbooru 系认证走 query 参数，缺了永远 401');
      expect(q['user_id'], 'USER');
    });

    test('searchPosts 无凭据时不带 api_key/user_id', () async {
      site.responder = (request) => _respondXml(
            request,
            '<posts count="0" offset="0">$_validPostXml</posts>',
          );
      final repo =
          GelbooruV2Repository(dio: _dioFor(site), serverId: 'gelbooru');

      await repo.searchPosts(const BooruQuery(tags: 'cat'));

      final q = site.lastRequest.queryParameters;
      expect(q.containsKey('api_key'), isFalse);
      expect(q.containsKey('user_id'), isFalse);
    });

    test('hasMore 用响应 count/offset 计算：过滤掉一条也不误判末页', () async {
      // 声明总数 3、本页只解析出 1 条有效；若用「本页条数 >= limit」会把
      // 第 2 页判成末页。
      site.responder = (request) => _respondXml(
            request,
            '<posts count="3" offset="0">$_validPostXml$_invalidPostXml</posts>',
          );
      final repo =
          GelbooruV2Repository(dio: _dioFor(site), serverId: 'gelbooru');

      final result =
          await repo.searchPosts(const BooruQuery(tags: 'cat', limit: 2));

      expect(result.posts, hasLength(1), reason: '无效帖（file_url/尺寸缺失）被过滤');
      expect(result.hasMore, isTrue,
          reason: 'offset(0) + 本页条数(1) < count(3)，还有下一页');
    });

    test('hasMore 在 count/offset 缺失时退回满页口径', () async {
      site.responder = (request) =>
          _respondXml(request, '<posts>$_validPostXml</posts>');
      final repo =
          GelbooruV2Repository(dio: _dioFor(site), serverId: 'gelbooru');

      final full =
          await repo.searchPosts(const BooruQuery(tags: 'cat', limit: 1));
      expect(full.hasMore, isTrue, reason: '取不到 count 时按本页条数 >= limit 判定');

      final partial =
          await repo.searchPosts(const BooruQuery(tags: 'cat', limit: 2));
      expect(partial.hasMore, isFalse);
    });

    test('hasMore 在 count/offset 为 0 时按声明总数判定为末页', () async {
      site.responder = (request) => _respondXml(
            request,
            '<posts count="0" offset="0">$_validPostXml</posts>',
          );
      final repo =
          GelbooruV2Repository(dio: _dioFor(site), serverId: 'gelbooru');

      final result =
          await repo.searchPosts(const BooruQuery(tags: 'cat', limit: 1));

      expect(result.hasMore, isFalse,
          reason: 'count=0 说明站点认为没有更多（0+1 < 0 为假）');
    });

    test('hasMore 在 count/offset 畸形时退回满页口径', () async {
      site.responder = (request) => _respondXml(
            request,
            '<posts count="abc" offset="9x">$_validPostXml</posts>',
          );
      final repo =
          GelbooruV2Repository(dio: _dioFor(site), serverId: 'gelbooru');

      final full =
          await repo.searchPosts(const BooruQuery(tags: 'cat', limit: 1));
      expect(full.hasMore, isTrue, reason: '畸形值解析为 null -> 退回本页条数 >= limit');

      final partial =
          await repo.searchPosts(const BooruQuery(tags: 'cat', limit: 5));
      expect(partial.hasMore, isFalse);
    });

    test('limit 超过单页上限时请求被夹到 maxPageSize', () async {
      site.responder = (request) => _respondXml(
            request,
            '<posts count="0" offset="0">$_validPostXml</posts>',
          );
      final repo =
          GelbooruV2Repository(dio: _dioFor(site), serverId: 'gelbooru');

      await repo.searchPosts(const BooruQuery(tags: 'cat', limit: 500));

      expect(site.lastRequest.queryParameters['limit'], '100',
          reason: '站点超限会静默截断，请求与 hasMore 必须共用夹持后的值');
    });

    test('suggestTags 也带 authQueryParams', () async {
      site.responder = (request) => _respondXml(
            request,
            '<tags><tag name="cat" count="5" /></tags>',
          );
      final dio = _dioFor(site, extra: {
        'authApiKey': 'KEY',
        'authLogin': 'USER',
      });
      final repo = GelbooruV2Repository(dio: dio, serverId: 'gelbooru');

      await repo.suggestTags('cat');

      final q = site.lastRequest.queryParameters;
      expect(q['name_pattern'], '%cat%');
      expect(q['api_key'], 'KEY',
          reason: '需 key 的站点若 tag 接口不带凭据会静默 401、建议永远为空');
      expect(q['user_id'], 'USER');
    });
  });

  group('GelbooruV2Parser.parseCount / parseOffset 四态', () {
    test('出现：解析出声明值', () {
      const xml = '<posts count="6960037" offset="40">';
      expect(GelbooruV2Parser.parseCount(xml), 6960037);
      expect(GelbooruV2Parser.parseOffset(xml), 40);
    });

    test('缺失：返回 null，调用方可退回满页口径', () {
      expect(GelbooruV2Parser.parseCount('<posts>'), isNull);
      expect(GelbooruV2Parser.parseOffset('<posts>'), isNull);
    });

    test('为 0：解析出 0 而不是 null（0 是有效声明）', () {
      const xml = '<posts count="0" offset="0">';
      expect(GelbooruV2Parser.parseCount(xml), 0);
      expect(GelbooruV2Parser.parseOffset(xml), 0);
    });

    test('畸形：返回 null 而不是抛异常或误读成数字', () {
      const xml = '<posts count="abc" offset="9x">';
      expect(GelbooruV2Parser.parseCount(xml), isNull);
      expect(GelbooruV2Parser.parseOffset(xml), isNull);
      // 其中一个可用时只补回可用的那个
      const mixed = '<posts count="5" offset="oops">';
      expect(GelbooruV2Parser.parseCount(mixed), 5);
      expect(GelbooruV2Parser.parseOffset(mixed), isNull);
    });
  });

  group('moebooru 仓库', () {
    test('searchPosts 用 /post.json 并带 moebooru 认证参数', () async {
      site.responder = (request) =>
          _respondJson(request, [_moebooruPost(1)]);
      final dio = _dioFor(site, extra: {
        'authApiKey': 'HASH',
        'authLogin': 'USER',
      });
      final repo = MoebooruRepository(dio: dio, serverId: 'yandere');

      await repo.searchPosts(const BooruQuery(
        tags: 'cat',
        page: 2,
        limit: 20,
        rating: 'q',
      ));

      expect(site.lastRequest.path, '/post.json');
      final q = site.lastRequest.queryParameters;
      expect(q['tags'], 'cat rating:questionable');
      expect(q['page'], '2');
      expect(q['limit'], '20');
      expect(q['login'], 'USER',
          reason: 'moebooru 只认 login/password_hash，Basic 头会被忽略');
      expect(q['password_hash'], 'HASH');
    });

    test('searchPosts 无凭据时不带 login/password_hash', () async {
      site.responder = (request) =>
          _respondJson(request, [_moebooruPost(1)]);
      final repo =
          MoebooruRepository(dio: _dioFor(site), serverId: 'yandere');

      await repo.searchPosts(const BooruQuery(tags: 'cat'));

      final q = site.lastRequest.queryParameters;
      expect(q.containsKey('login'), isFalse);
      expect(q.containsKey('password_hash'), isFalse);
    });

    test('hasMore：满页为 true，不满页为 false', () async {
      site.responder = (request) => _respondJson(
            request,
            [_moebooruPost(1), _moebooruPost(2)],
          );
      final repo =
          MoebooruRepository(dio: _dioFor(site), serverId: 'yandere');

      final full =
          await repo.searchPosts(const BooruQuery(tags: 'cat', limit: 2));
      expect(full.hasMore, isTrue);

      final partial =
          await repo.searchPosts(const BooruQuery(tags: 'cat', limit: 3));
      expect(partial.hasMore, isFalse);
    });

    test('limit 超过单页上限时请求被夹到 maxPageSize', () async {
      site.responder = (request) =>
          _respondJson(request, [_moebooruPost(1)]);
      final repo =
          MoebooruRepository(dio: _dioFor(site), serverId: 'yandere');

      await repo.searchPosts(const BooruQuery(tags: 'cat', limit: 500));

      expect(site.lastRequest.queryParameters['limit'], '100');
    });
  });

  group('rule34 / safebooru 非预期响应降级', () {
    test('rule34 searchPosts 收到非数组 JSON 时返回空结果且不抛异常', () async {
      site.responder = (request) =>
          _respondJson(request, {'unexpected': true});
      final repo = Rule34Repository(dio: _dioFor(site), serverId: 'rule34');

      final result = await repo.searchPosts(const BooruQuery(tags: 'cat'));

      expect(result.posts, isEmpty);
      expect(result.hasMore, isFalse,
          reason: '形态不符时静默吞掉并置 hasMore=false，而不是把异常抛给 UI');
    });

    test('rule34 searchPosts 参数含 json=1 且注入凭据', () async {
      site.responder = (request) => _respondJson(request, const []);
      final dio = _dioFor(site, extra: {
        'authApiKey': 'KEY',
        'authLogin': 'USER',
      });
      final repo = Rule34Repository(dio: dio, serverId: 'rule34');

      await repo.searchPosts(const BooruQuery(tags: 'cat', page: 2));

      final q = site.lastRequest.queryParameters;
      expect(q['json'], '1');
      expect(q['pid'], '1');
      expect(q['api_key'], 'KEY');
      expect(q['user_id'], 'USER');
    });

    test('rule34 suggestTags 收到非数组非 XML 时返回空列表', () async {
      site.responder = (request) =>
          _respondJson(request, {'unexpected': true});
      final repo = Rule34Repository(dio: _dioFor(site), serverId: 'rule34');

      expect(await repo.suggestTags('cat'), isEmpty,
          reason: 'tag 端点形态未验证，静默吞掉非预期响应但不得抛异常');
    });

    test('safebooru searchPosts 收到非 XML（JSON 对象）时返回空结果', () async {
      site.responder = (request) => _respondJson(request, {'error': 'nope'});
      final repo =
          SafebooruRepository(dio: _dioFor(site), serverId: 'safebooru');

      final result = await repo.searchPosts(const BooruQuery(tags: 'cat'));

      expect(result.posts, isEmpty);
      expect(result.hasMore, isFalse);
    });

    test('safebooru searchPosts 收到零结果 XML 时返回空结果', () async {
      site.responder = (request) =>
          _respondXml(request, '<posts count="0" offset="0"></posts>');
      final repo =
          SafebooruRepository(dio: _dioFor(site), serverId: 'safebooru');

      final result = await repo.searchPosts(const BooruQuery(tags: 'cat'));

      expect(result.posts, isEmpty,
          reason: '零结果响应里没有 <post 标签，守卫必须放行为空而不是去解析');
      expect(result.hasMore, isFalse);
    });

    test('safebooru searchPosts 带 authQueryParams', () async {
      site.responder = (request) => _respondXml(
            request,
            '<posts count="5" offset="0">$_validPostXml</posts>',
          );
      final dio = _dioFor(site, extra: {
        'authApiKey': 'KEY',
        'authLogin': 'USER',
      });
      final repo = SafebooruRepository(dio: dio, serverId: 'safebooru');

      await repo.searchPosts(const BooruQuery(tags: 'cat', rating: 'e'));

      final q = site.lastRequest.queryParameters;
      expect(q['tags'], 'cat rating:explicit');
      expect(q['api_key'], 'KEY');
      expect(q['user_id'], 'USER');
    });

    test('safebooru suggestTags 收到非 XML 时返回空列表', () async {
      site.responder = (request) => _respondJson(request, const []);
      final repo =
          SafebooruRepository(dio: _dioFor(site), serverId: 'safebooru');

      expect(await repo.suggestTags('cat'), isEmpty);
      expect(await repo.fetchTrendingTags(), isEmpty);
    });
  });
}
