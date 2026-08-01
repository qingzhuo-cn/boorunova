import 'dart:io';

import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/data/repository/history/user_history_repo.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class DataStoragePage extends StatefulWidget {
  const DataStoragePage({super.key});
  @override
  State<DataStoragePage> createState() => _DataStoragePageState();
}

class _DataStoragePageState extends State<DataStoragePage> {
  String _cacheSize = '计算中...';

  @override
  void initState() {
    super.initState();
    _calcCache();
  }

  Future<Directory?> _appTempDir() async {
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return null;
    }
  }

  Future<void> _calcCache() async {
    try {
      final temp = await _appTempDir();
      int size = 0;
      if (temp != null && temp.existsSync()) {
        await for (final e in temp.list()) {
          if (e is File) size += await e.length();
        }
      }
      setState(() => _cacheSize = '${(size / 1048576).toStringAsFixed(1)} MB');
    } catch (_) {
      setState(() => _cacheSize = '未知');
    }
  }

  Future<void> _clearCache() async {
    try {
      final temp = await _appTempDir();
      int count = 0;
      if (temp != null && temp.existsSync()) {
        await for (final e in temp.list()) {
          if (e is File) {
            await e.delete();
            count++;
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已清除 $count 个缓存文件')),
        );
        await _calcCache();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据与存储')),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.storage),
          title: const Text('缓存'),
          subtitle: Text(_cacheSize),
          trailing: TextButton(onPressed: _clearCache, child: const Text('清除')),
        ),
        Consumer(
          builder: (context, ref, _) {
            final cache = PaintingBinding.instance.imageCache;
            final imgs = cache.currentSize;
            final imgBytes = cache.currentSizeBytes;
            return ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('图片缓存'),
              subtitle: Text('$imgs 张, ${(imgBytes / 1048576).toStringAsFixed(1)} MB'),
              trailing: TextButton(
                onPressed: () {
                  cache.clear();
                  cache.clearLiveImages();
                  clearDiskCachedImages();
                  setState(() {});
                },
                child: const Text('清除'),
              ),
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final historyCount = ref.watch(userHistoryRepoProvider).count;
            return ListTile(
              leading: const Icon(Icons.history),
              title: const Text('浏览历史'),
              subtitle: Text('$historyCount 条记录'),
              trailing: TextButton(
                onPressed: () async {
                  await ref.read(userHistoryRepoProvider).clear();
                  ref.invalidate(userHistoryRepoProvider);
                },
                child: const Text('清除'),
              ),
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final downloadCount = ref.watch(userDownloadsRepoProvider).count;
            return ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('下载记录'),
              subtitle: Text('$downloadCount 条记录'),
              trailing: TextButton(
                onPressed: () async {
                  await ref.read(userDownloadsRepoProvider).clear();
                  ref.invalidate(userDownloadsRepoProvider);
                },
                child: const Text('清除'),
              ),
            );
          },
        ),
      ]),
    );
  }
}
