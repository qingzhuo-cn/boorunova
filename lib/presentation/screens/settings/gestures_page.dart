import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GesturesPage extends ConsumerWidget {
  const GesturesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('手势')),
      body: ListView(children: [
        _header('图片查看器'),
        _tile('下滑动作', s.swipeDownAction == 'detail' ? '查看详情' : '关闭', ['close', 'detail'], ['关闭', '查看详情'], n.setSwipeDownAction, s.swipeDownAction),
        _tile('单击图片', s.tapAction == 'detail' ? '查看详情' : '无', ['detail', 'none'], ['查看详情', '无'], n.setTapAction, s.tapAction),
        _tile('双击图片', s.doubleTapAction == 'fav' ? '收藏' : '缩放', ['zoom', 'fav'], ['缩放', '收藏'], n.setDoubleTapAction, s.doubleTapAction),
        _tile('长按图片', s.longPressAction == 'fav' ? '收藏' : '无', ['fav', 'none'], ['收藏', '无'], n.setLongPressAction, s.longPressAction),
      ]),
    );
  }

  Widget _header(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)));

  Widget _tile(String title, String subtitle, List<String> vals, List<String> labels, void Function(String) onChanged, String current) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: DropdownButton<String>(
        value: current, underline: const SizedBox(),
        items: List.generate(vals.length, (i) => DropdownMenuItem(value: vals[i], child: Text(labels[i], style: const TextStyle(fontSize: 13)))),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    );
  }
}
