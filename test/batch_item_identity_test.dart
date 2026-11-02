import 'package:boorunova/foundation/util/batch_ops.dart';
import 'package:flutter_test/flutter_test.dart';

/// 批量结果必须带上 `postId`（OPT §3.3 的持久化队列按 `postId|url` 出队）。
///
/// 只按 URL 出队会在「同一媒体地址被两个帖子下载」时误删另一条——这正是
/// 进度模型当初踩过的坑（见 download_progress 的身份注释）。
void main() {
  test('BatchItem 带 postId，且可空', () {
    const withId = BatchItem(url: '/a.jpg', postId: '42', success: true);
    const without = BatchItem(url: '/a.jpg', success: true);
    expect(withId.postId, '42');
    expect(without.postId, isNull);
  });

  test('同一 URL 的两个帖子是两条不同身份（出队不会互相顶掉）', () {
    const a = BatchItem(url: '/same.jpg', postId: '1', success: true);
    const b = BatchItem(url: '/same.jpg', postId: '2', success: true);
    expect(a.postId == b.postId, isFalse);
    expect('${a.postId}|${a.url}', isNot('${b.postId}|${b.url}'));
  });
}
