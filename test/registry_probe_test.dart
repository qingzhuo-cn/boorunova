import 'package:boorunova/boorus/danbooru/danbooru_repository.dart';
import 'package:boorunova/boorus/e621/e621_repository.dart';
import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/registry.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';
import 'package:boorunova/boorus/gelbooru_v2/gelbooru_v2_repository.dart';
import 'package:boorunova/boorus/kvs/kvs_repository.dart';
import 'package:boorunova/boorus/moebooru/moebooru_repository.dart';
import 'package:boorunova/boorus/rule34/rule34_repository.dart';
import 'package:boorunova/boorus/safebooru/safebooru_repository.dart';
import 'package:boorunova/boorus/sankaku/sankaku_repository.dart';
import 'package:boorunova/boorus/shimmie2/shimmie2_repository.dart';
import 'package:boorunova/boorus/zerochan/zerochan_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 探测相关的纯函数单测。
///
/// 探测顺序与域名判定是「加站」这条路上的两个静默陷阱：判错了不会报错，
/// 只会让用户看到一个类型不对的站点。所以这两处必须能离线验证。
void main() {
  group('BooruRegistry.scanner 域名判定', () {
    test('精确域名与子域都命中', () {
      expect(BooruRegistry().scanner('https://danbooru.donmai.us/posts'),
          BooruType.danbooru);
      expect(BooruRegistry().scanner('danbooru.donmai.us'), BooruType.danbooru,
          reason: '用户手填 URL 常常不带 scheme');
      expect(BooruRegistry().scanner('https://beta.paheal.net'),
          BooruType.shimmie2);
      expect(BooruRegistry().scanner('https://yande.re'), BooruType.moebooru);
      expect(BooruRegistry().scanner('https://danbooru.donmai.us:8443'),
          BooruType.danbooru,
          reason: '端口不该影响域名判定');
      // 域名捷径表是**渠道数据**：Play 版为空（全部 URL 走协议探测，
      // 由 site_presets_test 的 Play 组钉住），所以这条只在默认构建下成立。
    }, skip: kPlayBuild ? 'Play 版域名捷径为空表（见 site_presets_test）' : false);

    test('伪造后缀域名不算命中（zerochan.net.evil.com 反例）', () {
      expect(BooruRegistry().scanner('https://zerochan.net.evil.com'), isNull);
      expect(BooruRegistry().scanner('https://e621.net.attacker.tld'), isNull);
    });

    test('域名只出现在路径里不算命中', () {
      expect(BooruRegistry().scanner('https://evil.com/zerochan.net'), isNull);
    });

    test('空输入返回 null', () {
      expect(BooruRegistry().scanner(''), isNull);
      expect(BooruRegistry().scanner('   '), isNull);
    });
  });

  group('BooruRegistry.matchesProbeResponse', () {
    test('非 200 一律不命中', () {
      const danbooruBody = '[{"tag_string":"a","preview_file_url":"x"}]';
      expect(
        BooruRegistry.matchesProbeResponse(403, danbooruBody, BooruType.danbooru),
        isFalse,
      );
      expect(
        BooruRegistry.matchesProbeResponse(200, danbooruBody, BooruType.danbooru),
        isTrue,
      );
    });

    test('特征过弱的反面：陌生 JSON API 不会被认成 danbooru', () {
      // 修好 JSON 解析（取原始字符串）之后，弱特征会真的误认站点：
      // 任何 /posts.json 返回 {"id":...} 的 API 都曾被当作 danbooru。
      // 现在要求 tag_string **且** preview_file_url 同时出现。
      expect(
        BooruRegistry.matchesProbeResponse(
            200, '[{"id":1,"name":"whatever"}]', BooruType.danbooru),
        isFalse,
      );
      // 只出现其中一个标记也不算命中
      expect(
        BooruRegistry.matchesProbeResponse(
            200, '[{"tag_string":"a"}]', BooruType.danbooru),
        isFalse,
      );
    });

    test('200 但响应体不含该类型特征 → 不命中', () {
      // 实测 safebooru.org 的 /?json=1 返回 200 的 HTML 首页：只看状态码
      // 就会把 safebooru 认成 zerochan。
      expect(
        BooruRegistry.matchesProbeResponse(
            200, '<html><body>home</body></html>', BooruType.zerochan),
        isFalse,
      );
    });

    test('各类型的真实响应特征能命中', () {
      expect(
        BooruRegistry.matchesProbeResponse(
            200,
            '[{"id":1,"file_url":"x","tag_string":"a",'
            '"preview_file_url":"y"}]',
            BooruType.danbooru),
        isTrue,
      );
      expect(
        BooruRegistry.matchesProbeResponse(
            200,
            '[{"preview_url":"a","sample_url":"b","jpeg_url":"c"}]',
            BooruType.moebooru),
        isTrue,
      );
      expect(
        BooruRegistry.matchesProbeResponse(
            200,
            '[{"file_url":"a","sample_url":"b","preview_url":"c"}]',
            BooruType.sankaku),
        isTrue,
      );
      expect(
        BooruRegistry.matchesProbeResponse(
            200, '{"posts":[]}', BooruType.e621),
        isTrue,
      );
      // gelbooru/rule34/safebooru 的探测路径带 json=1，返回 JSON DAPI
      expect(
        BooruRegistry.matchesProbeResponse(
            200,
            '{"@attributes":{},"post":'
            '[{"preview_url":"x","file_url":"y"}]}',
            BooruType.rule34),
        isTrue,
      );
      // 旧特征 '<post' 是 XML 口径，对 json=1 的响应永远不命中
      expect(
        BooruRegistry.matchesProbeResponse(
            200, '<posts><post id="1"/></posts>', BooruType.rule34),
        isFalse,
      );
    });
  });

  group('每个引擎都声明单页上限', () {
    // 审查低危项点名的约定：「满页 = 还有下一页」依赖「请求 limit ≤ 站点单页
    // 上限」。不声明这个上限，站点静默截断时就会把满页误判成末页
    // （用户症状：滚动到底再也不加载）。这里把约定钉成可执行断言。
    final repositories = <String, BaseBooruRepository>{
      'danbooru': DanbooruRepository(dio: Dio(), serverId: 's'),
      'gelbooru_v2': GelbooruV2Repository(dio: Dio(), serverId: 's'),
      'moebooru': MoebooruRepository(dio: Dio(), serverId: 's'),
      'e621': E621Repository(dio: Dio(), serverId: 's'),
      'sankaku': SankakuRepository(dio: Dio(), serverId: 's'),
      'zerochan': ZerochanRepository(dio: Dio(), serverId: 's'),
      'rule34': Rule34Repository(dio: Dio(), serverId: 's'),
      'safebooru': SafebooruRepository(dio: Dio(), serverId: 's'),
      'shimmie2': Shimmie2Repository(dio: Dio(), serverId: 's'),
      'kvs': KvsRepository(dio: Dio(), serverId: 's'),
    };

    test('上限是正数，且夹持后的值就是上限', () {
      for (final entry in repositories.entries) {
        final repo = entry.value;
        expect(repo.maxPageSize, greaterThan(0), reason: entry.key);
        expect(repo.clampLimit(100000), repo.maxPageSize, reason: entry.key);
      }
    });

    test('上限以内的 limit 不被改动', () {
      for (final entry in repositories.entries) {
        expect(entry.value.clampLimit(40), 40, reason: entry.key);
      }
    });
  });
}
