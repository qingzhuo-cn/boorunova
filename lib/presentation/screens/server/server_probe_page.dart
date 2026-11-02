// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/registry.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ServerScanPage extends ConsumerStatefulWidget {
  const ServerScanPage({super.key, this.initialUrl = ''});

  final String initialUrl;

  @override
  ConsumerState<ServerScanPage> createState() => _ServerScanPageState();
}

class _ServerScanPageState extends ConsumerState<ServerScanPage> {
  final _urlController = TextEditingController();
  final _logs = <_LogEntry>[];
  bool _scanning = false;
  bool _done = false;
  bool _cancelRequested = false;
  BooruType? _result;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.initialUrl;
    if (widget.initialUrl.isNotEmpty) {
      Future.microtask(_startScan);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    // 防并发开始：探测是长跑（单引擎最坏 15s 超时）。此前没有这道闸门，
    // 而「取消」又会立刻把 _scanning 置回 false 让按钮重新可点，于是上一轮
    // 还在后台跑、下一轮已经启动，两个扫描并发写 _logs/_result。
    if (_scanning) return;

    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _addLog(T.probeInputHint, LogType.info);
      return;
    }

    setState(() {
      _scanning = true;
      _done = false;
      _result = null;
      _cancelRequested = false;
      _logs.clear();
    });

    final registry = ref.read(booruRegistryProvider);
    final engines = registry.registeredTypes;
    _addLog('> scan start: $url', LogType.header);
    _addLog('> engines: ${engines.length}', LogType.info);

    for (final type in engines) {
      // 用户点「取消」后终止后续探测，避免后台仍逐引擎跑完全部。
      if (_cancelRequested) break;

      final engine = registry.get(type);
      if (engine == null) continue;

      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      _addLog('> probing $type ...', LogType.info);

      try {
        final detected = await registry.probe(url, singleType: type);
        // await 之后页面可能已经被关掉：再读 State / setState 会崩。
        if (!mounted) return;
        // 取消也约束「迟到的命中」：用户已经点了取消，就不该再弹结果。
        if (_cancelRequested) break;
        if (detected != null) {
          _addLog('✓ $type matched! (${engine.booru.name})', LogType.success);
          setState(() {
            _result = type;
            _scanning = false;
            _done = true;
          });
          return;
        } else {
          _addLog('  $type: no response', LogType.fail);
        }
      } catch (e) {
        if (!mounted) return;
        _addLog('  $type: error - $e', LogType.fail);
      }
    }

    if (!mounted) return;
    if (_cancelRequested) {
      _addLog('> scan cancelled', LogType.info);
    } else {
      _addLog('> scan done: no match found', LogType.fail);
    }
    setState(() {
      _scanning = false;
      _done = true;
    });
  }

  void _addLog(String msg, LogType type) {
    if (mounted) {
      _logs.add(_LogEntry(msg, type));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = _logs.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(T.scanTitle),
        leading: _scanning
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: T.scanClose,
                onPressed: () => context.pop(),
              ),
      ),
      body: Column(
        children: [
          if (_scanning)
            const LinearProgressIndicator(),
          if (first && !_scanning)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(T.scanIdleHint,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
              ),
            ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: _logs.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Text(
                    e.text,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.5,
                      color: e.type == LogType.success
                          ? Colors.greenAccent
                          : e.type == LogType.fail
                              ? Colors.red.shade300
                              : e.type == LogType.header
                                  ? Colors.cyanAccent
                                  : Colors.grey.shade400,
                    ),
                  ),
                )).toList(),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: T.serverUrl,
                        hintText: T.serverUrlHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.url,
                      enabled: !_scanning,
                      onSubmitted: (_) => _startScan(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_scanning)
                    OutlinedButton(
                      // 只置取消标志，不在这里把 _scanning 置回 false：
                      // 置回后「探测」按钮马上又可选，而上一轮循环可能还卡在
                      // 某个引擎 15s 的超时里 —— 两个扫描就并发跑起来了。
                      // 循环在下一轮开头看到标志后退出，由末尾统一收尾并恢复按钮。
                      // 按下后按钮置灰，直观表示「正在停」；循环退出时
                      // 末尾的 setState 会把它换回可点的「探测」。
                      onPressed: _cancelRequested
                          ? null
                          : () {
                              _cancelRequested = true;
                              _addLog('> cancelling ...', LogType.info);
                            },
                      child: Text(T.scanCancel),
                    )
                  else if (_done && _result != null)
                    FilledButton.icon(
                      onPressed: () {
                        final url = _urlController.text.trim();
                        context.pushReplacement('/servers/editor', extra: {
                          'initialUrl': url,
                          'initialType': _result,
                        });
                      },
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(T.scanContinue),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _startScan,
                      icon: const Icon(Icons.search, size: 18),
                      label: Text(T.scanStart),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum LogType { info, success, fail, header }

class _LogEntry {
  _LogEntry(this.text, this.type);
  final String text;
  final LogType type;
}
