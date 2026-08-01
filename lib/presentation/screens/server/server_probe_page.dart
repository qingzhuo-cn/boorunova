import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/registry.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/screens/server/server_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  BooruType? _result;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.initialUrl;
    if (widget.initialUrl.isNotEmpty) {
      Future.microtask(() => _startScan());
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _addLog('输入站点地址后点击"探测"', LogType.info);
      return;
    }

    setState(() {
      _scanning = true;
      _done = false;
      _result = null;
      _logs.clear();
    });

    final registry = ref.read(booruRegistryProvider);
    final engines = registry.registeredTypes;
    _addLog('> scan start: $url', LogType.header);
    _addLog('> engines: ${engines.length}', LogType.info);

    for (final type in engines) {
      final engine = registry.get(type);
      if (engine == null) continue;

      await Future.delayed(const Duration(milliseconds: 150));
      _addLog('> probing $type ...', LogType.info);

      try {
        final detected = await registry.probe(url, singleType: type);
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
        _addLog('  $type: error - $e', LogType.fail);
      }
    }

    _addLog('> scan done: no match found', LogType.fail);
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
        title: const Text('服务器探测'),
        leading: _scanning
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: Column(
        children: [
          if (_scanning)
            const LinearProgressIndicator(),
          if (first && !_scanning)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('点击"探测"开始匹配引擎', style: TextStyle(color: Colors.grey))),
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
                      decoration: const InputDecoration(
                        labelText: T.serverUrl,
                        hintText: T.serverUrlHint,
                        border: OutlineInputBorder(),
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
                      onPressed: () => setState(() => _scanning = false),
                      child: const Text('取消'),
                    )
                  else if (_done && _result != null)
                    FilledButton.icon(
                      onPressed: () {
                        final url = _urlController.text.trim();
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => ServerEditorPage(
                              initialUrl: url,
                              initialType: _result,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('继续'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _startScan,
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('探测'),
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
