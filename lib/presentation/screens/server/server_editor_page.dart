import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/screens/server/booru_site_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ServerEditorPage extends ConsumerStatefulWidget {
  const ServerEditorPage({super.key, this.serverId, this.template, this.initialUrl, this.initialName});

  final String? serverId;
  final BooruSiteTemplate? template;
  final String? initialUrl;
  final String? initialName;

  @override
  ConsumerState<ServerEditorPage> createState() => _ServerEditorPageState();
}

class _ServerEditorPageState extends ConsumerState<ServerEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _loginController;
  BooruType _selectedType = BooruType.unknown;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _urlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _loginController = TextEditingController();

    if (widget.serverId != null) {
      _isEditing = true;
      _loadServer();
    } else if (widget.template != null) {
      _selectedType = widget.template!.type;
      _nameController.text = widget.initialName ?? widget.template!.name;
      _urlController.text = widget.initialUrl ?? widget.template!.baseUrl;
    }
  }

  void _loadServer() {
    final repo = ref.read(userServerRepoProvider);
    final server = repo.getById(widget.serverId!);
    if (server != null) {
      _nameController.text = server.name;
      _urlController.text = server.baseUrl;
      _apiKeyController.text = server.apiKey ?? '';
      _loginController.text = server.login ?? '';
      _selectedType = server.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    _loginController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(userServerRepoProvider);
    final server = BooruServer.create(
      name: _nameController.text.trim(),
      baseUrl: _urlController.text.trim(),
      type: _selectedType,
      apiKey: _apiKeyController.text.trim().isEmpty
          ? null
          : _apiKeyController.text.trim(),
      login: _loginController.text.trim().isEmpty
          ? null
          : _loginController.text.trim(),
    );

    if (_isEditing) {
      await repo.update(server.copyWith(id: widget.serverId));
    } else {
      await repo.save(server);
    }

    if (mounted) {
      ref.invalidate(userServerRepoProvider);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? T.editServer : T.addNewServer),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: T.serverName,
                hintText: T.serverNameHint,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? T.required : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: T.serverUrl,
                hintText: T.serverUrlHint,
              ),
              keyboardType: TextInputType.url,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? T.required : null,
            ),
            if (widget.template != null) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: Icon(widget.template!.icon, size: 16, color: widget.template!.color),
                label: Text(widget.template!.name,
                    style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
              ),
            ],
            const SizedBox(height: 24),
            Text(
              T.authenticationOptional,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: T.apiKey,
                hintText: T.apiKeyHint,
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _loginController,
              decoration: const InputDecoration(
                labelText: T.login,
                hintText: T.loginHint,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? T.saveChanges : T.addServerBtn),
            ),
          ],
        ),
      ),
    );
  }
}
