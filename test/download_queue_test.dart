import 'dart:io';

import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/util/download_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// 「未完成的下载」落盘与恢复（OPT §3.3）。
///
/// 修复前进度只在内存：用户点了批量下载、中途退出或被杀进程，回来时既没有
/// 提示也没有续跑入口。这里钉住三件事——入队去重、成功出队、按年龄淘汰。
PendingDownload _item(String url, String postId,
    {String ns = 'srv', DateTime? at}) =>
    PendingDownload(
      url: url,
      postId: postId,
      namespace: ns,
      // 默认用真实当前时间：队列按「7 天内」过滤，写死的历史日期会被
      // 正确淘汰掉（测试自己先踩过一次这个坑）。
      addedAt: at ?? DateTime.now(),
    );

void main() {
  final now = DateTime.now();

  group('入队/出队策略（纯函数）', () {
    test('重复入队按 postId|url 去重', () {
      final merged = DownloadQueueOps.merge(
        [_item('/a.jpg', '1')],
        [_item('/a.jpg', '1')],
        now: now,
      );
      expect(merged, hasLength(1), reason: '同一条不该排两次');
    });

    test('同一 URL 但不同帖子是两条（不能互相顶掉）', () {
      final merged = DownloadQueueOps.merge(
        [_item('/same.jpg', '1')],
        [_item('/same.jpg', '2')],
        now: now,
      );
      expect(merged, hasLength(2));
    });

    test('过旧的条目不参与（与 .part 保鲜期同口径）', () {
      final merged = DownloadQueueOps.merge(
        [],
        [
          _item('/old.jpg', '1',
              at: now.subtract(DownloadQueueOps.maxAge +
                  const Duration(minutes: 1))),
          _item('/fresh.jpg', '2', at: now),
        ],
        now: now,
      );
      expect(merged.map((e) => e.url), ['/fresh.jpg']);
    });

    test('按时间升序', () {
      final merged = DownloadQueueOps.merge(
        [],
        [
          _item('/b.jpg', '2', at: now.add(const Duration(minutes: 2))),
          _item('/a.jpg', '1', at: now),
        ],
        now: now.add(const Duration(minutes: 3)),
      );
      expect(merged.map((e) => e.url), ['/a.jpg', '/b.jpg']);
    });

    test('超出上限时保留最新的那些', () {
      final many = [
        for (var i = 0; i < DownloadQueueOps.maxEntries + 10; i++)
          _item('/x$i.jpg', '$i',
              at: now.add(Duration(seconds: i))),
      ];
      final merged = DownloadQueueOps.merge(
        [],
        many,
        now: now.add(const Duration(hours: 1)),
      );
      expect(merged, hasLength(DownloadQueueOps.maxEntries));
      expect(merged.last.url,
          '/x${DownloadQueueOps.maxEntries + 9}.jpg',
          reason: '被砍掉的必须是最旧的');
    });

    test('出队只移除指定的那一条', () {
      final after = DownloadQueueOps.remove(
        [_item('/a.jpg', '1'), _item('/b.jpg', '2')],
        url: '/a.jpg',
        postId: '1',
      );
      expect(after.map((e) => e.url), ['/b.jpg']);
    });
  });

  group('Hive 落盘', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('boorunova_queue');
      Hive.init(tempDir.path);
      await Hive.openBox(HiveSetup.settingsBoxName);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      tempDir.deleteSync(recursive: true);
    });

    test('入队 → 读回 → 出队（跨「重启」仍在，因为读的是同一个 box）', () async {
      final store = DownloadQueueStore();
      await store.add([_item('/a.jpg', '1'), _item('/b.jpg', '2')]);

      // 换一个实例读：模拟重启后新建 store
      final reopened = DownloadQueueStore();
      final pending = await reopened.pending();
      expect(pending.map((e) => e.url), ['/a.jpg', '/b.jpg']);
      expect(pending.first.namespace, 'srv');

      await reopened.remove(url: '/a.jpg', postId: '1');
      expect((await reopened.pending()).map((e) => e.url), ['/b.jpg']);
    });

    test('重复入队不会写重（落盘层也去重）', () async {
      final store = DownloadQueueStore();
      await store.add([_item('/a.jpg', '1')]);
      await store.add([_item('/a.jpg', '1')]);
      expect(await store.pending(), hasLength(1));
    });

    test('clear 清空（用户选择忽略时）', () async {
      final store = DownloadQueueStore();
      await store.add([_item('/a.jpg', '1')]);
      await store.clear();
      expect(await store.pending(), isEmpty);
    });

    test('损坏的条目被跳过，不影响其余（容错）', () async {
      final store = DownloadQueueStore();
      await store.add([_item('/a.jpg', '1')]);
      // 直接往 box 里塞一条没有 url 的垃圾条目（存的是 JSON 字符串信封）
      await HiveSetup.settingsBox.put(
        'pending_downloads',
        '{"_v":2,"items":['
            '{"url":"/a.jpg","postId":"1","namespace":"srv","addedAt":1},'
            '{"postId":"broken"}]}',
      );
      final pending = await store.pending();
      expect(pending.map((e) => e.url), ['/a.jpg'],
          reason: '没有 url 的条目直接丢掉，其余照常恢复');
    });
  });

  group('续跑提示每运行一次（进程级额度）', () {
    setUp(resetResumePromptSlot);

    test('第一次领取成功，之后一律为 false', () {
      // 首页会随导航重建：实例字段会变成「每次回首页都问一遍」
      expect(consumeResumePromptSlot(), isTrue);
      expect(consumeResumePromptSlot(), isFalse);
      expect(consumeResumePromptSlot(), isFalse);
    });

    test('重置后可以再领（模拟下一次启动）', () {
      expect(consumeResumePromptSlot(), isTrue);
      resetResumePromptSlot();
      expect(consumeResumePromptSlot(), isTrue);
    });
  });
}
