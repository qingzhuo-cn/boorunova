// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/screens/search/search_submission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 首页底部悬浮搜索栏：自身透明，玻璃质感由外层 GlassContainer 提供。
class HomeSearchBar extends ConsumerWidget {
  const HomeSearchBar({
    super.key,
    required this.hintText,
    required this.onSubmitted,
    this.leading,
    this.collapsed = false,
    this.onScrollToTop,
    this.currentQuery = '',
  });

  final String hintText;

  /// 提交包含评级的结构化查询（不是裸字符串：评级要交给引擎映射）。
  final ValueChanged<SearchSubmission> onSubmitted;
  final Widget? leading;
  final bool collapsed;
  final VoidCallback? onScrollToTop;
  final String currentQuery;

  Future<void> _openSearchPage(BuildContext context) async {
    final submission = await context.push<SearchSubmission>(
      '/search',
      extra: {'initialQuery': currentQuery},
    );
    if (submission != null && submission.query.trim().isNotEmpty) {
      onSubmitted(submission);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        children: [
          if (leading != null) leading!,
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: T.tapToSearch,
            onPressed: () => _openSearchPage(context),
          ),
          Expanded(
            child: GestureDetector(
              // 必须显式声明 opaque：容器没有 decoration，命中测试只覆盖
              // 文字字形本身，点到文字左右的空白处会落空——用户反映的
              // 「必须点放大镜才能进搜索」就是这个原因。已用回归测试证伪过：
              // 去掉这一行，test/video_controls_test.dart 里"点空白处"的
              // 用例立刻失败。
              behavior: HitTestBehavior.opaque,
              onTap: () => _openSearchPage(context),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.centerLeft,
                child: Text(
                  currentQuery.isNotEmpty ? currentQuery : T.tapToSearch,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: currentQuery.isNotEmpty
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          if (collapsed)
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                icon: const Icon(Icons.arrow_upward_rounded),
                tooltip: T.backToTop,
                onPressed: onScrollToTop,
              ),
            )
          else
            SizedBox(
              width: 40,
              height: 40,
              child: Tooltip(
                message: T.switchColumns,
                child: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () {
                    // 在 [minGridColumns]-[maxGridColumns] 之间循环。
                    // 列数存在 settings 里（随 Hive 持久化），此前是内存
                    // StateProvider，杀进程就丢。
                    final current = ref.read(settingsProvider).gridColumns;
                    final next = current >= maxGridColumns
                        ? minGridColumns
                        : current + 1;
                    ref.read(settingsProvider.notifier).setGridColumns(next);
                  },
                  child: Text('${ref.watch(settingsProvider).gridColumns}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
