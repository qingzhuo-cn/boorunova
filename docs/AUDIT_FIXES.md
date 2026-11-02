# BooruNova 审查问题修复方案

> 依据 2026-10-10 全量审查（5 个分区审查 + 发布链实测）整理，覆盖全部发现：
> 高危 6、中危 30、低危 60+、测试缺口 8 组、发布链 4、文档 8 处。
> 所有行号对应审查时的代码状态；代码片段为示意骨架，落地时按上下文微调。

---

## 0. 修复排期总览

| 批次 | 内容 | 条目 |
|---|---|---|
| **A：发版前**（建议随 v1.8.7+29 一起发） | 核心功能在特定平台/站点上整体失效、内容安全口径、发布链纪律 | H1 H2 H3 H4 R1 R2 R3 |
| **B：下个迭代**（1.8.7 或 1.8.8） | 高频路径的可见缺陷与数据安全 | H5 H6 M-UI 系列 |
| **C：择期** | 健壮性打磨、低危、测试补齐、文档 | 其余 |

---

## 1. 高危修复（H1–H6）

### H1 Android 8/9 相册权限缺失 → 下载必然失败

- **位置**：`lib/foundation/util/image_downloader.dart:71-75`（`Gal.putImage` 调用点）
- **根因**：gal 2.3.3 在 SDK ≤ 28 上要求**运行时已授予**的 `WRITE_EXTERNAL_STORAGE`（`GalPlugin.java` 的 `hasAccess()`），而 `putImage/putVideo` 不会自动发起请求。全项目从未调用 `Gal.requestAccess()`，minSdk=26 → Android 8.0/8.1/9 上每次下载都 ACCESS_DENIED，且用户见不到授权弹窗。Android 10（API 29，legacy 存储）大概率同样受影响，需真机验证。
- **修复**：在 `downloadImage` 最前面（批量入口 `BatchOps.downloadAll` 同理，只做一次）：

```dart
/// 进程内缓存，避免每次下载都触发系统弹窗检查
static bool? _galAccessGranted;

Future<bool> _ensureGalleryAccess() async {
  final cached = _galAccessGranted;
  if (cached != null) return cached;
  try {
    final ok = await Gal.hasAccess() || await Gal.requestAccess();
    _galAccessGranted = ok;
    return ok;
  } catch (_) {
    return false; // 平台异常按无权限处理，给出可读错误
  }
}
```

被拒绝时返回 `DownloadResult(success: false, error: 'gallery_permission_denied')`，UI 层把该哨兵映射为本地化文案（照 `kNoServerSelected` 的模式），并引导去系统设置。
- **验证**：Android 8/9 真机或模拟器（API 26/28 镜像）首次下载弹权限、授权后成功、拒绝后报可读错误。

### H2 box 损坏恢复把健康的 box 一并关闭且永不重开

- **位置**：`lib/foundation/database/hive_setup.dart:39-48`
- **根因**：`Hive.close()` 会关闭**所有**已注册 box，但 catch 分支只重开损坏的那一个。`_openBoxes` 先开 servers 再开 settings：settings 损坏时 servers 被连带关闭且不再重开，此后每次 `HiveSetup.serversBox` 都抛 `Box not found`，且 `init()` 不抛错 → 降级页也不出现，用户面对的是"服务器列表整个会话全坏"。
- **修复**：catch 中**删除 `Hive.close()`**（hive 在 openBox 失败时已自行清理半开实例）：

```dart
static Future<void> _openBox(String name) async {
  try {
    await Hive.openBox(name, crashRecovery: true);
    return;
  } catch (_) {
    // 注意：这里不能 Hive.close()——它会关掉另一个已成功打开的 box。
    if (Hive.isBoxOpen(name)) {
      try { await Hive.box(name).close(); } catch (_) {}
    }
    _quarantine(name);
    recoveredFromCorruption = true;
    await Hive.openBox(name);
  }
}
```

- **验证**：单测——向 settings box 写入垃圾字节后 init，断言 `serversBox` 仍可读写、`recoveredFromCorruption == true`。

### H3 danbooru/e621 2024 四档评级迁移未处理（内容安全口径）

- **位置**：
  - 解析侧：`lib/boorus/danbooru/parser/danbooru_parser.dart:38`、`lib/boorus/e621/parser/e621_parser.dart:43`
  - 查询侧：`lib/boorus/danbooru/danbooru_repository.dart:14-23`、`lib/boorus/e621/e621_repository.dart:15-21`
- **根因**：两站 2024 年起评级为四档 `g/s/q/e`（general/sensitive/questionable/explicit）。`'s'` 的语义已从 safe 变成 **sensitive（擦边）**。现状：sensitive 帖被 `normalizeRating` 归入 UI 的 `'s'`（安全）→ 绿徽章、通过 `isSafeRating` 侧栏头图安全口径；而真正安全的 `'g'` 反而落到"未知"灰徽章。查询侧用户选"安全"发出 `rating:s`（danbooru）/`rating:safe`（e621）→ 在现行站点上拉到的是 sensitive 内容或 0 结果。
- **修复**（保持现有三档 UI 不动的最小改法）：

```dart
// 解析侧（danbooru_parser / e621_parser）：
// 四档世界的 s=sensitive 并入 UI 三档的 q（可疑）；g=general 才是 s（安全）。
final rawRating = post['rating'] as String?;
final triState =
    (rawRating == 's' || rawRating == 'sensitive') ? 'q' : rawRating;
final rating = normalizeRating(triState);
```

```dart
// 查询侧（danbooru_repository / e621_repository 的评级映射）：
switch (query.rating!) {
  's' => 'rating:g',  // 安全 = general（四档世界的真安全档）
  'q' => 'rating:q',
  'e' => 'rating:e',
  _ => 'rating:${query.rating}',
}
```

`normalizeRating` 本体（base_booru_repository.dart:90-106）把 `g/general` 已映射到 `'s'`，无需再动。
- **验证**：因本开发环境对相关域名有 DNS 污染，必须真机核验：danbooru 搜 `rating:g` 与 `rating:s` 各取一条，确认 g 档显示绿徽章、s 档显示可疑徽章；e621 同理。为 parser 补四档 fixture 用例（g/s/q/e 各一条断言归一结果）。

### H4 瀑布流瓦片无 key + gaplessPlayback → 元素复用显示旧图

- **位置**：`lib/presentation/widgets/timeline/timeline.dart:54-75`（无 key）、`:206`（`gaplessPlayback: true`）
- **根因**：Sliver 按 index 复用元素；黑名单增删导致 `filteredPosts` 位移而列表长度不变时，同一 index 换绑到另一个帖子，`gaplessPlayback` 继续显示上一个帖子的已解码帧直到新图加载完成——用户看到 A 的缩略图、点进去是 B。
- **修复**（推荐挂 key，让元素身份跟内容走）：

```dart
return _AnimatedTile(
  key: ValueKey(postKeyOf(posts[index])), // 身份跟内容，杜绝同位置换帖复用旧帧
  index: index,
  child: _PostTile(...),
);
```

副作用提示：换 key 会让被过滤位置的瓦片重新走入场动画（`reduceAnimations` 仍会被尊重），可接受。备选方案是去掉 `gaplessPlayback`（它本是为"同一 URL 换分辨率"设计的），但闪白感更明显。
- **验证**：在黑名单页增删一个能命中当前可见列表的标签，返回首页观察可见瓦片不再串图；`flutter run` profile 模式确认无明显滚动劣化。

### H5 模板"已添加"按引擎 type 判定 → 同引擎镜像站无法添加、编辑错对象

- **位置**：`lib/presentation/screens/server/server_page.dart:94-109`
- **根因**：`servers.any((s) => s.type == t.type)` + `firstWhere((s) => s.type == t.type)`。gelbooruV2 家族有 5 个模板、moebooru 有 2 个：添加 Gelbooru 后其余镜像站全部显示"已添加"，点击只会编辑 Gelbooru。
- **修复**：改按**规范化 baseUrl** 判定，并把"已添加"从独占编辑改成双入口：

```dart
String _normUrl(String url) {
  var s = url.trim().toLowerCase();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

final added =
    servers.any((s) => _normUrl(s.baseUrl) == _normUrl(t.baseUrl));
// 「已添加」时：主按钮仍允许「再添加一个」（走新增流程），
// 次按钮「编辑现有」按 baseUrl 精确 firstWhere（找不到时回退不显示）。
```

- **验证**：添加 gelbooru.com 后，Xbooru/Realbooru/TBIB/Rule34.us 模板仍可各自添加；点击"编辑现有"打开的是对应 URL 的那个站点。

### H6 备份功能缺陷群（可达性 / 完整性 / 容错 / 语义）

- **位置**：`lib/presentation/screens/settings/data_backup_page.dart`
- **四个子问题与修复**：

**(a) 导出位置用户不可达**——`getApplicationDocumentsDirectory()` 在 Android 是 `/data/user/0/<pkg>/app_flutter`，需 ADB 才能取出。项目已有 `share_plus` 依赖，导出改走系统分享面板：

```dart
final dir = await getTemporaryDirectory();
final file = File('${dir.path}/boorunova_backup_'
    '${DateTime.now().millisecondsSinceEpoch}.json');
await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
await Share.shareXFiles([XFile(file.path)], subject: 'BooruNova backup');
// SnackBar 改提示「已调起分享」，删除旧的「已导出到 <私有路径>」文案
```

**(b) 备份内容不完整**——缺浏览历史（`user_history_repo.dart:193` 的 `replaceAll` 注释写明"备份导入用"却是死代码）与 hosts 映射。导出 map 补两段：

```dart
'history': ref.read(userHistoryRepoProvider).getAll()
    .map((h) => h.toJson()).toList(),
'hosts': ref.read(userHostsRepoProvider).getAll()
    .map((h) => h.toJson()).toList(),
```

导入侧对应：`history` → `userHistoryRepo.replaceAll`（合并去重按 `serverId|postId`，时间新者优先）；`hosts` → `userHostsRepo.replaceAll`（按 domain 去重合并）。同步更新备份页的条目统计 UI 与 README 措辞。

**(c) 导入无逐段容错、无确认**——目前只有 servers 段逐条 try/catch，favorites/blockedTags/downloads 一条坏记录就中断整段，被外层 catch 兜住只弹"导入失败"，已写入部分无提示。修复模式：

```dart
// 每段独立统计并捕获，单条损坏跳过而不是中断
var ok = 0, skipped = 0;
for (final item in list) {
  try {
    final post = BooruPost.fromJson(Map<String, dynamic>.from(item as Map));
    ...;
    ok++;
  } catch (_) {
    skipped++; // 记数继续
  }
}
// 结果 SnackBar 分段汇报：'服务器 5/6，收藏 40/40，跳过 1 条…'
```

导入前弹确认对话框，明确说明会**合并**收藏/下载/服务器、**覆盖**设置与搜索历史。同时给 `post.dart` 的 `_tagList` 加宽容口径（见 L-数据-3），坏元素不再抛 TypeError。

**(d) 语义与去重口径**——搜索历史 `replaceAll` 是替换语义（导入旧备份静默清空当前记录），改为合并（去重后按 viewedAt/newest 排序、保留 20 上限）；下载去重 `d.postId == entry.postId` 改为：

```dart
if (!all.any((d) =>
    d.postId == entry.postId && d.serverId == entry.serverId)) {
  all.add(entry);
}
```

- **验证**：新增 `test/backup_test.dart`：导出内容包含全部七段；导入含坏记录的备份逐段统计正确；重复导入两次收藏不翻倍；搜索历史合并不丢现有条目。

---

## 2. 中危修复（按模块）

### 2.1 引擎层

| # | 位置 | 方案 |
|---|---|---|
| M1 | `zerochan_parser.dart:16,24` 取 `file`/`author`，与 `zerochan_repository.dart:36-38` 实测注释矛盾（响应只有 id/width/height/md5/thumbnail/source/tag/tags） | 真机抓包确认。若确无 `file`：original/sample 恒空 → 点开/下载只有缩略图质量。实现 `resolveMediaUrl`（详情页解析大图），或退而求其次拼 zerochan 的大图 URL 变体；对齐 fixture |
| M2 | `rule34_repository.dart:44-60` tag 建议端点（`s=tag&json=1`）形态从未验证；非 JSON-List 响应被 `if (data is! List) return []` 静默吞掉 | 真机验证。若回 XML：复用 `GelbooruV2Parser.parseSuggestions`；若切 `autocomplete.php`：解析裸字符串数组。给静默失败加 `debugPrint`。safebooru 同款处理 |
| M3 | `registry.dart:135,156` rule34 探测路径带 `json=1` 却用特征 `'<post'`（XML）校验 → 该引擎按类型探测必然失败（目前靠 scanner 域名捷径兜底） | 二选一：探测路径去掉 `json=1`（自然命中 `<post`），或特征改 `'"preview_url"'`。顺带：`scanner()` 的 `contains` 子串判域名改为按 host 精确/后缀匹配（防 `zerochan.net.evil.com` 误判）；danbooru/moebooru/sankaku 的 `'"id"'` 特征过弱，换更特异的键名 |
| M4 | `sankaku.dart:24-27` 自定义 UA `BooruNova/1.0` 直连 Cloudflare 保护站点 → 大概率 403 | 对齐 KVS 的做法（`kvs.dart:34-36` 已有先例）：浏览器 UA；真机确认 `/post/index.json` 端点仍可用 |
| M5 | 6 个 JSON 解析器硬转型（danbooru/e621/moebooru/sankaku/rule34/zerochan 的 `as int?`/`as String?`）→ 单条 `score: 3.5` 或字符串数字即让整页搜索报错 | 抽共享宽容工具（参照 `shimmie2_parser.dart:227-231` 的 `_int`/`_asMap`）：`int? _asInt(Object? v) => v is int ? v : v is num ? v.toInt() : int.tryParse('$v');`。每条帖子 try/catch 丢条保页 |
| M6 | `zerochan_parser.dart:26` rating 硬编码 `const rating = 's'` → ecchi 内容全标"安全"并过头图安全口径 | 改 `'q'`，与 shimmie2"无法判定按可疑"口径一致 |

### 2.2 数据与基础层

| # | 位置 | 方案 |
|---|---|---|
| M7 | `download_paths.dart:16` 自定义下载目录"存在即通过"，scoped storage 下选公共目录（/storage/emulated/0/Download）写失败且无回退 | 选中目录时做**写探针**（创建并删除临时文件）；不可写在设置页直接拒绝并说明。下载失败时识别权限类异常并提示"已回退默认目录" |
| M8 | `json_store.dart:67` `decoded['_v'] as num?` 硬 cast，违背本文件"读取永不抛"目标 | `final v = decoded['_v']; final version = v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 1 : 1);` |
| M9 | `user_hosts_repo.dart:18` `get(_key) as String?` 绕过 `asStringOrNull`（json_safe 注释点名要防的模式）→ 值非 String 时 hosts 启用则所有网络请求失败 | 改 `asStringOrNull(_box.get(_key))` |
| M10 | `dio_factory.dart:36-43,46-53` `createProbe`/`createDownload` 不带 UA → e621/sankaku CDN 403 风险、探测误判 | 工厂默认注入 `User-Agent: BooruNova/<version>`（版本号从 `appVersionProvider` 或 `package_info_plus` 取，可静态缓存）；保留 headers 参数供引擎覆盖 |
| M11 | `batch_ops.dart:19` CancelToken 全链路打通但调用点（home_content 批量下载）不传；`createDownload` 无 stall 保护 | 调用点持有 `CancelToken`，页面 dispose / 点停止时 `cancel()`；给下载加宽松 stall 检测（如 60s 无接收进度即失败取消） |
| M12 | `image_downloader.dart:71-94` 下载管线一致性：Gal 成功但 `repo.add` 抛错报"失败"；同帖重复下载 MediaStore 重复条目；`repo.clear()` 只删记录留孤儿文件 | (a) 记录失败提示"已存入相册但记录失败"；(b) 下载前按 `serverId|postId` 查记录/查路径，已存在时跳过或明示"再次保存"；(c) clear/remove 提供可选文件清理并在 UI 明示"文件保留在相册" |

### 2.3 表示层核心

| # | 位置 | 方案 |
|---|---|---|
| M13 | `app_theme.dart:12-14` + `booru_nova.dart:61` 主题双状态源（备份恢复的主题需重启才生效） | 删掉 `appThemeModeProvider`：MaterialApp 改 `ref.watch(settingsProvider.select((s) => s.themeMode))`；`appearance_page.dart:61-62` 的双写一并收掉 |
| M14 | `batch_selection.dart` 切站不清空选择 → B 站显示 A 站的"已选 N" | 在 `switchServer` 流程或 `ref.listen(serverId)` 时 `clear()` |
| M15 | `tag_suggestions.dart:7,26-31` 全局静态 `_cache` 无界、key 不含 limit、凭据变更不失效 | 加条目上限（如 200，LRU 淘汰）；key 并入 limit；该设置变化/凭据保存时清缓存 |
| M16 | `timeline.dart:196-197` + 各 parser `aspectRatio` 只挡 height 不挡 width → 坏数据 aspectRatio=0 挂整页 | Timeline 侧兜底（覆盖所有引擎）：`final ar = post.aspectRatio > 0 && post.aspectRatio.isFinite ? post.aspectRatio : 1.0;` |
| M17 | `video_viewer.dart:41-45` + `resolved_video.dart:33-42` 缺 `didUpdateWidget`（url/headers/post 变化被忽略） | 实现 `didUpdateWidget`：url/post 变了 → dispose 旧 controller 重走 `_init`；headers 变了重建 |
| M18 | `video_viewer.dart:69-71,333-335,458-463` 播放期每 tick 重建整棵控制树 + 每次 build 新建 `ImageFilter.blur` | 进度/时间改 `AnimatedBuilder` 局部订阅；blur 滤镜提 `static final`（照 `glass.dart:9` 的 `glassBlurFilter`）；监听节流到秒粒度 |
| M19 | `video_viewer.dart`（全文件）无 AppLifecycleState 处理 → 退后台继续播 + 出声 | `WidgetsBindingObserver`：`inactive/paused` 时 `pause()`，回到 resumed 且此前在播则恢复 |
| M20 | `page_state.dart:171-182` + `home_content.dart:61-72` 翻页退化循环：去重后 appended 为空仍前进页码且维持 hasMore → 坏引擎无限爬页 | `if (result.posts.isNotEmpty && appended.isEmpty) → hasMore: false`（连续空页熔断） |
| M21 | `booru_nova.dart:60-76` 整量 watch settings → 任何字段变化重建 3 份 ThemeData | `select((s) => s.accentColor)` / `select((s) => s.language)` / `select((s) => s.themeMode)` 分开订阅；`ColorScheme.fromSeed` 结果按参数缓存 |

### 2.4 页面层

| # | 位置 | 方案 |
|---|---|---|
| M22 | `search_settings_page.dart:12` `tagSuggestionLimitProvider` 纯内存（全应用唯一不持久化设置） | 并入 `AppSettings`：加字段 `tagSuggestionLimit = 12`，fromJson 加 `json['tagSuggestionLimit'] as int? ?? 12`，copyWith/toJson/setter 照 gridColumns 模式补齐 |
| M23 | `home_content.dart:91-99,170-177` 黑名单屏蔽整页时卡死"没有找到帖子" | 空态且 `hasMore` 时自动 loadMore；EmptyState 加"继续加载"按钮；文案区分"结果均被黑名单屏蔽" |
| M24 | `server_editor_page.dart:151-159` + `server_probe_page.dart:41-43` URL 只查非空（无 scheme 照存、无查重、http 无提示） | validator 里 `Uri.tryParse` + 强制 http/https（无 scheme 自动补 `https://` 并提示）；保存前按规范化 baseUrl 查重，重复时给"已存在，去编辑？"选项；http 明文给警示文案 |
| M25 | `server_probe_page.dart:71-78,187-194` await 后无 mounted 检查；取消不中断进行中探测；可并发开始 | 所有 `await` 后的 setState 前加 `if (!mounted) return;`；取消标志对命中结果同样生效；再开始前检查 `_scanning` |
| M26 | **i18n 硬编码中文**（19 文件；黑名单页/探索/图集/搜索选项/关于页整页中文，`T.noServerSelected`/`T.retry` 已存在却没用） | 统一收口到 `T`：blacklist/explore/pools/search 排序分级选项/about/server_editor 对话框/hosts '未保存的更改'/post_detail '已选'/router `_InvalidRoutePage`。新增对应 getter，现有键直接复用 |
| M27 | `explore_page.dart` / `pools_page.dart` / `pool_detail_page.dart` 不监听站点切换、不过黑名单、无分页（图集 `limit:100` 静默截断） | `ref.listen(booruPageStateProvider.select((s) => s.serverId))` 重拉；浏览面复用 home_content 的黑名单过滤谓词；套用 page_state 的 loadMore 模式或本地 seq+page；图集页至少显示"仅前 100 张" |
| M28 | `downloads_page.dart:70-85` 48dp 小格 `Image.network` 无 cacheWidth（原图 URL 全尺寸解码 → OOM 风险；同文件 `_preview` 已修过同类） | `cacheWidth: (48 * MediaQuery.devicePixelRatioOf(context)).round()`，或用本地缩略 |
| M29 | `post_viewer.dart:190-203,348-367` 放大后垂直平移被"下滑关闭"手势劫持 | `_zoomController.value != Matrix4.identity()` 时禁用 dismiss 手势（onVerticalDrag* 置 null），或监听 `onInteractionStart` 动态切换；真机验证 |
| M30 | `data_storage_page.dart:154-176` 清除浏览历史/下载记录无确认（同应用其他清空入口都有） | 复用现有 AlertDialog 确认模式 |

---

## 3. 低危修复速查表

### 3.1 引擎层

| 位置 | 问题 | 一行方案 |
|---|---|---|
| `gelbooru_v2_parser.dart:99-108` | 实体解码 `&` 放最先（`<` → `<` 过度解码）；表仅 6 项 | 先解具名/数字实体、最后解 `&`；补 `'` 与十进制 |
| `gelbooru_v2_parser.dart:33,92` | 帖子正则不跨行、属性只认双引号 → 变体站静默 0 条 | `[\s\S]*?` 与 `["']` 变体；attrs 为空记日志 |
| `moebooru_parser.dart:9` | `http://` 强升 `https://`（http-only 实例图片全挂） | http 原样保留；`//` 按 baseUrl scheme 补 |
| `gelbooru_v2_repository.dart:67-74` 等 | suggestTags/fetchTrendingTags 不带 `authQueryParams` → 需 key 的站点建议静默 401 | tag 查询同样 `...authQueryParams` |
| `moebooru_repository.dart` | 全程无认证（moebooru 只认 login/password_hash，Basic 无效） | 若支持登录：透传 `login`+`password_hash` 查询参数 |
| `rule34_parser.dart:7,45` | postUrl 硬编码 `rule34.xxx` | 仓库传 web 域名进解析器，缺省再回退 |
| `post.dart:51-52` | `List<String>.from(v)` 脏数据抛 TypeError；width `is int` 把 double 归零；`uploader` 是死字段 | `v.whereType<String>().toList()`；`is num` 放宽；决定 uploader 去留（KVS 拿它存时长，先改名或废弃） |
| 各 repository | hasMore 三套口径并存，"满员"依赖未声明的"limit ≤ 站点单页上限"约定 | 每引擎声明单页上限常量并 clamp 请求 limit |

### 3.2 数据与基础层

| 位置 | 问题 | 一行方案 |
|---|---|---|
| `hive_setup.dart:12-14` | `recoveredFromCorruption` 无 UI 消费 | 启动后检查标志，一次性弹"部分本地数据已损坏并隔离"提示 |
| `hive_setup.dart:51-61` | `_quarantine` 只改名 `.hive`（`.hivec` 残留会复活坏数据）；rename 失败无日志 | 连 `.hivec` 一起隔离；失败记 `debugPrint` |
| `json_store.dart:132-141` | 注释称同步写，实际 put/delete 未 await，失败成未处理异步异常 | 挪进 `_enqueue` 队列 await 并捕获记录 |
| `user_history_repo.dart:155` | `getAll()` 返回内部缓存可变引用（favorites 是 unmodifiable） | `List.unmodifiable` 包一层 |
| `download_paths.dart:56-66` | `extensionOf('https://h/..')` 返回 `.`，拼出 `..` 文件名 | 要求 `dot < base.length - 1`；stem 为空/纯点直接拒绝 |
| `hosts_page.dart` + `user_hosts_repo.dart` | hosts 输入零校验（任意串当 IP；`com` 级条目劫持所有 *.com） | 保存时 `InternetAddress.tryParse` 校验 IP；domain 正则 + 拒绝单标签 |
| `user_server_repo.dart:56-69` | reorder 以 order 数组为下标基准，与展示列表（含未入 order 的尾部项）错位 | reorder 前用 getAll 的完整 id 序列重建 order 再移动 |

### 3.3 表示层核心

| 位置 | 问题 | 一行方案 |
|---|---|---|
| `router.dart:299-307` | `_InvalidRoutePage` 三条硬编码中文 | 走 `T` |
| `resolved_video.dart:53,73,107` | 裸英文错误串直出；每次进入重抓详情页无缓存 | 错误串走 T；按 postKey 缓存 resolveMediaUrl 结果 |
| `video_viewer.dart:48-53` | `Uri.parse` 在 try 外 → 坏 URL 未捕获异常 + 永久转圈 | 挪进 try |
| `video_viewer.dart:448,515-524` | 全屏控制层永不自动隐藏；播放/暂停逻辑复制一份 | 复用 inline 的 Timer 逻辑；抽公共控制组件 |
| `download_progress.dart:62-81` | `start()` 只按 URL：同 URL 并发互相清零；update 未知 URL 静默丢 | 键含 postId；downloading 状态下的重复 start 忽略或聚合 |
| `tags_blocker_state.dart:20-33` | push/pushAll/delete 无 try/catch，Hive 写失败 UI 无感 | 捕获并给失败提示 |
| `trending_tags.dart:5-7` | 一次性 read 不 watch serverId（脆弱耦合） | `watch(select((s) => s.serverId))` |
| `server_favicon.dart:25,46-49` | `_failed` 失败集合进程级永久（一次抖动整会话不重试） | 加 5 分钟 TTL |
| `timeline.dart:96-108` | 滚回重播入场动画；reduceAnimations 只在 initState 读一次 | 动画按可见一次性播放；设置变化用 ref.listen |
| `timeline.dart:201-206` | 缩略图无 timeLimit → 挂起连接永久 shimmer | `timeLimit: 8s`（对齐 site_artwork）+ 有限重试 |
| `timeline.dart:352-355` | 评分缩写 `1.2w` 英文用户不可读 | 经 T 分语言（k/M） |
| `app_strings.dart:253,292` | countUnit 英文回退空串 → "12 " 悬空 | 英文侧给 ''→ 不渲染该单位或用 `items` |
| `booru_nova.dart:58,70` | 启动降级页永远中文（早退早于 T.setLocale） | 按 `platformDispatcher.locale` 现场判断 |
| `booru_nova.dart:73-76` | system 暗色用 midnight、显式 dark 用普通暗色，观感不一致 | 确认是否有意；是则设置页文案说明，否则统一 |
| `onboarding_state.dart:44-46` | `preset()` 持有调用方 Set 引用 | `Set.of()` 拷贝 |
| `site_artwork.dart:21-22` | `ref.keepAlive()` 在 await 后调用 | 先拿 `final link = ref.keepAlive()`，空结果 `link.close()` |
| `video_viewer.dart:50` | 默认 UA 与图片管线不一致 | 与 mediaHeaders/图片侧统一 |

### 3.4 页面层

| 位置 | 问题 | 一行方案 |
|---|---|---|
| `hosts_page.dart:112-114` | 添加映射弹窗两个 TextEditingController 从不 dispose | 独立 StatefulWidget + dispose |
| `hosts_page.dart:57-61` | await 后 setState 无 mounted 检查 | `if (!mounted) return;` |
| `post_viewer.dart:333-337` 等 | `ref.invalidate` 排在 mounted 检查前（同型 3 处） | invalidate 移到 mounted 后（范本：downloads_page.dart:198-206） |
| `post_detail_page.dart:73-79` | 详情页"打开完整查看器"用单帖重开，丢画廊位置 | 路由 extra 带原 posts+index，或改为 pop 回查看器 |
| `post_viewer.dart:441-449` | 进度图标取同步 URL，视频帖与实际下载 URL 不匹配 → 恒为不确定态 | _download 解析后缓存 URL 供图标查询 |
| `favorites_page.dart:63-87` | 收藏只有弹层无查看器入口；无 Semantics 标签 | 弹层加"查看大图/下载"；GestureDetector 包 Semantics |
| `privacy_page.dart:59-88` | clear 后不 invalidate → 栈内页面陈旧 | 补 invalidate |
| `search_history_page.dart:23-26` | 清空全部无确认 | 补确认对话框 |
| `pools_page.dart:52` / `pool_detail_page.dart:62` | 裸 `e.toString()` 直出 | 走 `T.friendlyError` |
| `search_page.dart:84-93,133` | 清除按钮/底部文案依赖 300ms debounce，反馈滞后 | onChanged 里立即局部 setState |
| `home_page.dart:44-46,63-65` | 带搜索词时删活动服务器：不选新站、残留已删站数据、loadMore 打已删站 | active 被删时无条件切到 `target ?? servers.first` |
| `server_editor_page.dart:118-127` | pop 后 400ms 延迟 invalidate 的 hack | 改 route 观察/pop 结果回调 |
| `server_editor_page.dart:171-188` | 遗留 planned 引擎服务器 Dropdown value 不在 items（debug 断言/release 空白） | items 覆盖全部 `BooruType.values`，未实现的标"未实现"禁用 |
| `search_history_page.dart:52-55` | 从历史重跑搜索不带 rating | 读 pageState 的 currentRating 一并传入 |
| `post_viewer.dart:292-314` | 双击/长按动作读屏不可见 | 手势触发时补 Semantics liveRegion 提示 |

---

## 4. 测试补齐方案（按优先级）

| 缺口 | 方案 |
|---|---|
| **引擎 HTTP/仓库层零测试**（最大空白：评级映射、hasMore、鉴权、参数构造） | 用 `HttpServer.bind` 起本地假站点（`hosts_network_test.dart` 已有现成模式），为 danbooru/gelbooru/e621/moebooru 各补：searchPosts 请求参数断言（含评级映射）、hasMore 数学断言（满页/不满页/过滤一条）、`authQueryParams` 注入 |
| 备份导出/导入 | `backup_test.dart`：导出七段完整性；导入坏记录逐段统计；重复导入幂等；版本过新拒绝 |
| 下载失败/取消路径 | 本地 HttpServer + 注入 dio：中断/取消/无扩展名/流清单拒绝/stall；先决定"半截文件是否清理"再断言 |
| 黑名单仓库与时间线过滤 | 直接为 `BooruTagsBlockerRepo` 补单测（稳定键、老格式升级、去重、serverId 作用域）+ 提纯时间线过滤谓词测试 |
| 服务器探测 | `probe` 抽"状态码+响应体特征→类型"纯函数单测；scanner 的 host 匹配（含 `zerochan.net.evil.com` 反例） |
| Gelbooru `parseCount/parseOffset`（hasMore 唯一依据） | count/offset 出现/缺失/0/畸形四态用例 |
| page_state 去重与竞态 | 第 2 页返回重复帖的追加断言；switchServer 期间迟到响应被丢弃的时序用例 |
| KVS 夹持终止判定 | 仓库级假 dio：clamp 触发/不触发两分支 |
| Hive 损坏恢复（H2 的守卫） | path_provider 测试替身注入临时目录，模拟损坏 `.hive` 文件 |
| 测试质量 | `site_artwork_test.dart:288-326` 删掉逐字重复用例（或改造成 serverId 作用域黑名单用例）；`danbooru_parser_test` 的 `uploader_name` fixture 对照实况 API 处理；`zerochan_parser_test` fixture 与实测字段对齐；`drawer_artwork_test` 改测提纯后的真 `_drawerHeader`；`downloads_regression_test` 的 `containsAll` 改无序全等；魔法字符串 'settings'/'servers' 改用 `HiveSetup` 常量；`test/fixtures/` 补一页再生成说明；`video_and_shimmie_parser_test.dart:191` 格式化 |

---

## 5. 发布链修复（RELEASING.md / CI）

### R1 release.yml workflow_dispatch 会创建名为 "main" 的 Release

`release.yml:174` 的 `gh release create "${GITHUB_REF_NAME}"`：tag 触发时是 tag 名没问题；**手动 dispatch 时是分支名**——会创建名为 `main` 的 Release/tag 且被标 `--latest`。修复：

```yaml
on:
  workflow_dispatch:
    inputs:
      tag:
        description: '要发布/重跑的 tag（如 v1.8.7）'
        required: true
```

```yaml
- name: 上传到 GitHub Release
  env:
    GH_TOKEN: ${{ github.token }}
  run: |
    TAG="${{ inputs.tag || github.ref_name }}"
    if gh release view "$TAG" > /dev/null 2>&1; then
      # 重跑：往已有 Release 补传并覆盖资产
      gh release upload "$TAG" \
        build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
        build/app/outputs/flutter-apk/app-release.apk \
        build/app/outputs/flutter-apk/SHA256SUMS.txt --clobber
    else
      gh release create "$TAG" --title "BooruNova $TAG" --latest --generate-notes \
        build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
        build/app/outputs/flutter-apk/app-release.apk \
        build/app/outputs/flutter-apk/SHA256SUMS.txt
    fi
```

### R2 版本纪律回归文档要求

1.8.3→1.8.6 四次版本号混在功能提交里，违背 RELEASING.md 第 2 节。**下一次发布走回正轨**：

1. 修完 A 批（H1–H4）后，单独提交 `chore(release): bump version to 1.8.7+29`；
2. 在**同一提交**上打 tag `v1.8.7` 并推送，让 release.yml 的 tag 触发链路出包；
3. 不要用 workflow_dispatch 重跑（配合 R1 修复后 dispatch 才可用）。

### R3 口令更换（文档自曝的 TODO）

按 RELEASING.md 第 0 节执行 `keytool -storepasswd`，同步更新 `android/key.properties` 与 CI 四个 Secret。**注意**：CI 里写死了证书指纹断言，换口令不影响指纹，链路安全。

### R4 文档修正

- [RELEASING.md:37](docs/RELEASING.md) 第 2 节示例值 `1.8.2`/`24` 过时 → 改成 `<name>+<code>` 占位符表述，避免再过时；
- README.md:236 / README_cn.md:224 "85 cases" → **146**（或改动态描述"解析器/状态机/存储/widget/网络五层"）；
- README.md:203 / README_cn.md:195 "Engine (8 impl)" → **10 个引擎**；
- docs/app_store_intro.md 站点表补 **Shimmie2/paheal、KVS 视频站** 两行；
- "完整双语"与 "Full backup & restore" 两处宣称：待 M26 / H6 落地后才算成立，落地时同步措辞；
- 命名漂移：`resolvePlaybackUrl` → `resolveMediaUrl`（kvs.dart:11、kvs_parser.dart:69、resolved_video.dart:15、SITES_AND_VIDEO.md:29）；
- 删除本地空目录 `lib/boorus/scanner/`、`lib/boorus/safebooru/parser/`（git 不追踪，仅本地遗留）。

---

## 6. 验收清单（A 批完成后）

- [ ] `flutter analyze --fatal-infos` 无问题
- [ ] `flutter test` 全绿（含新增：hive 损坏恢复、backup、rating 四档 fixture）
- [ ] Android 8/9 真机：首次下载弹权限、拒绝时报可读错误、授权后成功
- [ ] danbooru/e621 真机：`rating:g` 绿徽章、sensitive 显示可疑徽章、"安全"筛选拉到 general 档
- [ ] 黑名单增删返回首页，可见瓦片不串图
- [ ] 模板页：gelbooru 家族 5 个站可各自添加
- [ ] 备份导出走分享面板；导入含坏记录的备份逐段汇报；重复导入幂等
- [ ] `git log` 有独立 `chore(release): bump version to 1.8.7+29` 提交，tag `v1.8.7` 打在同一提交
- [ ] tag 推送后 release.yml 绿：指纹断言、清单断言、SHA256SUMS 齐全
