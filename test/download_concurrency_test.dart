import 'package:boorunova/foundation/util/batch_ops.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// 批量下载并发数（OPT §3.2）的边界与分批契约。
///
/// 这条设置的三个消费者（滑杆 UI、设置反序列化、下载分批）必须用同一组边界，
/// 否则会出现「UI 能选 6、实际被夹回 3」这种看不见的不一致。
void main() {
  group('分批契约', () {
    test('并发 1 = 串行，每批一个', () {
      expect(concurrencyBatches(3, 1), [(0, 1), (1, 2), (2, 3)]);
    });

    test('正好整除', () {
      expect(concurrencyBatches(6, 3), [(0, 3), (3, 6)]);
    });

    test('最后一批不满', () {
      expect(concurrencyBatches(7, 3), [(0, 3), (3, 6), (6, 7)]);
    });

    test('越界输入被夹紧（不会出现 0 并发导致死循环）', () {
      expect(concurrencyBatches(4, 0), concurrencyBatches(4, minDownloadConcurrency));
      expect(concurrencyBatches(20, 999),
          concurrencyBatches(20, maxDownloadConcurrency));
      // 关键：所有任务都被覆盖且不重叠
      final batches = concurrencyBatches(20, 999);
      final covered = <int>[];
      for (final (start, end) in batches) {
        for (var i = start; i < end; i++) {
          covered.add(i);
        }
      }
      expect(covered, List.generate(20, (i) => i));
    });

    test('空任务没有批次', () {
      expect(concurrencyBatches(0, 3), isEmpty);
      expect(concurrencyBatches(-5, 3), isEmpty);
    });
  });

  group('设置的边界与持久化', () {
    test('越界值被夹到合法范围', () {
      expect(
        AppSettings.fromJson(const {'downloadConcurrency': 0}).downloadConcurrency,
        minDownloadConcurrency,
      );
      expect(
        AppSettings.fromJson(const {'downloadConcurrency': 99}).downloadConcurrency,
        maxDownloadConcurrency,
      );
    });

    test('老设置没有这个键 → 默认值与改动前写死的并发一致', () {
      expect(const AppSettings().downloadConcurrency, defaultDownloadConcurrency);
      expect(defaultDownloadConcurrency, 3, reason: '改动前 batch_ops 写死 3');
      expect(
        AppSettings.fromJson(const {}).downloadConcurrency,
        defaultDownloadConcurrency,
      );
    });

    test('toJson → fromJson 往返保留', () {
      const source = AppSettings(downloadConcurrency: 5);
      expect(
        AppSettings.fromJson(source.toJson()).downloadConcurrency,
        5,
      );
    });
  });
}
