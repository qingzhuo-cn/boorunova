import 'dart:io';

import 'package:boorunova/data/repository/hosts/entity/host_entry.dart';
import 'package:boorunova/data/repository/hosts/user_hosts_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
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

  List<HostEntry> _parseEntries(String text) {
    final entries = <HostEntry>[];
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final ip = parts[0].trim();
        final domain = parts[1].trim();
        if (ip.isNotEmpty && domain.isNotEmpty) {
          entries.add(HostEntry(domain: domain, ip: ip));
        }
      }
    }
    return entries;
  }

  Future<void> _save() async {
    final entries = _parseEntries(_controller.text);
    await ref.read(userHostsRepoProvider).replaceAll(entries);
    ref.invalidate(userHostsRepoProvider);
    setState(() => _dirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${T.hostsParsed}${entries.length}${T.hostsRules}'),
        ),
      );
    }
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
      for (final e in existing) {
        merged[e.domain.toLowerCase()] = e;
      }
      for (final e in imported) {
        merged[e.domain.toLowerCase()] = e;
      }

      _controller.text = merged.values
          .map((h) => '${h.ip}  ${h.domain}')
          .join('\n');
      setState(() => _dirty = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${T.importSuccess}，${T.hostsParsed}${imported.length}${T.hostsRules}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${T.importFailed}: $e')),
        );
      }
    }
  }

  void _showAddDialog() {
    final domainCtrl = TextEditingController();
    final ipCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(T.addHostMapping),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: domainCtrl,
              decoration: const InputDecoration(
                labelText: T.domain,
                hintText: T.domainHint,
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ipCtrl,
              decoration: const InputDecoration(
                labelText: T.ipAddress,
                hintText: T.ipHint,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(T.cancel),
          ),
          FilledButton(
            onPressed: () {
              final domain = domainCtrl.text.trim();
              final ip = ipCtrl.text.trim();
              if (domain.isEmpty || ip.isEmpty) return;
              final newLine = '$ip  $domain';
              if (_controller.text.isEmpty) {
                _controller.text = newLine;
              } else {
                _controller.text = '${_controller.text}\n$newLine';
              }
              setState(() => _dirty = true);
              Navigator.pop(ctx);
            },
            child: const Text(T.add),
          ),
        ],
      ),
    );
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
        title: const Text(T.hostsTitle),
        actions: [
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
                '未保存的更改',
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
