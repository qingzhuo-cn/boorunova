// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/registry.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';
import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/screens/server/booru_site_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 由表单值构造「要保存的服务器」。
///
/// 抽成独立函数是为了**能被单测钉住**：编辑时必须以已有实体为起点，否则
/// 不在表单里的字段（站点偏好、创建时间）会被重置——这是真实发生过的 bug。
/// 页面层 widget 测试很难覆盖（保存后要 `context.pop()`，需要一整套可 pop 的
/// 路由栈），而这里要守的其实就是「用哪条构造路径」。
@visibleForTesting
BooruServer buildServerForSave({
  BooruServer? existing,
  required String name,
  required String baseUrl,
  required BooruType type,
  String? apiKey,
  String? login,
}) =>
    existing != null
        ? existing.withFormValues(
            name: name,
            baseUrl: baseUrl,
            type: type,
            apiKey: apiKey,
            login: login,
          )
        : BooruServer.create(
            name: name,
            baseUrl: baseUrl,
            type: type,
            apiKey: apiKey,
            login: login,
          );

class ServerEditorPage extends ConsumerStatefulWidget {
  const ServerEditorPage({super.key, this.serverId, this.template, this.initialUrl, this.initialName, this.initialType});

  final String? serverId;
  final BooruSiteTemplate? template;
  final String? initialUrl;
  final String? initialName;
  final BooruType? initialType;

  @override
  ConsumerState<ServerEditorPage> createState() => _ServerEditorPageState();
}

class _ServerEditorPageState extends ConsumerState<ServerEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _loginController;
  late BooruType _selectedType;
  bool _isEditing = false;

  /// 保存成功后，等这次路由被销毁（pop 转场结束）再刷新的容器。
  ///
  /// 用它替代原来「pop 后 `Future.delayed(400ms)`」的 hack：那个 400ms
  /// 是照着 300ms 转场时长凑出来的魔数，转场时长或「减少动画」设置一变
  /// 就对不上时机。
  ProviderContainer? _refreshOnDispose;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _urlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _loginController = TextEditingController();

    _selectedType = widget.initialType ?? BooruType.unknown;
    if (widget.serverId != null) {
      _isEditing = true;
      _loadServer();
    } else if (widget.template != null) {
      _selectedType = widget.initialType ?? widget.template!.type;
      _nameController.text = widget.initialName ?? widget.template!.name;
      _urlController.text = widget.initialUrl ?? widget.template!.baseUrl;
    } else if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
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
    _scheduleRefreshOnDispose();
    _nameController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    _loginController.dispose();
    super.dispose();
  }

  /// 路由真正结束（pop 转场完成、State 被销毁）时再刷新服务器列表。
  ///
  /// 此前是 pop 之后 `Future.delayed(400ms)` 再 invalidate：400ms 是照着
  /// 300ms 转场时长凑的魔数，用户开「减少动画」时转场为 0，这个延迟只剩
  /// 拖慢刷新；转场时长一旦调整，又可能落在转场中途 —— ServerPage 在转场
  /// 里重建列表，残留在 sliver 子节点上的 Ink 动画会画出空指针（release
  /// 下表现为整页空白）。
  ///
  /// 改挂在 State.dispose 上：它就是「路由被移除」这个框架生命周期点，
  /// 天然和转场时长解耦。另外 `Route.popped` 不能用 —— 它在 pop **开始**
  /// 时就完成，仍然是原来的危险时机。
  /// 当前选中的引擎是否用得到凭据。未知类型按「不显示」处理：
  /// 未注册的引擎连请求都发不出去，填凭据更没意义。
  bool get _needsAuth =>
      ref.read(booruRegistryProvider).get(_selectedType)?.booru.capabilities.auth ??
      false;

  void _scheduleRefreshOnDispose() {
    final container = _refreshOnDispose;
    if (container == null) return;
    // 推到下一帧：dispose 发生在卸载/构建阶段，当场改 provider 会撞上
    // 「build 期间修改 provider」的保护。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      container.invalidate(userServerRepoProvider);
    });
  }

  Future<void> _save() async {
    // 先把地址规范化再校验：用户只填域名时补 https://，并写回输入框，
    // 让「最终会存下什么」对用户可见。修复前只判非空，`example.com`
    // 会被原样存进 baseUrl —— 引擎据此拼出的是相对路径，请求必然失败。
    final parsed = _parseBaseUrl(_urlController.text);
    if (parsed != null) {
      final normalized = parsed.toString();
      if (normalized != _urlController.text.trim()) {
        _urlController.text = normalized;
      }
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedType == BooruType.unknown) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(T.engineTypeNotSet),
          content: Text(T.engineTypeNotSetMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(T.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(T.save),
            ),
          ],
        ),
      );
      // await 之后 State 可能已被销毁，继续用 ref/context 会抛。
      if (!mounted) return;
      if (confirm != true) return;
    }

    final repo = ref.read(userServerRepoProvider);

    // 按规范化地址查重：`HTTPS://Danbooru.Donmai.us/` 与
    // `https://danbooru.donmai.us` 是同一个站点。修复前完全不查重，
    // 同一个站点能重复添加，列表里出现多份、编辑时也分不清是哪个。
    final key = _dedupeKey(_urlController.text);
    final self =
        widget.serverId == null ? null : repo.getById(widget.serverId!);
    BooruServer? existing;
    // 编辑时若地址没动就不查重：库里历史遗留的重复项不该每次保存都弹窗。
    if (self == null || _dedupeKey(self.baseUrl) != key) {
      for (final s in repo.getAll()) {
        if (s.id == widget.serverId) continue; // 编辑自己不算重复
        if (_dedupeKey(s.baseUrl) == key) {
          existing = s;
          break;
        }
      }
    }
    if (existing != null) {
      final action = await _askDuplicate(existing);
      if (!mounted) return;
      switch (action) {
        case _DuplicateAction.editExisting:
          // 地址既然已经在用，直接切到那个服务器的编辑页，别让用户在
          // 「新增」里白填一遍、最后还是存出重复项。
          context.pushReplacement('/servers/editor',
              extra: {'serverId': existing.id});
          return;
        case _DuplicateAction.saveAnyway:
          break;
        case _DuplicateAction.cancel:
          return;
      }
    }

    final name = _nameController.text.trim();
    final baseUrl = _urlController.text.trim();
    final apiKey = _apiKeyController.text.trim().isEmpty
        ? null
        : _apiKeyController.text.trim();
    final login = _loginController.text.trim().isEmpty
        ? null
        : _loginController.text.trim();

    // 编辑时**从已有实体出发**：create() + copyWith(id:) 会把不在表单里的字段
    // （站点偏好、创建时间）重置成默认值——用户改个地址就会丢掉站点偏好。
    // （`self` 是本次保存开始时读到的自己，见上面的查重逻辑。）
    final server = buildServerForSave(
      existing: self,
      name: name,
      baseUrl: baseUrl,
      type: _selectedType,
      apiKey: apiKey,
      login: login,
    );

    // 凭据写不进安全存储时站点仍然保存成功，但凭据只在本会话有效——
    // 必须让用户知道，否则下次启动它会静默消失（用户只会觉得「Key 又没了」）。
    final credentialsPersisted = await repo.save(server);

    if (!mounted) return;
    if (!credentialsPersisted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(T.credentialsNotStored),
          duration: const Duration(seconds: 5),
        ),
      );
    }
    // 容器必须在 pop 之前拿到：pop 之后这个 State 会被销毁，context 失效。
    _refreshOnDispose = ProviderScope.containerOf(context, listen: false);
    context.pop();
  }

  /// 地址重复时的三选一弹窗。
  Future<_DuplicateAction> _askDuplicate(BooruServer existing) async {
    final action = await showDialog<_DuplicateAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(T.serverUrlExistsTitle),
        content: Text(T.serverUrlExistsMessage(existing.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_DuplicateAction.cancel),
            child: Text(T.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_DuplicateAction.saveAnyway),
            child: Text(T.saveAnyway),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_DuplicateAction.editExisting),
            child: Text(T.editExisting),
          ),
        ],
      ),
    );
    // 点遮罩/返回键关掉弹窗时按「取消」处理，不静默保存。
    return action ?? _DuplicateAction.cancel;
  }

  /// 解析并校验用户输入的站点地址，不合法返回 null。
  ///
  /// 修复前只判非空：没写 scheme 的 `example.com` 与 `ftp://…` 都能存进
  /// baseUrl，引擎拼请求地址时分别得到相对路径和错误协议，搜索必然失败。
  static Uri? _parseBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    // 没写协议时按 https 试解析：BYO-Server 场景下用户只填域名是常态。
    final candidate = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(candidate);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    // Uri.tryParse 很宽容：`not a url` 会被解析成 host=`not%20a%20url`。
    // host 里出现转义字符一定是垃圾输入；空 host（如 `http://`）同样拒绝。
    if (uri.host.isEmpty || uri.host.contains('%')) return null;
    return uri;
  }

  /// 查重用的规范化键：补齐协议后 trim + 小写 + 去尾部斜杠。
  ///
  /// 老的服务器记录可能是没写协议存下的（修复前的行为），所以先走一遍
  /// [_parseBaseUrl] 再比，才能和新输入的规范化地址对上。
  static String _dedupeKey(String url) {
    var s = (_parseBaseUrl(url)?.toString() ?? url).trim().toLowerCase();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// 地址栏的 validator：解析失败或协议不是 http(s) 时给出对症提示。
  String? _validateUrl(String? v) {
    final raw = v?.trim() ?? '';
    if (raw.isEmpty) return T.required;
    if (_parseBaseUrl(raw) != null) return null;
    final scheme =
        raw.contains('://') ? raw.split('://').first.toLowerCase() : '';
    if (scheme.isNotEmpty && scheme != 'http' && scheme != 'https') {
      return T.urlSchemeUnsupported;
    }
    return T.invalidUrl;
  }

  /// 地址栏下方的一行提示；没有需要提醒的内容时不占位。
  ///
  /// 用 ValueListenableBuilder 只重建这一小块，避免每敲一个字整页 setState。
  Widget _urlNotice(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    if (!text.contains('://')) {
      return _UrlNoticeLine(
        icon: Icons.info_outline,
        color: Theme.of(context).colorScheme.primary,
        text: T.urlSchemeWillBeAdded,
      );
    }
    if (text.toLowerCase().startsWith('http://')) {
      // http 明文：登录名/API Key 与浏览内容都可能被中间人读取。
      // 不阻止保存（有些老站点只有 http），但必须给醒目提示。
      return _UrlNoticeLine(
        icon: Icons.warning_amber_rounded,
        color: Colors.orange.shade800,
        text: T.urlInsecureWarning,
      );
    }
    return const SizedBox.shrink();
  }

  /// 引擎下拉的候选项。
  ///
  /// 修复前只列了 [BooruSiteTemplate.all] 里的类型 + unknown，两处都会踩
  /// DropdownButtonFormField「value 必须恰好命中一个 item」的断言：
  /// 1) gelbooruV2 有 5 个镜像模板 → 5 个同值 item，debug 打开 Gelbooru 直接崩；
  /// 2) planned 引擎（anime-pictures / e-shuushuu）在 items 里根本没有条目，
  ///    打开这类遗留服务器时 debug 断言崩溃、release 显示空白且改不回来。
  /// 这里改为覆盖 [BooruType.values] 全集、每个 type 只留第一个模板名，
  /// 未注册引擎的条目标注「未实现」并禁用。
  /// 引擎显示名。优先用出厂模板名；Play 版没有模板（site_presets 编译期
  /// 置空），改用同一份数据里的中性引擎名——它只描述协议家族，不含站点名。
  String _engineLabel(BooruType type, Map<BooruType, String> templateNames) {
    if (kPlayBuild) {
      return kNeutralEngineNames[type] ?? templateNames[type] ?? type.value;
    }
    return templateNames[type] ?? type.value;
  }

  List<DropdownMenuItem<BooruType>> _engineItems() {
    final registry = ref.read(booruRegistryProvider);
    final labels = <BooruType, String>{};
    for (final t in [...BooruSiteTemplate.all, ...BooruSiteTemplate.planned]) {
      labels.putIfAbsent(t.type, () => t.name);
    }
    return [
      for (final type in BooruType.values)
        if (type != BooruType.unknown)
          DropdownMenuItem(
            value: type,
            // 未实现的引擎可选会造出打不开的站点，直接禁用；但当前值命中的
            // 条目仍能正常显示出来（DropdownButton 允许选中项是 disabled）。
            enabled: registry.isRegistered(type),
            child: Text(
              registry.isRegistered(type)
                  ? _engineLabel(type, labels)
                  : '${_engineLabel(type, labels)}${T.engineNotImplementedSuffix}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
      DropdownMenuItem(
        value: BooruType.unknown,
        child: Text(T.engineAutoOther, style: const TextStyle(fontSize: 13)),
      ),
    ];
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
              decoration: InputDecoration(
                labelText: T.serverName,
                hintText: T.serverNameHint,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? T.required : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: T.serverUrl,
                hintText: T.serverUrlHint,
              ),
              keyboardType: TextInputType.url,
              validator: _validateUrl,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _urlController,
              builder: (context, value, _) => _urlNotice(value.text),
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
            const SizedBox(height: 16),
            DropdownButtonFormField<BooruType>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: T.engineType,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: _engineItems(),
              onChanged: (v) => setState(() => _selectedType = v ?? BooruType.unknown),
            ),
            if (_selectedType != BooruType.unknown &&
                !ref.read(booruRegistryProvider).isRegistered(_selectedType))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  T.engineNotImplemented,
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
              ),
            const SizedBox(height: 24),
            // 只给「用得到凭据」的引擎显示凭据输入。填了也不生效的输入框
            // 只会让用户以为自己配错了（能力声明见 BooruCapabilities.auth）。
            if (_needsAuth) ...[
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
                decoration: InputDecoration(
                  labelText: T.apiKey,
                  hintText: T.apiKeyHint,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _loginController,
                decoration: InputDecoration(
                  labelText: T.login,
                  hintText: T.loginHint,
                ),
              ),
            ] else if (_selectedType != BooruType.unknown)
              Text(
                T.engineNoAuthNeeded,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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

/// 地址重复时用户在弹窗里的选择。
enum _DuplicateAction { cancel, saveAnyway, editExisting }

/// 地址栏下方的一行提示（图标 + 文案）。
class _UrlNoticeLine extends StatelessWidget {
  const _UrlNoticeLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }
}
