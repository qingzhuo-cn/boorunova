import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

typedef OnProgress = void Function(double progress);

class ImageDownloader {
  ImageDownloader._();

  static Future<DownloadResult> downloadImage(
    String url, {
    String? postId,
    int? width,
    int? height,
    OnProgress? onProgress,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final name = url.split('/').last;
      if (!name.contains('.')) {
        return const DownloadResult(success: false, error: 'No file extension');
      }

      final path = '${dir.path}/$name';
      final dio = Dio();
      await dio.download(
        url, path,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      await Gal.putImage(path);

      if (postId != null) {
        final repo = UserDownloadsRepo();
        await repo.add(DownloadEntry(
          postId: postId,
          imageUrl: url,
          localPath: path,
          downloadedAt: DateTime.now(),
          width: width,
          height: height,
        ));
      }

      return const DownloadResult(success: true);
    } catch (e) {
      return DownloadResult(success: false, error: e.toString());
    }
  }
}

class DownloadResult {
  const DownloadResult({required this.success, this.error});

  final bool success;
  final String? error;
}
