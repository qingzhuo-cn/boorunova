// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/data/repository/server/entity/server_preferences.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/foundation/util/download_paths.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 站点级偏好设置页（文档 §6.4）。
///
/// 三项都**默认跟随全局**，所以新加站点什么都不用改；改动即时落盘，不设
/// 保存按钮（与其它设置页一致）。
///
/// 落盘走 [UserServerRepo.savePreferences]，**不碰凭据**：改一个画质不该
/// 顺手触发一次安全存储的写入与复核。
class ServerPreferencesPage extends ConsumerStatefulWidget {
  const ServerPreferencesPage({super.key, required this.serverId});

  final String serverId;

  @override
  ConsumerState<ServerPreferencesPage> createState() =>
      _ServerPreferencesPageState();
}

class _ServerPreferencesPageState
    extends ConsumerState<ServerPreferencesPage> {
  late final TextEditingController _subdirController;
  late ServerPreferences _preferences;
  bool _subdirValid = true;

  @override
  void initState() {
    super.initState();
    final server = ref.read(userServerRepoProvider).getById(widget.serverId);
    _preferences = server?.preferences ?? const ServerPreferences();
    _subdirController =
        TextEditingController(text: _preferences.downloadSubdir);
  }

  @override
  void dispose() {
    _subdirController.dispose();
    super.dispose();
  }

  Future<void> _update(ServerPreferences next) async {
    setState(() => _preferences = next);
    await ref
        .read(userServerRepoProvider)
        .savePreferences(widget.serverId, next);
    if (!mounted) return;
    ref.invalidate(userServerRepoProvider);

    // 改的如果是**正在浏览的那个站点**，立刻按新偏好重拉一次。
    // 否则用户改完回到首页，看到的还是按旧评级拉来的内容，只有再搜一次
    // 才生效——「设置看起来没起作用」正是这类问题的典型观感。
    final pageState = ref.read(booruPageStateProvider);
    if (pageState.serverId != widget.serverId) return;
    final notifier = ref.read(booruPageStateProvider.notifier);
    await notifier.search(
      notifier.currentQuery,
      rating: effectiveRatingForServer(
        settings: ref.read(settingsProvider),
        preferences: next,
      ),
    );
  }

  /// 子目录提交：非法输入直接拒绝并提示，而不是静默存成别的东西。
  void _commitSubdir() {
    final raw = _subdirController.text;
    final sanitized = sanitizeSubdirName(raw);
    final valid = raw.trim().isEmpty || sanitized == raw.trim();
    setState(() => _subdirValid = valid);
    if (!valid) return;
    _update(_preferences.copyWith(downloadSubdir: sanitized));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final server = ref.watch(userServerRepoProvider).getById(widget.serverId);
    if (server == null) {
      return Scaffold(
        appBar: AppBar(title: Text(T.serverPreferences)),
        body: EmptyState(
          icon: Icons.dns_outlined,
          title: T.noServerSelected,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(T.serverPreferences)),
      body: ListView(children: [
        ListTile(
          title: Text(server.name),
          subtitle: Text(server.baseUrl,
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const Divider(),
        SectionHeader(title: T.visibleRating),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(T.visibleRatingSub,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, children: [
            _chip(T.ratingFollowGlobal, null, _preferences.visibleRating),
            _chip(T.safe, 's', _preferences.visibleRating),
            _chip(T.questionable, 'q', _preferences.visibleRating),
            _chip(T.explicit, 'e', _preferences.visibleRating),
          ]),
        ),
        const SizedBox(height: 8),
        // 预览画质（与下载画质分开：预览省流量、下载存原图是常见组合）
        SectionHeader(title: T.previewQuality),
        ListTile(
          subtitle: Text(T.previewQualitySub, style: theme.textTheme.bodySmall),
          trailing: _qualitySelector(
            value: _preferences.previewQuality,
            onChanged: (v) => _update(v == null
                ? _preferences.copyWith(clearPreviewQuality: true)
                : _preferences.copyWith(previewQuality: v)),
          ),
        ),
        SectionHeader(title: T.downloadQuality),
        ListTile(
          subtitle: Text(T.serverQualitySub,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
          trailing: _qualitySelector(
            value: _preferences.downloadQuality,
            onChanged: (v) => _update(v == null
                ? _preferences.copyWith(clearDownloadQuality: true)
                : _preferences.copyWith(downloadQuality: v)),
          ),
        ),
        SectionHeader(title: T.defaultSort),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(T.defaultSortSub,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, children: [
            _sortChip(T.sortFollowSearch, null),
            _sortChip(T.sortScore, 'score'),
            _sortChip(T.sortDate, 'date'),
            _sortChip(T.sortRating, 'rating'),
          ]),
        ),
        const SizedBox(height: 8),
        SectionHeader(title: T.downloadSubdir),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(T.downloadSubdirSub,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _subdirController,
            decoration: InputDecoration(
              hintText: T.downloadSubdirHint,
              errorText: _subdirValid ? null : T.invalidSubdir,
            ),
            onSubmitted: (_) => _commitSubdir(),
            onEditingComplete: _commitSubdir,
            onTapOutside: (_) => _commitSubdir(),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  /// 画质三选一：跟随全局 / 原图 / 预览。
  ///
  /// 预览与下载共用它：两处各写一遍 SegmentedButton 的话，改一处忘一处，
  /// 用户会看到两个「画质」设置长得不一样。
  Widget _sortChip(String label, String? value) {
    return ChoiceChip(
      label: Text(label),
      selected: _preferences.defaultSort == value,
      onSelected: (_) => _update(value == null
          ? _preferences.copyWith(clearDefaultSort: true)
          : _preferences.copyWith(defaultSort: value)),
    );
  }

  Widget _qualitySelector({
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
            value: 'global',
            label: Text(T.ratingFollowGlobal,
                style: const TextStyle(fontSize: 11))),
        ButtonSegment(
            value: 'original',
            label: Text(T.qualityOriginal,
                style: const TextStyle(fontSize: 11))),
        ButtonSegment(
            value: 'sample',
            label: Text(T.qualitySample,
                style: const TextStyle(fontSize: 11))),
      ],
      selected: {value ?? 'global'},
      onSelectionChanged: (v) =>
          onChanged(v.first == 'global' ? null : v.first),
    );
  }

  Widget _chip(String label, String? value, String? current) {
    return ChoiceChip(
      label: Text(label),
      selected: current == value,
      onSelected: (_) => _update(value == null
          ? _preferences.copyWith(clearVisibleRating: true)
          : _preferences.copyWith(visibleRating: value)),
    );
  }
}
