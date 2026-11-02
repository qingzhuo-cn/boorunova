// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/tags_blocker_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BlacklistPage extends ConsumerStatefulWidget {
  const BlacklistPage({super.key});

  @override
  ConsumerState<BlacklistPage> createState() => _BlacklistPageState();
}

class _BlacklistPageState extends ConsumerState<BlacklistPage> {
  final _controller = TextEditingController();

  /// 当前选择的屏蔽作用域：'' = 全局，否则是 serverId（OPT §6.4）。
  String _scope = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTags(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    ref.read(tagsBlockerStateProvider.notifier).pushAll(
          serverId: _scope,
          tags: trimmed.split(RegExp(r'\s+')),
        );
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsBlockerStateProvider);
    final servers = ref.watch(userServerRepoProvider).getAll();
    final theme = Theme.of(context);

    // 站点被删掉后，作用域下拉里不该继续留着它；退回全局避免「存下一个
    // 指向已删站点的作用域」。
    if (_scope.isNotEmpty && !servers.any((s) => s.id == _scope)) {
      _scope = '';
    }

    return Scaffold(
      appBar: AppBar(title: Text(T.blacklistTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: T.addBlockedTag,
              hintText: T.addBlockedTagHint,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                tooltip: T.add,
                onPressed: () => _addTags(_controller.text),
              ),
            ),
            onSubmitted: _addTags,
          ),
          const SizedBox(height: 12),
          // 作用域选择：各站标签体系不同，「这个词只想在某站屏蔽」是常见需求
          Row(
            children: [
              const SizedBox(width: 4),
              Text(T.blockScope, style: theme.textTheme.labelLarge),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _scope,
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(T.scopeGlobal,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    for (final server in servers)
                      DropdownMenuItem(
                        value: server.id,
                        child: Text(
                          T.blockScopeFor(server.name),
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _scope = v ?? ''),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
              T.scopeSiteHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (tags.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Icon(Icons.block, size: 48,
                        color: theme.colorScheme.onSurface.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text(T.noBlockedTags,
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5))),
                  ],
                ),
              ),
            ),
          for (final entry in tags.entries)
            ListTile(
              title: Text(entry.value.name),
              leading: const Icon(Icons.block, size: 20),
              subtitle: Text(
                entry.value.serverId.isEmpty
                    ? T.scopeGlobalShort
                    : T.blockScopeFor(
                        servers
                                .where((s) => s.id == entry.value.serverId)
                                .map((s) => s.name)
                                .firstOrNull ??
                            // 站点已删：旧条目仍按作用域存着，如实显示 id
                            entry.value.serverId,
                      ),
                style: const TextStyle(fontSize: 11),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: T.removeAction,
                onPressed: () {
                  ref.read(tagsBlockerStateProvider.notifier).delete(entry.key);
                },
              ),
              dense: true,
            ),
        ],
      ),
    );
  }
}
