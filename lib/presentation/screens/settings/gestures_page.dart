// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GesturesPage extends ConsumerWidget {
  const GesturesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(T.gestures)),
      body: ListView(children: [
        SectionHeader(title: T.sectionViewer),
        _tile(
          context,
          T.swipeDownAction,
          s.swipeDownAction,
          {'close': T.actionClose, 'detail': T.actionDetail},
          n.setSwipeDownAction,
          s.swipeDownAction,
          // 下滑手势与翻页轴互斥：纵向翻页时纵轴被 PageView 占用，
          // 该设置无法生效。与其让用户以为设了没用，不如说清楚。
          hint: s.viewerSwipeMode ? null : T.swipeDownNeedsHorizontal,
        ),
        _tile(context, T.tapAction, s.tapAction, {'detail': T.actionDetail, 'none': T.actionNone}, n.setTapAction, s.tapAction),
        _tile(context, T.doubleTapAction, s.doubleTapAction, {'zoom': T.actionZoom, 'fav': T.actionFav}, n.setDoubleTapAction, s.doubleTapAction),
        _tile(context, T.longPressAction, s.longPressAction, {'fav': T.actionFav, 'none': T.actionNone}, n.setLongPressAction, s.longPressAction),
      ]),
    );
  }

  Widget _tile(BuildContext context, String title, String current,
      Map<String, String> labels, void Function(String) onChanged, String value,
      {String? hint}) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(labels[value] ?? value, style: const TextStyle(fontSize: 12)),
          if (hint != null)
            Text(
              hint,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
      trailing: DropdownButton<String>(
        value: current, underline: const SizedBox(),
        items: labels.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    );
  }
}
