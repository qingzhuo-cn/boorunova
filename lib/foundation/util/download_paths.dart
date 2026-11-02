// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 解析下载目录：优先用户设置的 [downloadPath]，不可用则回退到默认目录。
///
/// 回退目标必须是**持久**目录：此前回退到 `getTemporaryDirectory()`，那是系统
/// 随时可以回收的缓存目录，「清理缓存」也会把它整个删掉——而下载记录里的
/// localPath 还指着它，文件会凭空消失且用户什么都没做。
Future<Directory> resolveDownloadDir(
  String downloadPath, {
  String subdir = '',
}) async {
  final safeSubdir = sanitizeSubdirName(subdir);
  if (downloadPath.isNotEmpty) {
    // 只判断「存在」是不够的：Android scoped storage 下
    // `/storage/emulated/0/Download` 这类公共目录能被选中、也能 exists()，
    // 但直接落文件会被拒绝。此前这里把它当可用目录返回，于是每次下载都
    // 在写盘时才失败，且没有任何回退。改为真正写一次探针。
    if (await isWritableDirectory(downloadPath)) {
      return _withSubdir(Directory(downloadPath), safeSubdir);
    }
    // 不可写（权限/只读/scoped storage）时回退默认目录，避免下载直接失败。
    // 注意回退到的是持久目录，不是缓存目录。
  }
  return _withSubdir(await defaultDownloadDir(), safeSubdir);
}

/// 在基目录下取（必要时创建）站点子目录。
///
/// 子目录建不出来（权限/只读/名字非法）时**退回基目录**：站点偏好是一个
/// 可选的整理手段，不该因为它在写入前就把这一张图判失败。
Future<Directory> _withSubdir(Directory base, String subdir) async {
  if (subdir.isEmpty) return base;
  final dir = Directory('${base.path}${Platform.pathSeparator}$subdir');
  if (await isWritableDirectory(dir.path)) return dir;
  return base;
}

/// 站点下载子目录的消毒规则（全项目唯一口径）。
///
/// 只允许**一层相对目录名**：绝对路径与 `..` 会让下载写到应用目录之外
/// （scoped storage 上要么失败，要么是最不该有的越权）。非法输入一律退化成
/// 空串（= 用基目录），而不是抛错或保留危险路径。
String sanitizeSubdirName(String raw) {
  var value = raw.trim().replaceAll('\\', '/');
  while (value.startsWith('/')) {
    value = value.substring(1);
  }
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  if (value.isEmpty) return '';
  value = value.split('/').first;
  if (value == '.' || value == '..') return '';
  value = value.replaceAll(RegExp(r'[^A-Za-z0-9._\-\u4e00-\u9fa5]'), '_');
  if (value.isEmpty || value.replaceAll('.', '').isEmpty) return '';
  return value.length > 40 ? value.substring(0, 40) : value;
}

/// 目录可写探针：真写一个临时文件再删掉，成功才返回 true。
///
/// 存在的理由见 [resolveDownloadDir]：`exists()` 区分不了「能看见」与
/// 「能写入」，而 scoped storage 下这两者经常不是一回事。选择下载目录时
/// 同样用它，把不可写的目录挡在保存之前，而不是等下载时才失败。
Future<bool> isWritableDirectory(String path) async {
  if (path.isEmpty) return false;
  // 探针结果按路径缓存在进程内：下载每一张图都会走一次
  // [resolveDownloadDir]，每次都真建再删一个临时文件等于给批量下载多加
  // 两次文件操作/张。目录中途变得不可写时，写盘失败仍会被上层报出来。
  // 只缓存**成功**结果：失败可能是权限还没给或外置卡没挂上，用户处理后
  // 再选一次应当立刻能用，不能因为一次否定就永久拒绝。
  if (_writableCache[path] ?? false) return true;
  final ok = await _probeWritableDirectory(path);
  if (ok) _writableCache[path] = true;
  return ok;
}

final Map<String, bool> _writableCache = <String, bool>{};

Future<bool> _probeWritableDirectory(String path) async {
  try {
    final dir = Directory(path);
    // 配置期一次性检查，非热路径。
    // ignore: avoid_slow_async_io
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final probe = File(
      '${dir.path}${Platform.pathSeparator}'
      '.boorunova_write_probe_${DateTime.now().microsecondsSinceEpoch}',
    );
    await probe.writeAsString('', flush: true);
    await probe.delete();
    return true;
  } catch (_) {
    return false;
  }
}

/// 默认下载目录：app 专属外部目录（`/Android/data/<pkg>/files/…`）。
///
/// 不需要任何存储权限，也不会被系统当缓存回收。取不到时逐级回退到应用文档
/// 目录，最后才是临时目录（极端情况下至少不崩）。
Future<Directory> defaultDownloadDir() async {
  final providers = <Future<Directory?> Function()>[
    getExternalStorageDirectory,
    getApplicationDocumentsDirectory,
  ];
  for (final provider in providers) {
    try {
      final dir = await provider();
      if (dir == null) continue;
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      continue;
    }
  }
  return getTemporaryDirectory();
}

/// URL 的扩展名（含点，已剥掉 query / fragment）。没有扩展名时返回 `''`。
///
/// 全项目**唯一**的扩展名口径：守卫和文件名生成必须用同一个函数，否则会
/// 出现「守卫认为有扩展名 → 放行 → 文件名却没扩展名 → Gal 抛
/// FileNotFoundException → 用户看到"下载失败"，而文件其实已经躺在磁盘上」。
String extensionOf(String url) {
  final raw = url.split('?').first.split('#').first;
  // 取**最后一个非空**路径段：视频站的媒体地址常以斜杠收尾
  // （实测 `…/…_720p.mp4/?v-acctoken=…`），只看最后一段会得到空串，
  // 于是守卫判定"没有扩展名"直接拒绝下载，而其实地址里明明有 .mp4。
  final segments = raw.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return '';
  final base = segments.last;
  final dot = base.lastIndexOf('.');
  // 必须要求点后还有字符：`https://h/..` 的最后一段是 `..`，lastIndexOf
  // 落在末尾，旧写法会返回 `.`，随后拼出 `..` 这种目录名，写盘失败且
  // 失败点离原因很远（守卫以为「有扩展名」就放行了）。返回空串让调用方
  // 的扩展名守卫直接拒绝。
  return dot > 0 && dot < base.length - 1 ? base.substring(dot) : '';
}

/// 视频扩展名集合。Gal 按媒体类型写入不同的相册集合，把 mp4 交给图片 API
/// 会在相册里留下一条无法播放的「图片」，甚至被 MediaStore 拒绝。
const Set<String> videoExtensions = {'.mp4', '.webm', '.mov', '.mkv', '.m4v'};

/// 流清单扩展名（HLS / DASH）。
///
/// 它们**不是文件**而是一份播放列表：直接当文件下载只会得到一个几十字节的
/// 文本，写进相册也没法播。视频站常只提供这种地址，所以必须显式识别并拒绝
/// 下载（播放不受影响，播放器原生支持 HLS）。
const Set<String> streamExtensions = {'.m3u8', '.mpd'};

bool isVideoFile(String url) =>
    videoExtensions.contains(extensionOf(url).toLowerCase());

bool isStreamManifest(String url) =>
    streamExtensions.contains(extensionOf(url).toLowerCase());

/// 生成唯一且保留扩展名的文件名，以 [postId] 为前缀，避免同名文件互相覆盖。
///
/// URL 可能带查询参数（如 `photo.jpg?v=123`），文件名主体和扩展名都必须
/// 清洗为 Windows/Android 合法字符，否则 `?`、`=` 等会让写盘失败。
/// 主体长度受限，避免超长 URL 拼出超 MAX_PATH 的路径导致写盘失败。
String uniqueFileName(
  String url, {
  String? postId,
  String? namespace,
}) {
  // 只取路径最后一段，剥掉 query / fragment。
  // 用**最后一个非空**段，与 extensionOf 同一口径：媒体地址尾随斜杠
  // （`…_720p.mp4/`）时若只看最后一段，会得到空主体 → 文件名叫 `.mp4`。
  final raw = url.split('?').first.split('#').first;
  final segments = raw.split('/').where((s) => s.isNotEmpty).toList();
  final base = segments.isEmpty ? '' : segments.last;
  final ext = extensionOf(url);
  final stem = ext.isEmpty || !base.endsWith(ext)
      ? base
      : base.substring(0, base.length - ext.length);
  final safeStem =
      stem.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_').replaceAll('..', '.');
  // 扩展名同样过白名单：保留字母数字点（如 .jpg .png），其余替换为下划线
  final safeExt = ext.replaceAll(RegExp(r'[^A-Za-z0-9.]'), '_');
  // 主体截断到 60 字符，避免超长路径；扩展名保留（.jpg 等本身不长）
  final trunk = safeStem.length > 60 ? safeStem.substring(0, 60) : safeStem;
  // 主体消毒后若为空或只剩点（如 `https://h/..` 的最后一段），返回空串
  // 明确拒绝：拼出 `.`/`..` 会被写盘当成目录路径。正常地址走不到这里——
  // extensionOf 对纯点段已返回空串，调用方的扩展名守卫会先行拒绝。
  if (trunk.isEmpty || trunk.replaceAll('.', '').isEmpty) return '';
  final safeNamespace = namespace == null || namespace.isEmpty
      ? ''
      : '${namespace.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}_';
  final safeId = postId == null || postId.isEmpty
      ? ''
      : '${postId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}_';
  return '$safeNamespace$safeId$trunk$safeExt';
}
