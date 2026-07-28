import 'package:flutter_riverpod/flutter_riverpod.dart';

class DownloadProgress {
  const DownloadProgress({
    required this.url,
    required this.postId,
    this.progress = 0.0,
    this.status = DownloadStatus.downloading,
    this.error,
  });

  final String url;
  final String postId;
  final double progress;
  final DownloadStatus status;
  final String? error;

  DownloadProgress copyWith({double? progress, DownloadStatus? status, String? error}) =>
      DownloadProgress(url: url, postId: postId, progress: progress ?? this.progress, status: status ?? this.status, error: error);
}

enum DownloadStatus { downloading, completed, failed }

final downloadProgressProvider = StateNotifierProvider<DownloadProgressNotifier, List<DownloadProgress>>((ref) {
  return DownloadProgressNotifier();
});

class DownloadProgressNotifier extends StateNotifier<List<DownloadProgress>> {
  DownloadProgressNotifier() : super([]);

  void start(String url, String postId) {
    state = [...state, DownloadProgress(url: url, postId: postId)];
  }

  void update(String url, double progress) {
    state = state.map((d) => d.url == url ? d.copyWith(progress: progress) : d).toList();
  }

  void complete(String url) {
    state = state.map((d) => d.url == url ? d.copyWith(status: DownloadStatus.completed, progress: 1.0) : d).toList();
    Future.delayed(const Duration(seconds: 2), () {
      state = state.where((d) => d.url != url).toList();
    });
  }

  void fail(String url, String error) {
    state = state.map((d) => d.url == url ? d.copyWith(status: DownloadStatus.failed, error: error) : d).toList();
  }

  void remove(String url) {
    state = state.where((d) => d.url != url).toList();
  }
}
