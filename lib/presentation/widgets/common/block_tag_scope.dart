// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:flutter/material.dart';

/// 快捷屏蔽的作用域选择（OPT §5.5）。
enum BlockTagScope {
  /// 所有站点都不显示这个标签。
  global,

  /// 只在当前站点屏蔽——各站标签体系不同，`cat` 在这里是角色、在别处可能不是。
  thisSite,
}

/// 把选择映射成 `pushAll(serverId:)` 的参数。
///
/// **全局 = 空串**，这是过滤侧（`filterBlockedPosts`）依赖的约定：serverId 为空
/// 的条目对所有站点生效。两处必须同一口径，所以收成一个函数而不是各写一遍。
String blockScopeServerId(BlockTagScope scope, String serverId) =>
    scope == BlockTagScope.global ? '' : serverId;

/// 长按标签 → 问「在哪儿屏蔽」→ 返回选择（取消返回 null）。
///
/// 抽成函数的原因：作用域语义在「黑名单页」和这里必须一致，而这里是唯一从
/// **帖子上下文**推断默认做法的地方，值得能单独测（见 block_tag_scope_test）。
///
/// [canScopeToSite] 为 false 时**不提供**站点选项。这不是省事，而是修复一个
/// 静默升级：帖子的 serverId 为空时（服务器已被删等），「仅本站」根本无从谈起，
/// 而 `blockScopeServerId` 会把它退化成空串 = **全局屏蔽**——用户点的是「只在
/// 这个站」，得到的却是「哪个站都没有了」。宁可少给一个选项，也不做这种偏离
/// 用户意图的事。
Future<BlockTagScope?> askBlockTagScope(
  BuildContext context, {
  required String tag,
  String? siteName,
  bool canScopeToSite = true,
}) {
  final siteLabel = (siteName == null || siteName.isEmpty)
      ? T.blockOnThisSite
      : T.blockScopeFor(siteName);
  return showDialog<BlockTagScope>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(T.blockThisTag),
      content: Text(T.blockThisTagBody(tag)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(T.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(BlockTagScope.global),
          child: Text(T.blockGlobally),
        ),
        if (canScopeToSite)
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(BlockTagScope.thisSite),
            child: Text(siteLabel),
          ),
      ],
    ),
  );
}
