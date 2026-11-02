// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:flutter/material.dart';

/// 「清空/删除」确认框的结果。
///
/// 用两个具名构造而不是 `bool?` 三态：三态里 `null`（取消）与 `false`
/// （只删记录）在调用点太容易写混，而这两者的后果完全不同。
class ClearConfirmation {
  const ClearConfirmation.cancelled()
      : confirmed = false,
        deleteLocalFiles = false;

  const ClearConfirmation.recordsOnly()
      : confirmed = true,
        deleteLocalFiles = false;

  const ClearConfirmation.withFiles()
      : confirmed = true,
        deleteLocalFiles = true;

  final bool confirmed;

  /// 是否连带删除 app 下载目录里的文件。
  ///
  /// 相册里那份**删不掉也不该删**（Gal 写进 MediaStore 的副本归系统管），
  /// 所以勾选项与说明文案必须同时出现，避免用户以为相册也清干净了。
  final bool deleteLocalFiles;
}

/// 统一的清空类确认框（历史 / 下载记录 / 搜索历史共用）。
///
/// [withFileOption] 为真时附一个「同时删除本机文件」勾选项。此前只有下载页
/// 有它，隐私页与存储页的同一个「清除下载记录」却是直接清空——同一个动作
/// 在不同入口的破坏力不一样，用户没法预期。
Future<ClearConfirmation> confirmClearDialog(
  BuildContext context, {
  required String title,
  required String content,
  String? confirmLabel,
  bool withFileOption = false,
}) async {
  var deleteFiles = false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(title),
        content: withFileOption
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(content),
                  CheckboxListTile(
                    value: deleteFiles,
                    onChanged: (v) =>
                        setDialogState(() => deleteFiles = v ?? false),
                    title: Text(T.deleteLocalFile,
                        style: const TextStyle(fontSize: 14)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              )
            : Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(T.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel ?? T.clear),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true) return const ClearConfirmation.cancelled();
  return deleteFiles
      ? const ClearConfirmation.withFiles()
      : const ClearConfirmation.recordsOnly();
}
