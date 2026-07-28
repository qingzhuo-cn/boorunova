import 'dart:io';
import 'package:flutter/material.dart';

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

  Future<void> _calcCache() async {
    try {
      final temp = Directory.systemTemp;
      int size = 0;
      if (temp.existsSync()) {
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
      final temp = Directory.systemTemp;
      if (temp.existsSync()) {
        int count = 0;
        await for (final e in temp.list()) {
          if (e is File) { await e.delete(); count++; }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已清除 $count 个缓存文件')));
          await _calcCache();
        }
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
        const ListTile(
          leading: Icon(Icons.history),
          title: Text('浏览历史'),
        ),
        const ListTile(
          leading: Icon(Icons.download_outlined),
          title: Text('下载记录'),
        ),
      ]),
    );
  }
}
