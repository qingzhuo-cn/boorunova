# BooruNova 优化路线与 Plus 订阅方案

> 前接《审查问题修复方案》（AUDIT_FIXES.md）：修复是"把错的改对"，本文是"把对的做得更好"。
> 分两部分：第一部分是流畅度/性能/下载等工程优化路线；第二部分是 Google Play 月卡式
> Plus 订阅的完整落地方案（含诚实的前置风险声明）。

---

# 第一部分：工程优化路线

## 1. 流畅度（滚动与交互帧率）

| # | 方向 | 做法 | 工作量 |
|---|---|---|---|
| 1.1 | 视频播放器重建治理 | 审查 M18：进度条改 `AnimatedBuilder` 只重建进度区；`ImageFilter.blur` 提 `static final`（全应用统一用 `glassBlurFilter`）；position 监听节流到秒粒度 | S |
| 1.2 | 根组件订阅粒度 | 审查 M21：`MaterialApp` 对 accentColor/language/themeMode 分别 `select`，`ColorScheme.fromSeed` 按 (seed, brightness) 缓存——调列数/强调色不再整树重建 | S |
| 1.3 | 相邻页预取 | 查看器打开第 i 张时对 i±1 的 sample 图 `precacheImage`（Wi-Fi 或蜂窝均可，缩略图已在缓存）；首页对下一页首屏缩略图做同样处理 | S |
| 1.4 | 视口缓存实验 | 在 `AppSliverMasonryGrid` 的 `cacheExtent` 上做 300–800px 实测（默认 250px 偏保守），用 DevTools timeline 定值 | S |
| 1.5 | Hero 飞行优化 | 打开详情的 Hero 动画当前用 sample 图参与飞行：飞行阶段用已解码的缩略图（timeline 瓦片帧），飞行结束再切 sample，消除大图解码造成的掉帧 | M |
| 1.6 | 批量进度条更新聚合 | `download_progress.dart` 每 1% 都 `[...state]` 复制整表：批量 50 条时改成按 URL 的 `Map` + 100ms 节流批量通知 | S |
| 1.7 | 下载列表缩略图 | 审查 M28：48dp 格 `cacheWidth` 化（同一文件里 `_preview` 已有修复范本） | S |

## 2. 性能（CPU / 内存 / 电池 / 体积）

| # | 方向 | 做法 | 工作量 |
|---|---|---|---|
| 2.1 | 内存缓存上限 | extended_image 的内存缓存（cache: true 已启用）设置上限（`maxMemoryCacheCount`/自定义 LRU），大瀑布流长会话内存可预测；"清理缓存"入口保留 | S |
| 2.2 | 磁盘缓存治理 | 现有手动清理之外加**自动 LRU**：磁盘缓存超阈值（如 512MB）时后台清最旧；设置页显示当前占用 | M |
| 2.3 | 大图查看解码 | 全屏查看器对超大原图按视口 `cacheWidth` 首解码、捏合放大到 2x 后再拉原图（两段式），防 6000×5000 图一次性解码 | M |
| 2.4 | 解析层共享工具 | 审查 M5 的 `_asInt/_asStr` helper 同时是性能项：减少整页解析因单条失败的重试/异常开销 | S |
| 2.5 | 视频生命周期 | 审查 M19（退后台暂停）——既是体验也是电池项 | S |
| 2.6 | 探测并行化 | `registry.probe` 目前串行 × 15s 超时，最坏 10 引擎 ≈ 150s：改 `Future.wait` 并发 + 首个命中即返回，加站体验从"分钟级"到"秒级" | S |
| 2.7 | Hive 定期 compact | `HiveSetup.flush()`（已挂后台生命周期）顺带按低频策略 `compact()`（如每次启动后一次），长会话后 box 文件不膨胀 | S |
| 2.8 | APK 体积 | `splits.abi` 已做对；再挤出 2–4MB 的手段：语言资源限定（`resourceConfigurations += ['en','zh']`，裁掉 AGP 打进来的上百种 locale）、检查 res 下未引用的密度资源（`androidx` 与插件带来） | S |
| 2.9 | 帧率回归看板 | `integration_test` + DevTools timeline 写一个滚动 500 帧的基准脚本，CI 上手动触发留档，防止优化倒退无人察觉 | M |

## 3. 网络与下载（用户重点诉求）

| # | 方向 | 做法 | 工作量 |
|---|---|---|---|
| 3.1 | **断点续传** | 目前中断=重下。实现：探到 `.part` 文件后带 `Range: bytes=<size>-` 请求，`206` 则 append、非 206 则整写。骨架见下 | M |
| 3.2 | 下载并发可调 | `_maxConcurrency=3` 提为设置项（1–6），配合审查 M11 的 stall 检测（60s 无进度失败重试） | S |
| 3.3 | 下载队列持久化 | 当前进度在内存，重启即丢：队列落 `JsonListStore`（复用现有串行事务），启动时恢复"未完成"项并询问是否续跑 | M |
| 3.4 | Wi-Fi-only 开关 | `connectivity_plus` 判断，设置项 + 批量下载入口提示；对流量敏感用户是刚需 | S |
| 3.5 | 重复下载治理 | 审查 M12(b)：下载前按 `serverId\|postId` 查记录 + MediaStore 查路径，已存在时提示"再次保存/跳过"，相册不再堆重复条目 | S |
| 3.6 | HLS 视频下载 | 现状正确（m3u8/mpd 明确拒绝、可播不可存）。进阶两档：① 优先 `video_alt_url` 的 mp4（已做，检查覆盖度）；② 远期内置 m3u8 分段下载+本地拼接（工作量大，先做需求调研） | S / L |
| 3.7 | 下载通知（可选） | 进度/完成通知需要 `POST_NOTIFICATIONS`——与当前"零通知权限"的刻意设计冲突：作为**默认关闭**的可选设置引入，同时更新 README 与 CI 清单断言（把"绝不申请"改为"默认不申请"） | M |
| 3.8 | 重试退避 | 统一网络重试策略：连接类错误指数退避（1s/2s/4s），429 带 Retry-After；探测与下载共用 | S |

断点续传骨架（`image_downloader.dart`）：

```dart
final part = File('$path.part');
final start = await part.exists() ? await part.length() : 0;
final resp = await client.get<ResponseBody>(url, options: Options(
  responseType: ResponseType.stream,
  headers: {if (start > 0) 'Range': 'bytes=$start-'},
));
final append = start > 0 && resp.statusCode == 206; // 服务器不支持 Range 则整写
final raf = await File('$path.part').open(
    mode: append ? FileMode.append : FileMode.write);
// stream 循环 raf.writeFrom；成功后 rename 到 $path → Gal 入库；失败保留 .part 供续传
```

## 4. 数据与可靠性

| # | 方向 | 做法 | 工作量 |
|---|---|---|---|
| 4.1 | search/hosts 仓库迁移 JsonListStore | 审查（中危）：一次迁移，并发丢更新与"损坏==空"覆写两类事故模式永久消失 | S |
| 4.2 | **凭据加固** | `apiKey` 目前明文存 Hive box（已靠 allowBackup=false 挡住系统备份面）。迁移 `flutter_secure_storage`（Android Keystore）：启动一次性搬运 + 旧值清除；备份导出继续不含凭据（现状正确） | M |
| 4.3 | 崩溃可见性 | `PlatformDispatcher.onError` 目前只 debugPrint，release 无人知晓：本地滚动日志文件（最近 N 次，含时间栈）+ 设置页"导出诊断"按钮（用户主动分享，不上传）——保持"数据不出设备"的承诺 | S |
| 4.4 | 图集/探索的统一分页 | 审查 M27 落地后，三个浏览页共用 page_state 模式，顺带消灭"图集只显示前 100 张"的静默截断 | M |

## 5. UX / 无障碍 / 本地化

| # | 方向 | 做法 | 工作量 |
|---|---|---|---|
| 5.1 | i18n 收口 | 审查 M26（19 文件硬编码中文）；补"跟随系统语言"选项（现只有 zh/en 手动切） | M |
| 5.2 | Semantics 全面化 | 批量选择状态、瀑布流瓦片（"查看 post xxx"）、查看器手势提示 liveRegion；TalkBack 全流程走一遍修断点 | M |
| 5.3 | 错误文案统一 | 探索/图集/下载错误全部走 `T.friendlyError`（审查 L-9 等），对用户永远不说裸异常 | S |
| 5.4 | 站点健康面板 | 服务器页显示每站连通性与延迟（探测接口已有），hosts 映射生效状态可视化 | S |
| 5.5 | 快捷黑名单 | 查看器/详情页长按标签 → "屏蔽此标签"（现要跳设置页手抄），配合 4.1 的稳定键 | S |

## 6. 开发与质量基建

| # | 方向 | 做法 | 工作量 |
|---|---|---|---|
| 6.1 | 引擎仓库层测试 | 见 AUDIT_FIXES 第 4 节：本地 HttpServer 假站点模式是全项目最大的测试杠杆 | M |
| 6.2 | 真站点核验 CI | SITES_AND_VIDEO.md 自述"DNS 污染环境下两个引擎未对真实站点验证"：加一个**手动触发、跑在海外 runner 上的** nightly workflow，对全部默认站点做连通+签名探测（只断言协议特征，不存内容），防止站点改版静默失效 | S |
| 6.3 | 依赖治理 | pubspec 依赖面健康（gal/dio/riverpod 均主流维护）；建议 CI 加 `flutter pub outdated` 报告 + 每季度一次小步升级，避免攒大版本 | S |
| 6.4 | 插件兼容护栏 | `android/build.gradle` 的 flutter 扩展补丁（gal 等 compileSdk 问题）依赖 Flutter 版本：升级 Flutter/AGP 时有回归风险，写进 RELEASING.md 的升级注意项 | S |

---

# 第二部分：Google Play「Plus」订阅方案

## 0. 先说清楚的三件事（诚实前置）

1. **与现有产品承诺的冲突**：README 宣称"不注册、不登录、不上传、不依赖任何应用商店、无账号门槛"。上 Play 订阅 = 分发与商业模式变更。建议以"**核心功能永久免费、Plus 只做增值便利**"为红线落地，README 同步改写，而不是静默违背旧承诺。
2. **Play 内容合规是最大前置，解法已定为「零预置 BYO-Server」**：Play 版不内置、不推荐、不链接任何站点——出厂是空白客户端，用户自行填写 URL（第 1 节含已逐文件核实的 8 处移除清单与**字节级** CI 门禁）。这是 IPTV 播放器（不带频道表）、RSS 阅读器（不带订阅源）、Kodi（默认无源）在 Play 上的既有合规模式：**审查看的是"随 APK 分发了什么内容与意图证据"，不是"理论上能连接什么"——浏览器不会因为能打开成人站被拒**。残余风险如实预期见 §1.5，配套四件套见 §1.3。
3. **Play Billing 只在 Play 分发的安装包上生效**：GitHub 直装 APK 天然没有付费通道。这反而给出一个干净的商业模型（见第 5 节）：**懂技术的用户从源码/GitHub 获得全功能，Play 用户为便利付费**——开源社区里被广泛尊重的模式。

## 1. 上架合规改造：零预置「BYO-Server」模式（本方案核心）

把"内容从哪来"的责任模型从**应用自带来源**改为**用户自行填写来源**：Play 版不内置、不推荐、不链接任何站点，出厂状态是空白客户端；用户手动输入 URL，由既有的协议探测引擎自动识别类型。这是 IPTV 播放器（不带频道表）、RSS 阅读器（不带订阅源）、Kodi（默认无源）在 Play 上的既有合规模式——**Play 审查的核心是"随 APK 分发了什么内容与意图证据"，而不是"理论上能连接什么"：浏览器不会因为能打开成人站被拒**。

### 1.1 必须彻底移除的预置（一处不留）

> **"移除" = 字节级移除**：隐藏开关、默认折叠、注释代码、口令解锁**都不算**。Release APK 会被反编译审查，AOT 产物、字符串常量、资源、外链、截图全部在视野内。任何残留都等于"藏证据"——被发现时的定性是蓄意规避审查（下架 + 封开发者账号），比明着预置更糟。

以下清单已经 grep 逐文件核实（2026-10-10），共 **8 处**，Play 版一处都不能留：

| # | 预置位置 | 现状 | Play 版处理 |
|---|---|---|---|
| 1 | `booru_site_template.dart:21-181` | **17 个站点模板**（`all` 15 + `planned` 2）：站名 + 域名 + 描述全量硬编码（Danbooru、Gelbooru、Safebooru、yande.re、Konachan、e621、Sankaku、Zerochan、Rule 34、Xbooru、Realbooru、TBIB、Rule34.us、Paheal×2、Rule34 Video、Anime-Pictures、E-Shuushuu） | 经 flavor 开关返回空列表；server_page 模板区整体消失 |
| 2 | `onboarding_state.dart:26-28` + `onboarding_page.dart:23-32` | 首启预勾选 safebooru；引导结束**按模板 baseUrl 直接建服务器** | Play 版首启改为"添加你的第一个服务器"教程：URL 输入 + `server_probe_page` 自动探测（已存在），全程不出现任何站点名 |
| 3 | 各引擎 `<engine>.dart:18` 默认 `baseUrl`（danbooru/gelbooru_v2/moebooru/e621/sankaku/zerochan/rule34/safebooru）+ `registry.dart:229` `baseUrl ?? engine.booru.baseUrl` 兜底 | createDio/createRepository 不传 URL 时**静默落到编译期站点默认值** | 兜底删除：Play 版 baseUrl 必填、缺省抛错；引擎 getter 经 flavor 开关返回空串 |
| 4 | 解析器默认参数：`zerochan_parser.dart:9`、`moebooru_parser.dart:16`、`sankaku_parser.dart:9`、`e621_parser.dart:9`、`rule34_parser.dart:7`（`_siteUrl = 'https://rule34.xxx'`） | 帖子详情链接有**硬编码站点默认值** | 全部改为必填参数，由仓库从服务器配置传入（对应 AUDIT_FIXES L-A-6，升格为 Play 版硬性前置） |
| 5 | `registry.dart:193-205` `scanner()` 域名→类型捷径表 | donmai.us、e621.net、yande.re、sankakucomplex.com、zerochan.net、rule34.xxx、safebooru.org、paheal.net、rule34video.com 等 10 个域名子串直通 | 表置空，全部 URL 走 `probe()`——探测特征是 `'<post'`、`/posts.json` 等**协议层**字符串，不含站点名，完整保留（这正是 BYO 的核心能力） |
| 6 | `app_strings.dart:376,393,422,428-429` | UI 提示文案含真实域名：URL 输入框 hint（danbooru.donmai.us / safebooru.org）、tag 建议 hint（gelbooru.com）、hosts 编辑器示例 | 改占位示例：`https://your-board.example.com`、hosts 示例 `1.2.3.4 your-board.example.com`（l10n 双语同步） |
| 7 | 应用内"关于/帮助"外链 | 指向 GitHub 仓库——README 含完整站点表与成人内容截图，对审查员是公开可查的**意图证据** | Play 版改链中立帮助页（新写一份，不含任何站点信息） |
| 8 | 商店 listing 文案与截图 | 待定 | 中性表述（"自建 image board 服务器浏览客户端"）；截图用占位/全年龄内容；不出现任何真实站点名 |

### 1.2 实现机制：预置收敛一处 + 编译期消除 + 字节级门禁

1. **单一数据面**：把模板/引导/扫描捷径/引擎默认域名的全部预置数据集中到 `lib/boorus/engine/site_presets.dart`，以 `const kPlayBuild = bool.fromEnvironment('boorunova.play');` 为唯一开关；所有消费方（server_page / onboarding / scanner / registry.createDio / 解析器入参）**只经它取数**。
2. **为什么必须是编译期开关**：`bool.fromEnvironment` 是编译期常量，Dart AOT 会把死分支连同字符串字面量一起摇树消除——**站点 URL 根本不进 Play APK 的字节**。运行时开关（shared_preferences 判断、隐藏菜单、远程配置）做不到这一点：字面量仍在二进制里，反编译即见。
3. **GitHub 构建不变**：`PLAY` 未定义时行为与现状完全一致（17 个模板、引导、扫描捷径全保留）——两个渠道的差异化即审查边界；同一 applicationId、同一签名（把现有发布密钥登记为 Play App Signing 的 app signing key，另建 upload key），Play 版可原地升级 GitHub 老安装，用户已配置的服务器是**用户数据**而非预置，升级后照常使用。这正好是 BYO 叙事的闭环：应用装出来就是空的，所有站点都是用户自己填的。
4. **CI 禁串断言（字节级）**：沿用项目"装机清单断言"的既有文化，release.yml 的 Play 构建尾部加一步——解包 APK 对产物 grep（同清单也跑一遍 `lib/` 源码）：

```yaml
- name: Play 版零预置断言（字节级）
  run: |
    unzip -o app-release.apk 'lib/*/*.so' 'classes*.dex' -d /tmp/apk
    if grep -R -a -E '(donmai\.us|e621\.net|sankakucomplex|yande\.re|konachan|zerochan\.net|gelbooru\.com|xbooru\.com|realbooru\.com|tbib\.org|safebooru\.org|paheal\.net|rule34video\.com|rule34\.(xxx|us|paheal))' /tmp/apk; then
      echo '::error::Play 构建产物里发现站点字面量残留'
      exit 1
    fi
```

5. **协议名 ≠ 站点名的边界**：`danbooru / gelbooru / moebooru / shimmie2 / philomena` 同时是协议/软件家族名，内部枚举值与探测特征可保留；`BooruType` 的 `e621 / rule34 / safebooru / zerochan / sankaku` 是**协议方言标识**（用户自配服务器需要它存类型），保留为内部码，但 Play 版 **UI 显示名**全部中性化（"Danbooru API"、"Gelbooru 0.2 协议"…），禁串清单只断言**域名与 UI 可见串**。若申诉阶段评审仍存异议，B 计划是枚举值改中性码 + 首启数据迁移，此处先不做。

### 1.3 零预置 ≠ 免检：合规四件套照做

| 项 | 做法 |
|---|---|
| IARC 分级问卷 | 如实填：应用自带零内容源、用户可自行接入任意服务器、可能遇成人内容 → M/18+；listing 明示"内容取决于你添加的服务器" |
| 安全模式默认 + 年龄门槛 | Play 版首启默认 safe 评级过滤开启，关闭需本地年龄确认（无账号）。预置移除是"不提供来源"，安全默认是"接入后也有保护"——两者叠加才是完整故事 |
| IFF（举报/屏蔽）通道 | 应用内天然支持"移除/屏蔽该服务器"；补 (a) 跳转来源站自身举报页的通用入口，(b) 申诉邮箱。UGC 政策三要素（可屏蔽、可举报、有申诉）全部落地 |
| 数据安全表单 | 仍申报"不收集数据"；新增一行"购买信息由 Google Play Billing 处理" |

### 1.4 工程合规项

| 项 | 要求 |
|---|---|
| targetSdk | Play 自 2025-08 起要求新上架/更新 target API **35**；当前 `flutter.targetSdkVersion`=34（Flutter 3.24）。上架前升级 Flutter 或 `build.gradle` 显式 `targetSdkVersion 35`（compileSdk 36 已满足） |
| AAB | Play 不收 APK：`flutter build appbundle`；`splits.abi` 配置对 AAB 无害保留 |
| 隐私政策 | 一页隐私政策 URL（声明"全部数据本地存储、不收集任何信息、内容源由用户自行配置"） |
| 通知权限（若做 3.7/新帖监控） | manifest 恢复 `POST_NOTIFICATIONS` → CI 的"绝不申请"断言**有意识地**改为"默认不申请、可选开启" |

### 1.5 残余风险的如实预期

- 零预置把"大概率被拒"降到"**可辩护**"，不是零风险：评审员可能了解 booru 生态，应用名 BooruNova 的 "booru" 关键词本身会引来更严的审视——这就是 listing 措辞、截图、帮助页全部中性化的原因。
- 被拒的应对：走申诉流程，提交 BYO 说明（零预置清单 + CI 字节级断言截图 + IFF 说明）——有工程证据的申诉远比"改改再交碰运气"成功率高。
- **不要反向操作**：把预置做成隐藏开关、彩蛋、特定口令解锁——反编译、差评、竞对举报任何一条都会暴露，届时定性是"蓄意规避审查"（下架 + 封号），比从没上架更糟。

## 2. 订阅技术实现（in_app_purchase）

### 2.1 商品设计

| 商品 ID | 形态 | 定价锚点 |
|---|---|---|
| `plus_monthly` | 自动续订月卡 | ¥12（Play 后台区域定价，约 $1.99 档） |
| `plus_yearly` | 自动续订年卡（base plan + offer） | ¥68（≈省 53%），首月/首年试用 offer |
| `plus_lifetime` | 一次性买断（非消耗型） | ¥198 |

单一 entitlement `plus`：任一商品激活即解锁全部 Plus 功能——三种 SKU 只是付款习惯差异，避免"功能分级"的复杂度。

### 2.2 本地架构（无后端）

```
启动:
  in_app_purchase 恢复流 → 读流/查历史购买
    → Play 本地验签（in_app_purchase 内置 Google Play 签名校验）
    → 写入 Hive 'plus_entitlement'（带 productId + 过期时间/买断标记 + 校验时间戳）

运行期:
  Entitlement = 缓存标记 && (买断 || 未过期)
  订阅类离线宽限: 缓存最近一次成功校验 ≤30 天即视为有效（Play 官方 grace 宽限 3 天，
  本地再放宽到"联网后 30 天内校验过"），避免弱网用户功能闪烁

购买/恢复入口:
  设置页"Plus"区: 状态卡片 + 购买/管理订阅（跳 Play 订阅页）/恢复购买按钮
```

要点：
- **不放任何功能逻辑在远端**：解锁判断纯本地（`EntitlementChecker` 单一入口），Play 验签由 in_app_purchase 完成，无需自建服务器，符合"零上传"基调；
- **restore 必做**：换机/重装场景 `in_app_purchase.restorePurchases()`；
- **不punish离线**：校验失败 ≠ 立即锁功能（见宽限策略）；
- 依赖：`in_app_purchase: ^3.2.0`（dev: `in_app_purchase_android` 平台层自带）。

### 2.3 代码骨架

```dart
class PlusState {
  final bool active;
  final String? productId;   // plus_monthly / plus_yearly / plus_lifetime
  final DateTime? expiresAt; // 买断为 null
  final DateTime lastVerifiedAt;
}

final plusProvider = NotifierProvider<PlusNotifier, PlusState>(PlusNotifier.new);

class PlusNotifier extends Notifier<PlusState> {
  // 启动时 load Hive → 监听 purchaseStream：
  //   GooglePlayPurchaseVerification → 更新 state + persist
  // 恢复入口: restorePurchases()
}
```

UI 侧全部走 `ref.watch(plusProvider.select((s) => s.active))`；免费路径显式注释，防止"顺手收费"污染核心体验。

### 2.4 测试

- Play Console **license tester** 测试号 + 测试轨道（internal → closed）全流程：购买、取消续订、退款、过期、离线宽限、restore；
- 单测：`EntitlementChecker` 的过期/宽限/买断矩阵用假时钟跑。

## 3. Plus 功能菜单（按落地成本分档）

> 原则：**每一项都必须对免费用户"仍然完整可用核心"**——Plus 卖的是便利与锦上添花。

### A 档：纯本地，零后端（随首个 Play 版本即可上）

| 功能 | 说明 |
|---|---|
| 主题外观包 | 强调色扩展色板、应用图标变体（Android 13+ themed icon 多套）、启动画面变体 |
| 进阶查看器 | 幻灯片间隔无级调节、无边框沉浸模式、双击缩放级别记忆、查看器手势预设（翻页模式：连续卷轴/单页） |
| 高级黑名单 | 正则/通配符匹配、按站点作用域、黑名单一键导入导出 |
| 批量增强 | 下载并发上限解锁至 6、批量操作规模上限提高、下载队列持久化续跑（3.3 对 Plus 开放） |
| 站点分组 | 服务器列表分组/文件夹（工作/收藏分栏） |
| 缓存大师 | 预取下一页缩略图、Wi-Fi 预取收藏页原图、自动 LRU 策略细调（2.2 的 Plus 化包装） |
| 本地统计 | 浏览/下载/收藏趋势图（纯本地 Hive 数据，无上报） |

### B 档：用户自己的云，零服务器（第二个里程碑）

| 功能 | 说明 |
|---|---|
| 云备份到 **用户自己的 Google Drive** | `google_sign_in` + Drive **App Data** 隐藏目录（`drive.appdata` scope）：备份文件进用户自己的 Drive，不经过任何我们的服务器，与应用"不上传"基调兼容（用户主动选择把自己的备份放进自己的云）；沿用 H6 修好的备份格式 |
| 多设备同步 | 同一 Drive 备份的导入/自动同步（收藏、黑名单、hosts、设置），换机成本归零 |

### C 档：轻后端 / 平台能力（远期）

| 功能 | 说明 |
|---|---|
| 新帖监控通知 | `flutter_workmanager` 周期轮询（≥15min）订阅的 tag/搜索词，命中差异即本地通知——无推送服务器，纯设备侧；依赖第 1 节的通知权限改造 |
| 每日精选/随机推送 | 同上机制，纯本地拉取 |

## 4. 定价与转化建议

- **免费试用**：`plus_yearly` 带 7 天试用（Play 原生支持），月卡不带——把试用作为年卡转化器；
- **对照锚点**：同类图库聚合类 App 订阅普遍 ¥8–25/月；¥12/月、¥68/年、¥198 买断是"轻订阅"定价，匹配工具类心智；
- **GitHub 版的定位**：建议保持 GitHub Releases 构建 = 全功能（含 A 档），README 明示"从源码构建/直装的用户不需要订阅，Play 版订阅是为自动更新与便利付费"——诚信换社区口碑，付费转化来自非技术用户，两拨人不重叠；
- **绝不放付费墙的功能清单（写进 README）**：任意站点添加、浏览、搜索、收藏、下载、备份（本地）、hosts——这些是 1.x 的产品根基。

## 5. 落地路线图

| 阶段 | 内容 | 里程碑 |
|---|---|---|
| P-1（随时可做，零成本） | **打赏通道上线**：`FUNDING.yml` + 设置页"支持开发"入口（GitHub Sponsors / Ko-fi / 爱发电，§6.2 路线 B） | 收入通道从第一天就存在 |
| P0（上架准备） | AUDIT_FIXES A 批修复 + **§1 零预置 BYO 改造**（site_presets 收敛 + PLAY 编译期开关 + 字节级禁串断言）+ 合规四件套 + 隐私政策 + AAB/targetSdk 35 | Play internal track 过审 |
| P1（订阅上线） | in_app_purchase 集成 + A 档 7 项功能 + license tester 全流程 | Play 正式版 + 订阅可购 |
| P2（云同步） | Drive App Data 云备份/恢复/多设备同步 | B 档上线 |
| P3（持续） | 通知监控（C 档）+ 性能优化看板常态化 | 按数据决定 |

每阶段的验收都跑一遍 RELEASING.md 的清单（CI 断言届时需同步更新：新增 `BILLING` 权限是 in_app_purchase 插件自动合并进清单的，现有"装机清单断言"要把它加白名单，**这是有意识的例外，不是破例**）。

---

## 6. 参考案例：Boorusama（同类开源产品的商业与产品决策）

> 2026-10-10 实地调研。本开发环境对 GitHub / Play 域名存在 DNS 污染，以下事实经 repos.ecosyste.ms 开放 API 与国内镜像核实；无法逐条核实的项已明确标注。Boorusama 是与 BooruNova 定位最接近的开源同门（同为 Flutter 的 booru 聚合客户端）。

### 6.1 核实过的事实

| 维度 | Boorusama | 来源 |
|---|---|---|
| 许可证 | **GPL-3.0** | 仓库元数据（COPYING） |
| 技术栈 | Dart / Flutter（与 BooruNova 相同） | 仓库元数据 |
| 规模与活跃度 | 507 stars / 5.11k 提交 / 115 tags，2020-09 创建、2026-10 仍在更新 | repos.ecosyste.ms |
| 分发渠道 | **Google Play**（`com.degenk.boorusama`，免费）+ GitHub 源码 + 第三方 APK 镜像（apkpure / apkcombo / pgyer） | Play 商店页、各镜像站 |
| **收费方式** | **纯打赏**：`.github/FUNDING.yml` 配置 Patreon + Ko-fi + Buy Me a Coffee 三条通道；**无 IAP、无订阅、无付费墙**。广告情况本环境无法核实，但其 GPL + 纯打赏的形态基本排除广告变现 | 仓库元数据 funding 字段 |
| 引擎家族 | danbooru、gelbooru、moebooru、sankaku、zerochan、shimmie2、philomena、hydrus-network、anime-pictures（topics 可见 9 族，比 BooruNova 多 philomena / hydrus / anime-pictures；topics 只是作者打的标签，未必穷尽） | 仓库 topics |

### 6.2 收费思路的启示：先打赏、后订阅，两条线并行

Boorusama 证明了这条路走得通：**GPL 开源 + Play 免费上架 + 纯打赏**，六年活跃、上百个版本。对我们的直接校准是把变现拆成两层：

| | 路线 B：打赏（Boorusama 模式） | 路线 A：Plus 订阅（本文方案） |
|---|---|---|
| 工程成本 | **零**（FUNDING.yml + README 徽章 + 设置页"支持开发"入口） | in_app_purchase 集成 + 合规改造 |
| 收入特征 | 不可预期、靠社区善意（无法核实 Boorusama 实际打赏收入） | 可预期、可定价 |
| 与"零上传/无账号"基调 | 完全无冲突 | 无冲突（entitlement 纯本地） |
| 风险 | 无 | 上架合规 + 订阅运营 |

**建议**：P0 就把打赏通道挂上（`FUNDING.yml` + 设置页"支持开发"入口；国际用户走 GitHub Sponsors / Ko-fi，国内用户可加爱发电 afdian 作为 custom 链接）——零成本先跑起来。Plus 按 P1 推进，两条线并行：**打赏面向开源社区，Plus 面向 Play 生态的普通用户**。Boorusama 的"形态"给的最重要校准是：先保证产品活下来、被信任，变现是第二位。

### 6.3 分发的合规启示：一个存在性证明 + 两个姿态

- **存在性证明**：Boorusama 以直白的 "booru client" 描述、含预设站点，多年存活于 Google Play（包名甚至带着 "degen"）——说明实践审查对这类应用**存在通过案例**。
- **但要清醒**：样本量 = 1；Play 政策是抽查执行，通过 ≠ 合规背书，同类应用历史上发生过批量清理；它过审时的分级与材料本环境无法核实。**不构成"带预置上架必然安全"的依据**。
- 由此给出两个姿态，仍推荐**先稳后进**：
  1. **上架姿态（P0 按原计划）**：零预置 BYO 上架——过审确定性最高，叙事自洽（"应用装出来就是空的"）。
  2. **进阶姿态（过审后的自由度）——预置"内容包外置"**：把 17 个站点模板做成一份可导入的 JSON（放在 GitHub 仓库/社区页，**不进 APK、Play 版应用内不链接**）；添加页提供"导入站点包"能力，用户导入即恢复全部模板。这等于把"预置"从应用字节挪到用户侧操作：合规边界不变（Play 版分发的字节仍零预置），懂技术的用户拿回全部便利。GitHub 版可以内置导入链接，Play 版不带。
  - **警告**：过审后再往 Play 版 APK 里**加回**预置是危险操作（重大更新触发复审）；要加便利就走"内容包外置"，不要改回内置。

### 6.4 按站点配置的借鉴：per-server 设置层（产品升级，免费核心）

Boorusama 的按站点设置是其口碑来源之一（基于其公开版本历史与社区讨论归纳；本环境无法读其源码逐行核实）：每个 booru 有**站点级**独立配置——可见评级过滤（比如只在某个站隐藏 explicit）、预览/下载画质分开选（sample / original）、tag 建议行为、站点级黑名单、下载目的地等；登录后按站解锁能力（Danbooru 的 API key → 收藏/投票/图集，Sankaku 登录提额）。背后的设计模式值得整体借鉴：

1. **能力声明（capability flags）**：给引擎契约（BooruRepository / 引擎注册表）加能力标志——`supportsAuth / supportsFavorites / supportsPools / supportsTagSuggestions / maxPageLimit / supportsRatingFilter`——设置 UI 按能力自动增减选项。BooruNova 现有的"遗留 planned 引擎下拉空白"问题（D L13）会被这套机制顺带治好：未实现引擎自动没有配置页。
2. **站点级配置层**：`BooruServer` 配置扩展为"URL + 凭据 + 站点偏好"三段；站点偏好至少包含：可见评级过滤（每站独立于全局）、预览画质、下载画质、站点级黑名单作用域、下载子目录、默认排序。**全部免费**——按站点配置属于核心可用性，不是 Plus 门槛（Plus 的 A 档是便利增强，别把基础配置做成收费）。
3. **优先级**：排在 AUDIT_FIXES B 批之后；其中"每站评级过滤"与 H3（四档评级修复）是同一条数据链，建议同批设计。

### 6.5 许可证决策：要不要从 MIT 转 GPL-3.0

**先拆一个误区：收费与许可证是两个独立决策。**
- MIT 下完全可以收费（甚至可以直接做闭源商业版——MIT 允许衍生品转为专有许可）；
- GPL-3.0 也不会帮你收费：任何人都可以合法剥掉 entitlement 重编译分发免费版（MIT/GPL 皆然）。§0.3 的"GitHub 版全功能"模型本来就接受了这一点——**Plus 卖的是便利，不是封锁**。

**GPL-3.0 真正改变的是"分叉的命运"**（对照威胁模型）：

| 你担心的 | MIT | GPL-3.0 | 备注 |
|---|---|---|---|
| 别人拿代码**闭源**做商业竞品 | 合法 | **违法（可诉讼）** | GPL 的核心价值；中国有司法先例（风灵 VirtualApp 案，判赔） |
| 广告/马甲克隆包再分发 | 合法 | **仍合法**（须保留版权声明 + 公开其改动） | 许可证治不了马甲包——靠商标 + 商店举报 + 签名校验 |
| 剥付费墙的免费 fork | 合法 | 仍合法 | 治不了，模型上已接受 |
| 吸收 Boorusama（GPL-3.0）代码 | 违法 | **合法** | 转 GPL 后，philomena / hydrus / anime-pictures 三个引擎可直接参考采用 |

对"应用"而言，"MIT 过于宽松"的直觉是对的：MIT 是**库**的惯例（追求最大采用），应用要防白嫖闭源就用 GPL——Boorusama 同款选择不是巧合。

**时机：要换就现在换（单向门）。**
已核仓库提交历史（2026-10-10）：94 个提交、作者全部是你自己 → 此刻改 LICENSE 单方面即生效、零成本。一旦合并第一个外部 PR，该代码的版权就属于贡献者，未来任何再许可都要取得其同意——**换证成本从今天起只增不减**。

**副作用如实清单**：
- 源码必须持续公开（本来就公开，无实际损失）；
- 部分企业背景贡献者会回避 GPL（个人 booru 应用影响小；Boorusama 以 GPL 维持 500+ 星社区）；
- iOS App Store 远期注意：GPL-3.0 与 Apple 商店条款有历史争议（VLC 下架事件）；Google Play 无此问题（官方明确允许 GPL 应用）；
- 依赖兼容性无障碍：现行依赖（riverpod / dio / gal 等）均为 MIT/Apache/BSD；**AGPL 无必要**（纯本地应用没有网络服务组件）；
- 备选 MPL-2.0（文件级 copyleft，企业友好但保护弱于 GPL）——列为备选；
- 按 MIT 已分发出去的旧版本无法追回（换证只对新版本生效），实际无碍。

**操作清单**（决定转 GPL-3.0 时）：
1. `LICENSE` 替换为 GPL-3.0 全文（版权行保留 "BooruNova contributors"）；
2. README（中英）许可段落与徽章同步；
3. `CONTRIBUTING.md` 写明"提交即按 GPL-3.0 授权"（免 CLA，同时堵住未来的单向门问题）；
4. 逐文件 SPDX 标头可选（GPL 只强制整体许可文本，不强制逐文件标头）；
5. 执行后顺带解锁上表最后一行：Boorusama 代码可直接参考采用。

**落地记录（已执行，2026-10）：改用 GNU AGPL-3.0，而不是 GPL-3.0。**
比 GPL-3.0 多的只有 §13「远程网络交互」义务：把修改版当网络服务对外提供时，必须向使用者
提供对应源代码。对 BooruNova 这种纯本地应用没有额外负担，但顺手堵住了"把代码接进自己的
服务端再闭源运营"这条 GPL-3.0 管不到的路径。已同步：`LICENSE` 全文、README（中英）徽章与
许可段落、`CONTRIBUTING.md`（提交即按 AGPL-3.0 授权、免 CLA）、应用内关于页、商店文案。
上面"AGPL 无必要"一句是当时的判断，以本记录为准。

---

## 附：与审查修复的交叉引用

- 第一部分 1.1/1.2/1.7/2.3/2.5 对应 AUDIT_FIXES 的 M18/M21/M28/M16/M19；
- 3.5/3.2/3.7 对应 M12/M11 与清单断言变更；
- 4.1 对应中危"search/hosts 迁移"；
- 5.1 对应 M26；5.3 对应 L-9；
- 第二部分 §1.1 清单第 4 项 = AUDIT_FIXES L-A-6（rule34 postUrl 参数化）升格为 Play 版硬性前置；
- 第二部分 §1 与 M24（URL 校验/查重）直接相关：BYO 模式下"添加服务器"是唯一入口，校验体验就是产品门面；
- 第二部分 §6.4 的"每站评级过滤"与 AUDIT_FIXES H3（四档评级）是同一条数据链，建议同批设计；§6.4 能力标志顺带解决 D L13（下拉 value 不在 items）。
