import 'package:boorunova/boorus/kvs/parser/kvs_parser.dart';
import 'package:boorunova/boorus/shimmie2/parser/shimmie2_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// KVS（视频站）与 Shimmie2（paheal 系）的解析测试。
///
/// 固件按**实测页面**的结构构造（rule34video.com / rule34.paheal.net，
/// 2026-10 抓取，内容已替换为占位文本）。三处曾经踩空的现实：
/// - KVS 详情页里 `_preview.mp4`（悬停预览小片）出现得比正片多，兜底必须排除；
/// - KVS 缩略图的 `src` 是 base64 占位符，真地址在 `data-original`；
/// - paheal 的属性用单引号、缩略图是**无扩展名**哈希路径，靠「必须带 .jpg」
///   过滤会把整页丢掉。
void main() {
  group('KvsParser 列表', () {
    // 与实测骨架一致：卡片锚点 → 预览片链接 → 懒加载占位 + data-original
    const listHtml = '''
<div class="thumb video_1">
  <a href="https://rule34video.com/video/1111111/sample-title-here/" title="Sample Title Here">
    <img class="wrap_image" src="https://rule34video.com/get_file/1/abc/1111000/1111111/1111111_preview.mp4/" alt="">
  </a>
  <img class="thumb lazy-load"
       src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
       data-original="https://rule34video.com/contents/videos_screenshots/1111000/1111111/320x180/1.jpg"
       data-webp="https://rule34video.com/contents/videos_screenshots/1111000/1111111/336x189/1.jpg"
       width="320" height="180" alt="Sample Title Here">
  <div class="duration">05:12</div>
</div>
<div class="thumb video_1">
  <a href="/video/2222222/another-clip/" title="Another Clip">
    <img class="thumb lazy-load" src="data:image/gif;base64,R0lGODlh" data-original="/contents/2222000/2222222/320x180/1.jpg" alt="Another Clip">
  </a>
  <div class="duration">01:02</div>
</div>
''';

    test('抽出条目：/video/<id>/ 链接、data-original 缩略图、时长、slug 与标题进标签', () {
      final posts = KvsParser.parseList(
        'kvs',
        'https://rule34video.com',
        listHtml,
      );

      expect(posts.map((p) => p.id), ['1111111', '2222222']);

      final first = posts.first;
      // 真地址在 data-original，不可是 base64 占位符、也不可是 _preview.mp4
      expect(first.thumbnailUrl,
          'https://rule34video.com/contents/videos_screenshots/1111000/1111111/320x180/1.jpg');
      expect(first.thumbnailUrl, isNot(contains('base64')));
      expect(first.thumbnailUrl, isNot(contains('_preview')));
      expect(first.postUrl,
          'https://rule34video.com/video/1111111/sample-title-here/');
      // 时长走 duration（此前塞在 uploader 里，字段名与内容不符）
      expect(first.duration, '05:12');
      expect(first.uploader, isNull);
      expect(first.tags, containsAll(['sample', 'title', 'here']));
      expect(first.rating, 'e');
      // 列表页不提供播放地址，留空交给按需解析
      expect(first.originalUrl, isEmpty);
      // 但必须**显式**标记为视频帖：否则会被当成图片帖渲染缩略图
      // （用户实测症状：「最多只是显示图片」，播放器根本走不到）
      expect(first.isVideo, isTrue);
      // 相对缩略图要补成绝对地址
      expect(posts[1].thumbnailUrl,
          'https://rule34video.com/contents/2222000/2222222/320x180/1.jpg');
    });
  });

  group('KvsParser 详情页', () {
    test('flashvars 里优先选最高档 mp4（能播也能存）', () {
      const html = '''
<script>var flashvars = {
  video_url: 'https://rule34video.com/get_file/1/a/1111111/1111111.mp4',
  video_alt_url: 'https://rule34video.com/get_file/1/b/1111111/1111111_720p.mp4',
  preview_url: 'https://rule34video.com/contents/1111111/1.jpg'
};</script>
''';
      final video = KvsParser.parseVideoPage(html);
      expect(video?.url,
          'https://rule34video.com/get_file/1/b/1111111/1111111_720p.mp4');
      expect(video?.poster, 'https://rule34video.com/contents/1111111/1.jpg');
    });

    test('只有 HLS 流时也能拿到地址，并反转义 \\/ ', () {
      const html = '''
var flashvars = {"video_url":"https:\\/\\/cdn.example.com\\/hls\\/master.m3u8?token=abc"};
''';
      final video = KvsParser.parseVideoPage(html);
      expect(video?.url, 'https://cdn.example.com/hls/master.m3u8?token=abc');
    });

    test('没有 flashvars 时排除 _preview.mp4，优先 /get_file/ 正片', () {
      const html = '''
<a href="https://rule34video.com/get_file/51/hash/1111000/1111111/1111111_preview.mp4/">preview</a>
<video><source src="https://cdn.example.com/v/9/play.m3u8" type="application/x-mpegURL"></video>
<meta content="https://rule34video.com/get_file/51/hash/1111000/1111111/1111111.mp4">
''';
      expect(KvsParser.parseVideoPage(html)?.url,
          'https://rule34video.com/get_file/51/hash/1111000/1111111/1111111.mp4');
    });

    test('只有预览片时宁可返回 null（不拿预览冒充正片）', () {
      const html =
          '<a href="https://rule34video.com/get_file/51/h/1/1/1111111_preview.mp4/">p</a>';
      expect(KvsParser.parseVideoPage(html), isNull);
    });

    test('协议相对与相对路径都要补成绝对地址（播放器不认无 scheme 地址）', () {
      const html = '''
var flashvars = {"video_url":"\\/\\/cdn.example.com\\/get_file\\/1\\/a\\/v.mp4"};
''';
      final video = KvsParser.parseVideoPage(html, baseUrl: 'https://site.example');
      expect(video?.url, 'https://cdn.example.com/get_file/1/a/v.mp4');
    });

    test('带参数的地址要还原 &amp; ，否则 token 参数名会被写坏', () {
      const html = '''
var flashvars = {"video_url":"https://cdn.example.com/get_file/1/a/v.mp4?token=abc&amp;e=1"};
''';
      expect(
        KvsParser.parseVideoPage(html)?.url,
        'https://cdn.example.com/get_file/1/a/v.mp4?token=abc&e=1',
      );
    });

    test('既没有 flashvars 也没有媒体直链时返回 null（UI 报可重试的错）', () {
      expect(KvsParser.parseVideoPage('<html><body>nothing</body></html>'),
          isNull);
    });
  });

  group('Shimmie2Parser（paheal 实测形态）', () {
    test('图库 HTML：单引号属性 + 无扩展名缩略图 + title 里的标签', () {
      const html = '''
<section id='Featured_Postleft'><h3 class='shm-toggler'>T</h3><div class='blockbody'>
<div style='text-align: center;'><a href='/post/view/4716633'>
<img id='thumb_rand_4716633' title='tag_one tag_two tag_three' alt='tag_one tag_two' height='240' width='320' src='/1d/2a/9f8e7d6c5b4a39281706f5e4d3c2b1a0' loading='lazy' />
</a></div></div></section>
<div class='shm-thumb'><a href="/post/view/4716640">
<img id='thumb_4716640' title='solo' alt='solo' src='//rule34.paheal.net/3c/4d/aabbccddeeff00112233445566778899' />
</a></div>
<a class='logo' href='/post/list'><img src='//rule34.paheal.net/themes/rule34v2/rule34_logo_top.png' /></a>
''';
      final posts = Shimmie2Parser.parseList(
        'shimmie2',
        'https://rule34.paheal.net',
        html,
      );

      expect(posts.map((p) => p.id), ['4716633', '4716640']);
      final first = posts.first;
      // 无扩展名的哈希路径必须被接受（此前要求图片后缀 → 整页 0 条）
      expect(first.thumbnailUrl,
          'https://rule34.paheal.net/1d/2a/9f8e7d6c5b4a39281706f5e4d3c2b1a0');
      // 协议相对要补 scheme，不能拼成 https://site//host/...
      expect(posts[1].thumbnailUrl,
          'https://rule34.paheal.net/3c/4d/aabbccddeeff00112233445566778899');
      // 站点 logo 不算缩略图
      expect(posts.any((p) => p.thumbnailUrl.contains('themes/')), isFalse);
      expect(first.tags, ['tag_one', 'tag_two', 'tag_three']);
      expect(first.postUrl, 'https://rule34.paheal.net/post/view/4716633');
    });

    test('script 内嵌模板里的 /post/view 链接不算条目', () {
      // 实测 paheal 页面里嵌着 JS 模板，同样含 /post/view/<id> 与未闭合 <img，
      // 不剥离 script 就会把模板片段当成条目（真页面回放时抓到过 40 条全错配）。
      const html = '''
<script>var tpl = "<a href='/post/view/9999999'><img src='/aa/bb/hash'";</script>
<a href='/post/view/1234567'><img id='thumb_1234567' title='alpha beta' src='/cc/dd/hash' /></a>
''';
      final posts = Shimmie2Parser.parseList(
        'shimmie2',
        'https://rule34.paheal.net',
        html,
      );
      expect(posts.map((p) => p.id), ['1234567']);
    });

    test('title 跨行时仍能取到标签（实测 paheal 的标签串会折行）', () {
      const html = '''
<a href='/post/view/7654321'><img id='thumb_7654321'
  title='first_tag second_tag
     third_tag' alt='' src='/ee/ff/hash' /></a>
''';
      final posts = Shimmie2Parser.parseList(
        'shimmie2',
        'https://rule34.paheal.net',
        html,
      );
      expect(posts.single.tags, ['first_tag', 'second_tag', 'third_tag']);
    });

    test('详情页原图只认 og:image（实测页面没有别的原图入口）', () {
      const html = '''
<meta property="og:image" content="/1d/2a/9f8e7d6c5b4a39281706f5e4d3c2b1a0" />
''';
      expect(
        Shimmie2Parser.parsePostImage(html, 'https://rule34.paheal.net'),
        'https://rule34.paheal.net/1d/2a/9f8e7d6c5b4a39281706f5e4d3c2b1a0',
      );
      // logo 之类的资源不当原图
      expect(
        Shimmie2Parser.parsePostImage(
          '<meta property="og:image" content="/themes/x/logo.png" />',
          'https://rule34.paheal.net',
        ),
        isNull,
      );
    });

    test('JSON 接口（新版 Shimmie）：字段解析与评级归一', () {
      final posts = Shimmie2Parser.parseJson('shimmie2', {
        'posts': [
          {
            'id': 9001,
            'file': 'https://site/_images/abc/9001.png',
            'preview': 'https://site/_thumbs/abc/9001.jpg',
            'width': 1200,
            'height': 800,
            'tags': ['1girl', 'solo'],
            'rating': 'safe',
          },
          {'id': 9002}, // 无可用媒体：跳过而不是抛错
        ]
      });
      expect(posts, hasLength(1));
      expect(posts.first.rating, 's');
      expect(posts.first.aspectRatio, closeTo(1.5, 0.001));
    });

    test('无匹配内容时返回空列表', () {
      expect(
        Shimmie2Parser.parseList('shimmie2', 'https://x', '<html></html>'),
        isEmpty,
      );
      expect(Shimmie2Parser.parseJson('shimmie2', const []), isEmpty);
    });
  });
}
