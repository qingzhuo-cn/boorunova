// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:io';

import 'package:boorunova/data/repository/hosts/entity/host_entry.dart';
import 'package:boorunova/data/repository/hosts/user_hosts_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HostsPage extends ConsumerStatefulWidget {
  const HostsPage({super.key});

  @override
  ConsumerState<HostsPage> createState() => _HostsPageState();
}

class _HostsPageState extends ConsumerState<HostsPage> {
  late TextEditingController _controller;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _buildText());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _buildText() {
    final hosts = ref.read(userHostsRepoProvider).getAll();
    if (hosts.isEmpty) return '';
    return hosts.map((h) => '${h.ip}  ${h.domain}').join('\n');
  }

  /// 解析编辑器文本，返回合法条目与因格式非法被丢弃的行数。
  ///
  /// 校验不是可选项：此前任意字符串都能当 IP（包括 `com`），而域名也没有
  /// 拒绝单标签——一条 `1.2.3.4 com` 会被存进映射表，`match()` 的
  /// `endsWith('.com')` 于是命中所有 .com 站点，等于用一行规则劫持整个
  /// 顶级域。IP 用 `InternetAddress.tryParse` 校验（只认字面量），域名要求
  /// 至少两段（含点）。
  ({List<HostEntry> entries, int rejected}) _parseEntries(String text) {
    final entries = <HostEntry>[];
    var rejected = 0;
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 2) {
        rejected++;
        continue;
      }
      final ip = parts[0].trim();
      final domain = parts[1].trim();
      if (!UserHostsRepo.isValidIp(ip) ||
          !UserHostsRepo.isValidDomain(domain)) {
        rejected++;
        continue;
      }
      entries.add(HostEntry(domain: domain, ip: ip));
    }
    return (entries: entries, rejected: rejected);
  }

  Future<void> _save() async {
    final parsed = _parseEntries(_controller.text);
    await ref.read(userHostsRepoProvider).replaceAll(parsed.entries);
    // await 之后 widget 可能已被销毁：此前 setState 没有 mounted 检查，
    // 保存时页面若已 pop（系统返回/返回手势）会触发 setState after dispose。
    if (!mounted) return;
    ref.invalidate(userHostsRepoProvider);
    setState(() => _dirty = false);
    final rejected = parsed.rejected;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          rejected > 0
              ? '${T.hostsParsed}${parsed.entries.length}${T.hostsRules}'
                  '，${T.hostsInvalidLines(rejected)}'
              : '${T.hostsParsed}${parsed.entries.length}${T.hostsRules}',
        ),
      ),
    );
  }

  Future<void> _importFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result == null || result.files.isEmpty) return;
      final file = File(result.files.first.path!);
      final content = await file.readAsString();

      final existing = _parseEntries(_controller.text);
      final imported = _parseEntries(content);
      final merged = <String, HostEntry>{};
      for (final e in existing.entries) {
        merged[e.domain.toLowerCase()] = e;
      }
      for (final e in imported.entries) {
        merged[e.domain.toLowerCase()] = e;
      }

      // 文件读取也是 await 点，之后才碰 controller/setState，必须先确认
      // 页面还在（此前这里也没有 mounted 检查）。
      if (!mounted) return;
      _controller.text = merged.values
          .map((h) => '${h.ip}  ${h.domain}')
          .join('\n');
      setState(() => _dirty = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${T.importSuccess}，${T.hostsParsed}${imported.entries.length}${T.hostsRules}'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          // 别把裸异常丢给用户（审查 L-9）：走全应用同一份映射
          SnackBar(content: Text('${T.importFailed}：${T.friendlyError(e)}')),
        );
      }
    }
  }

  Future<void> _showAddDialog() async {
    // 弹窗文案由独立 StatefulWidget 持有，关闭时统一 dispose 两个
    // TextEditingController——此前它们在方法里创建后从不释放，
    // 每开一次弹窗就泄漏两个 controller（连同焦点节点与监听）。
    final line = await showDialog<String>(
      context: context,
      builder: (_) => const _AddHostDialog(),
    );
    if (line == null || !mounted) return;
    final existing = _controller.text;
    _controller.text = existing.isEmpty ? line : '$existing\n$line';
    setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final hosts = ref.watch(userHostsRepoProvider).getAll();
    final text = _buildText();
    if (!_dirty && _controller.text != text) {
      _controller.text = text;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(T.hostsTitle),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final enabled = ref.watch(settingsProvider).hostsEnabled;
              return IconButton(
                icon: Icon(enabled ? Icons.power_settings_new : Icons.power_settings_new_outlined,
                    color: enabled ? Theme.of(context).colorScheme.primary : null),
                tooltip: enabled ? T.hostsOnTip : T.hostsOffTip,
                onPressed: () {
                  ref.read(settingsProvider.notifier).setHostsEnabled(!enabled);
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: T.addHost,
            onPressed: _showAddDialog,
          ),
          IconButton(
            icon: const Icon(Icons.file_open_outlined),
            tooltip: T.importHostsFile,
            onPressed: _importFile,
          ),
          if (_dirty)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: T.save,
              onPressed: _save,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_dirty)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.tertiaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                T.unsavedChanges,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                  fontSize: 12,
                ),
              ),
            ),
          Expanded(
            child: hosts.isEmpty && !_dirty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.dns_outlined,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          T.noHostMappings,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          T.addMappingsHint,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.3),
                              ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        hintText: T.hostsEditorExample,
                        hintStyle: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.6,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.3),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      onChanged: (_) {
                        if (!_dirty) setState(() => _dirty = true);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 添加 Host 规则的弹窗。
///
/// 独立成 StatefulWidget 只为一件事：有地方 dispose 两个
/// TextEditingController（顺带把校验提示渲染在输入框上）。
class _AddHostDialog extends StatefulWidget {
  const _AddHostDialog();

  @override
  State<_AddHostDialog> createState() => _AddHostDialogState();
}

class _AddHostDialogState extends State<_AddHostDialog> {
  final _domainCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _domainCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final domain = _domainCtrl.text.trim();
    final ip = _ipCtrl.text.trim();
    if (domain.isEmpty || ip.isEmpty) return;
    if (!UserHostsRepo.isValidIp(ip) ||
        !UserHostsRepo.isValidDomain(domain)) {
      // 与编辑器保存用同一套校验
      setState(() => _error = T.hostsRuleInvalid);
      return;
    }
    Navigator.pop(context, '$ip  $domain');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(T.addHostMapping),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _domainCtrl,
            decoration: InputDecoration(
              labelText: T.domain,
              hintText: T.domainHint,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ipCtrl,
            decoration: InputDecoration(
              labelText: T.ipAddress,
              hintText: T.ipHint,
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(T.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(T.add),
        ),
      ],
    );
  }
}
