import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/foundation/network/dio_factory.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class BatchOps {
  BatchOps._();

  static Future<BatchDownloadResult> downloadAll(
      List<String> urls, List<String> postIds) async {
    final results = <BatchItem>[];

    for (int i = 0; i < urls.length; i++) {
      try {
        final dir = await getTemporaryDirectory();
        final name = urls[i].split('/').last;
        if (!name.contains('.')) {
          results.add(BatchItem(
              url: urls[i], success: false, error: 'No file extension'));
          continue;
        }

        final path = '${dir.path}/$name';
        final dio = DioFactory.createDownload();
        await dio.download(urls[i], path);
        await Gal.putImage(path);

        if (postIds.isNotEmpty && i < postIds.length) {
          final repo = UserDownloadsRepo();
          await repo.add(DownloadEntry(
            postId: postIds[i],
            imageUrl: urls[i],
            localPath: path,
            downloadedAt: DateTime.now(),
          ));
        }

        results.add(BatchItem(url: urls[i], success: true));
      } catch (e) {
        results.add(
            BatchItem(url: urls[i], success: false, error: e.toString()));
      }
    }

    return BatchDownloadResult(
      items: results,
      successCount: results.where((r) => r.success).length,
      failCount: results.where((r) => !r.success).length,
    );
  }
}

class BatchDownloadResult {
  const BatchDownloadResult({
    required this.items,
    required this.successCount,
    required this.failCount,
  });

  final List<BatchItem> items;
  final int successCount;
  final int failCount;
}

class BatchItem {
  const BatchItem({
    required this.url,
    required this.success,
    this.error,
  });

  final String url;
  final bool success;
  final String? error;
}
