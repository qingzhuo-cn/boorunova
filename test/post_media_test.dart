import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:flutter_test/flutter_test.dart';

PostSummary _post({
  String id = '1',
  String thumbnail = 'https://x.test/t.jpg',
  String sample = 'https://x.test/s.jpg',
  String original = 'https://x.test/o.jpg',
  String serverId = 'srv',
  String? postUrl = 'https://x.test/post/1',
  String? duration,
}) =>
    PostSummary(
      id: id,
      thumbnailUrl: thumbnail,
      sampleUrl: sample,
      originalUrl: original,
      tags: const ['a'],
      aspectRatio: 1.5,
      width: 300,
      height: 200,
      rating: 's',
      score: 42,
      serverId: serverId,
      source: 'src',
      postUrl: postUrl,
      duration: duration,
    );

void main() {
  group('isVideoPost', () {
    test('纯图片不判为视频', () {
      expect(isVideoPost(_post()), isFalse);
    });

    test('original 是 mp4 时判为视频', () {
      expect(
        isVideoPost(_post(original: 'https://x.test/o.mp4')),
        isTrue,
      );
    });

    test('sample 是 mp4 时也判为视频（original 是图）', () {
      // 回归点：详情页此前只看 sample 优先的 mediaUrl、瀑布流只看
      // original，两边口径不同。同一帖子在列表标视频、点进去按图渲染。
      expect(
        isVideoPost(_post(sample: 'https://x.test/s.mp4')),
        isTrue,
      );
    });

    test('任一字段命中即算视频', () {
      expect(
        isVideoPost(_post(
          sample: 'https://x.test/s.webm',
          original: 'https://x.test/o.jpg',
        )),
        isTrue,
      );
    });

    test('/video/ 路径与 sample 目录下的 mp4 视为视频', () {
      expect(
        isVideoPost(_post(original: 'https://x.test/video/abc')),
        isTrue,
      );
      expect(
        isVideoPost(_post(original: 'https://x.test/sample/a.mp4')),
        isTrue,
      );
    });

    test('大小写不敏感', () {
      expect(isVideoPost(_post(original: 'https://x.test/O.MP4')), isTrue);
    });

    test('扩展名在 query 参数之后也命中', () {
      expect(
        isVideoPost(_post(original: 'https://x.test/o.mp4?token=1')),
        isTrue,
      );
    });

    test('空 URL 不抛异常', () {
      expect(isVideoPost(_post(sample: '', original: '')), isFalse);
    });
  });

  group('mediaUrlOf', () {
    test('优先 sample', () {
      expect(mediaUrlOf(_post()), 'https://x.test/s.jpg');
    });

    test('sample 为空退回 original', () {
      expect(
        mediaUrlOf(_post(sample: '')),
        'https://x.test/o.jpg',
      );
    });

    test('两者皆空退回 thumbnail', () {
      expect(
        mediaUrlOf(_post(sample: '', original: '')),
        'https://x.test/t.jpg',
      );
    });
  });

  group('postKeyOf', () {
    test('不同站点的同 id 帖子键值不同', () {
      // 回归点：批量选择此前直接拿裸 postId 当 key，而切换站点时
      // batchSelection 不会被清空。A 站的 42 号选中态会误命中 B 站的
      // 42 号，被批量下载/收藏/分享一起带走。
      expect(
        postKeyOf(_post(id: '42', serverId: 'alpha')),
        isNot(postKeyOf(_post(id: '42', serverId: 'beta'))),
      );
    });

    test('同站点同 id 键值稳定', () {
      expect(
        postKeyOf(_post(id: '42', serverId: 'alpha')),
        postKeyOf(_post(id: '42', serverId: 'alpha')),
      );
    });
  });

  group('downloadUrlOf', () {
    test('preferSample 为假时走 sample → original → thumbnail 优先级', () {
      expect(downloadUrlOf(_post()), 'https://x.test/s.jpg');
      expect(
        downloadUrlOf(_post(sample: '')),
        'https://x.test/o.jpg',
      );
      expect(
        downloadUrlOf(_post(sample: '', original: '')),
        'https://x.test/t.jpg',
      );
    });

    test('preferSample 为真时优先 sample', () {
      // 回归点：单图下载、进度图标、批量下载此前各写一份三元表达式，
      // 其中一处靠注释「与这里保持一致」同步。改一处忘另一处，用户设了
      // sample 质量却会被按原图下载。
      expect(
        downloadUrlOf(_post(), preferSample: true),
        'https://x.test/s.jpg',
      );
    });

    test('sample 缺失时退回共享优先级，不返回空串', () {
      expect(
        downloadUrlOf(_post(sample: ''), preferSample: true),
        'https://x.test/o.jpg',
      );
    });
  });

  group('permalinkOf', () {
    test('优先站点帖子页链接', () {
      expect(permalinkOf(_post()), 'https://x.test/post/1');
    });

    test('postUrl 为 null 时退回原图地址', () {
      expect(
        permalinkOf(_post(postUrl: null)),
        'https://x.test/o.jpg',
      );
    });

    test('postUrl 为空串时也退回，不分享空地址', () {
      // 历史记录来自 JSON 反序列化，任何一环给出空串都不该分享出去。
      expect(
        permalinkOf(_post(postUrl: '')),
        'https://x.test/o.jpg',
      );
    });
  });

  group('PostSummary.toPost', () {
    test('全字段无损传递', () {
      // 回归点：四个收藏入口此前各手写一份 17 字段字面量，漏传是静默的。
      final src = _post();
      final post = src.toPost();
      expect(post.id, src.id);
      expect(post.serverId, src.serverId);
      expect(post.thumbnailUrl, src.thumbnailUrl);
      expect(post.sampleUrl, src.sampleUrl);
      expect(post.originalUrl, src.originalUrl);
      expect(post.tags, src.tags);
      expect(post.aspectRatio, src.aspectRatio);
      expect(post.width, src.width);
      expect(post.height, src.height);
      expect(post.rating, src.rating);
      expect(post.score, src.score);
      expect(post.source, src.source);
      expect(post.postUrl, src.postUrl);
    });

    test('标签分类字段一并传递', () {
      const src = PostSummary(
        id: '9',
        thumbnailUrl: '',
        sampleUrl: '',
        originalUrl: '',
        tags: ['g', 'a', 'c', 'cr', 'm'],
        aspectRatio: 1,
        width: 1,
        height: 1,
        rating: 'q',
        score: 0,
        tagGeneral: ['g'],
        tagArtist: ['a'],
        tagCharacter: ['c'],
        tagCopyright: ['cr'],
        tagMeta: ['m'],
      );
      final post = src.toPost();
      expect(post.tagGeneral, ['g']);
      expect(post.tagArtist, ['a']);
      expect(post.tagCharacter, ['c']);
      expect(post.tagCopyright, ['cr']);
      expect(post.tagMeta, ['m']);
    });

    test('视频时长走独立字段并随收藏往返', () {
      // 回归点：KVS 曾把时长塞进 uploader，字段名与内容不符；显示侧也
      // 没有任何消费点。现在它是自己的字段，且必须活过 toPost/fromJson。
      final src = _post(original: 'https://x.test/v.mp4', duration: '05:12');
      expect(src.toPost().duration, '05:12');
      expect(src.toPost().uploader, isNull);
      expect(BooruPost.fromJson(src.toPost().toJson()).duration, '05:12');
    });

    test('可 JSON 往返，收藏持久化不丢字段', () {
      final src = _post();
      final restored = BooruPost.fromJson(src.toPost().toJson());
      expect(restored.id, src.id);
      expect(restored.serverId, src.serverId);
      expect(restored.postUrl, src.postUrl);
      expect(restored.aspectRatio, src.aspectRatio);
    });
  });
}
