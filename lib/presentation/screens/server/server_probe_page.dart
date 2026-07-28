import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/registry.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/screens/server/booru_site_template.dart';
import 'package:boorunova/presentation/screens/server/server_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ServerProbePage extends ConsumerStatefulWidget {
  const ServerProbePage({super.key});

  @override
  ConsumerState<ServerProbePage> createState() => _ServerProbePageState();
}

class _ProbeResult {
  _ProbeResult({
    required this.type,
    required this.name,
    required this.icon,
    required this.color,
  });

  final BooruType type;
  final String name;
  final IconData icon;
  final MaterialColor color;
  bool testing = false;
  bool success = false;
}

class _ServerProbePageState extends ConsumerState<ServerProbePage> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  BooruType? _selectedType;
  bool _probing = false;
  bool _probed = false;
  late List<_ProbeResult> _results;

  @override
  void initState() {
    super.initState();
    _results = BooruSiteTemplate.all
        .where((t) => _isRegistered(t.type))
        .map((t) => _ProbeResult(
              type: t.type,
              name: t.name,
              icon: t.icon,
              color: t.color,
            ))
        .toList();
  }

  bool _isRegistered(BooruType type) {
    final registry = ref.read(booruRegistryProvider);
    return registry.isRegistered(type);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _probe() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _probing = true;
      _probed = false;
      _selectedType = null;
      for (final r in _results) {
        r.testing = true;
        r.success = false;
      }
    });

    final registry = ref.read(booruRegistryProvider);

    for (int i = 0; i < _results.length; i++) {
      if (!mounted) return;
      try {
        final detected = await registry.probe(url,
            singleType: _results[i].type);
        if (mounted) {
          setState(() {
            _results[i].testing = false;
            _results[i].success = detected != null;
            if (detected != null && _selectedType == null) {
              _selectedType = detected;
              _probed = true;
              _nameController.text = _results[i].name;
            }
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _results[i].testing = false);
        }
      }
    }

    if (mounted) {
      setState(() => _probing = false);
    }
  }

  void _save() {
    if (_selectedType == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ServerEditorPage(
          template: BooruSiteTemplate.findByType(_selectedType!),
          initialUrl: _urlController.text.trim(),
          initialName: _nameController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(T.addSite)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: T.serverUrl,
              hintText: T.urlHint,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: _probing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                onPressed: _probing ? null : _probe,
              ),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.search,
                onSubmitted: (_) => _probe(),
          ),
          const SizedBox(height: 24),
          if (_probing || _probed) ...[
            Text(
              T.engineMatchResults,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ..._results.map(_buildResultTile),
            const SizedBox(height: 24),
            if (_selectedType != null) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: T.serverName,
                  hintText: T.serverNameHint,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text(T.confirmAdd),
              ),
            ],
          ],
          if (!_probing && !_probed)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Icon(Icons.link, size: 48,
                        color: theme.colorScheme.primary.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text(
                      T.enterUrlToMatch,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultTile(_ProbeResult r) {
    final isSelected = _selectedType == r.type;
    final statusIcon = r.testing
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : r.success
            ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
            : Icon(Icons.cancel, color: Colors.grey.shade400, size: 18);

    return Card(
      color: isSelected
          ? r.color.withOpacity(0.1)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: r.color.withOpacity(0.2),
          child: Icon(r.icon, color: r.color, size: 18),
        ),
        title: Text(r.name, style: const TextStyle(fontSize: 14)),
        trailing: statusIcon,
        selected: isSelected,
        onTap: r.success
            ? () {
                setState(() {
                  _selectedType = r.type;
                  _nameController.text = r.name;
                });
              }
            : null,
      ),
    );
  }
}
