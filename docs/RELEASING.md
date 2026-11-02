# 发布流程（Android）

本文件是发布链的**唯一操作说明**。手工发布容易漏步骤，漏掉的每一样都曾经出过事：
漏 `--target-platform` 会让通用包从 38MB 涨到 56MB；漏签名校验会让 debug 签名的包发出去。

## 0. 不可违反的两条红线

1. **密钥不可更换。** `android/release.jks` 一旦更换，所有已安装用户必须卸载重装才能升级
   （签名不一致 → `INSTALL_FAILED_UPDATE_INCOMPATIBLE`）。
2. **口令可以更换，且不影响升级。** 换口令只改容器密码，密钥对与证书不变：

   ```bash
   keytool -storepasswd -keystore android/release.jks -storepass <旧口令> -new <新口令>
   # PKCS12 的 key password 跟 store password 一致，改完同步更新 android/key.properties
   ```

## 1. 密钥台账

| 项 | 值 |
|---|---|
| 签名证书 SHA-256 | `5687a29420f6e278faae3ff97e420ce1adc5517d8b5a6cf759995f38c681f3cd` |
| DN | `CN=Dev` |
| 签名方案 | APK Signature Scheme v2（minSdk 26，v1 不需要） |
| 密钥文件 | `android/release.jks`（**不入库**，`android/.gitignore` 已忽略） |
| 口令文件 | `android/key.properties`（**不入库**） |

**备份要求**：`release.jks` + `key.properties` 至少两份离线副本（例如密码管理器附件 + 加密U盘）。
当前这份密钥只存在于开发机，磁盘损坏 = 永久失去所有用户的升级能力。

> ⚠️ 口令 `123456` 属可离线爆破的强度，务必按第 0 节换成随机串。
> 换口令后**必须**同步更新 `key.properties` 与 CI Secrets，否则下一次发布直接失败（这是有意的硬失败）。

## 2. 版本号

唯一来源是 `pubspec.yaml` 的 `version: <name>+<code>`：

* `versionName` = `<name>`，`versionCode` = `<code>`（**只增不减**，Android 硬约束）。
  写具体数字容易过时（这里曾经写死 `1.8.2`/`24`），以 `pubspec.yaml` 为准。
* `android/app/build.gradle` 不再回落到 `1.0`：缺 `flutter.versionCode` / `flutter.versionName`
  会直接构建失败，提示你去用 `flutter build`（由 flutter 工具把版本写进 `local.properties`）。
* 发版前先提交 `chore(release): bump version to x.y.z+N`，Tag 打在**同一个提交**上。

## 3. 构建与上传

```bash
# 一次性：确保签名就位
ls android/key.properties android/release.jks

# 构建（两个包一起出：arm64 专用 + 双 ABI 通用）
flutter build apk --release --target-platform android-arm64,android-x64

# 产物
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk   # ~19MB，绝大多数手机
build/app/outputs/flutter-apk/app-release.apk             # ~38MB，arm64 + x86_64
```

`--target-platform` 不能省：不加会把 armeabi-v7a 一起打进通用包（38MB → 56MB），
且与 README 里声明的体积不符。

也可直接运行脚本（含体积/签名/哈希自检）：

```bash
tool/release_android.sh            # 只构建并自检
tool/release_android.sh --publish  # 构建自检后创建 GitHub Release 并上传
```

## 4. 发布前自检清单

- [ ] `flutter analyze --fatal-infos` 无问题
- [ ] `flutter test` 全绿
- [ ] `apksigner verify --print-certs` 的证书 SHA-256 == 台账里的 `5687a294…`
- [ ] 装机清单无 `REQUEST_INSTALL_PACKAGES` / `POST_NOTIFICATIONS`，且 `allowBackup="false"`
      （CI 里有断言，本地可 `aapt2 dump xmltree <apk> --file AndroidManifest.xml`）
- [ ] 通用包 ≈37MB（不是 56MB）；arm64 专用包约 **19MB**
- [ ] 调试符号已归档：本地在 `build/symbols.tar.gz`，CI 走 workflow artifact（`symbols-<tag>`）。
      **Release 页面只挂安装包**，不放符号与校验和文件
- [ ] README 的「最新版本」与下载表体积已同步
- [ ] `docs/DEVICE_VERIFICATION.md` 里与本次改动相关的条目已在真机跑过（离线环境覆盖不到的项）

## 4.1 升级 Flutter / AGP 的注意项

`android/build.gradle` 末尾有一段**插件补丁**：给所有 `com.android.library`
插件项目补一个 `flutter` 扩展（`FlutterSdkVersions`）。原因是若干插件仍用旧
模板 `android { compileSdk flutter.compileSdkVersion }`，而 Flutter 只为 app
项目注册该扩展，插件在求值阶段会直接报 "Could not get unknown property
'flutter'"。

升级时必看：

- 补丁里的 `compileSdkVersion / minSdkVersion / targetSdkVersion / ndkVersion`
  是**硬编码**的，必须与 `android/app/build.gradle` 保持一致；升级 AGP /
  Flutter / NDK 后忘了同步，会出现「app 用新 SDK、插件用旧 SDK」的错配。
- 新版本 Flutter 若改为给插件项目也注册 `flutter` 扩展，这段补丁会因为
  `findByName('flutter') == null` 判断而自动让位——不需要手工删，但升级后
  应确认插件求值不再报错。
- 升级 Flutter 后 `.metadata` 里记录的 revision 会变；CI 与 release.yml 里
  `flutter-version` 是写死的 3.24.0，**必须一起改**，否则「本机能过、CI 不过」。
- 升级后至少跑一次 `flutter build apk --debug --target-platform android-arm64`
  （CI 已经在跑），再按第 4 节清单跑一次发布自检。

## 4.2 凭据存放（1.8.7 起）

站点的 `apiKey` / `login` **不再落 Hive**，改存平台安全存储
（Android：`flutter_secure_storage` → Keystore 加密的 SharedPreferences）。

- 首次启动（`main` 里、首帧之前）做一次性搬运：写进安全存储 → **读回复核** →
  才抹掉 Hive 里的明文；复核失败或存储不可用时**保持原样**（宁可留明文也不丢 Key）。
- 每次保存站点也复核一次（个别设备的 Keystore 是静默失败：调用不报错、读回来是空）。
  复核不通过时站点照样保存，但 `save()` 返回 false，编辑页会提示「本次会话有效」。
- 导入备份走 `saveImported()`：**完全不碰**凭据存储。备份不含凭据，导入不该有
  「清空某个站点 Key」的副作用。
- 孤儿凭据只在 `HiveSetup.recoveredFromCorruption` 为真时清理（服务器记录确实
  因 box 损坏消失了）；平时不清理——`_rawAll()` 会跳过单条损坏记录，把它当成
  「已删除」就会误删用户的 Key。
- 读取路径仍是同步的：启动时把凭据读进进程内镜像，`getAll()` 同步叠加。
  所以 `initCredentials()` 必须完成在首帧之前，否则第一次请求会以未认证身份发出。
- 备份导出依旧不含凭据（`toBackupJson`），落盘走 `toStoredJson`（连凭据的键都不出现）。
- 该插件**不新增任何权限**（走 EncryptedSharedPreferences，非生物识别路径）。

回归守卫在 `test/credential_store_test.dart`（含「写不进安全存储时不得抹掉明文」
的负对照）。升级该插件时重点确认：迁移仍然只做一次、`read` 复核仍然生效。

## 4.3 体积（§2.8）：已做的与实测效果

| 手段 | 状态 | 实测 |
|---|---|---|
| `splits.abi`（只出 arm64/x64，通用包不含 armeabi-v7a） | 已有 | 通用包 56MB → 38MB |
| `resourceConfigurations += ['en', 'zh']` | 已有 | 裁掉 AGP 打进的上百种 locale |
| `--split-debug-info=build/symbols` | 本轮接入 | **arm64 专用包 19.6MB → 18.5MB**（符号 3.76MB 单独归档） |

**符号要留，但不进 Release**：`--split-debug-info` 只是把符号从 `libapp.so`
挪出去，不是删掉。用户用「设置 → 关于 → 导出诊断」给出的崩溃栈必须靠同一次
构建的符号才能还原，所以 release.yml 会打包 `symbols.tar.gz`，作为 **workflow
artifact** 留存（本地则在 `build/symbols.tar.gz`）。Release 页面只挂安装包。
本地发版脚本 `tool/release_android.sh` 已带同一参数（口径与 CI 一致）。

## 4.4 两条渠道：GitHub 直装版 与 Play 版（零预置 BYO）

两个渠道的差别只有一个编译期开关：`--dart-define=boorunova.play=true`。

| | GitHub 直装版（默认） | Play 版 |
|---|---|---|
| 出厂站点模板 | 16 个 | **无**（装出来是空白客户端） |
| 引导首启 | 勾选站点 | 「添加你自己的第一个服务器」 |
| 探测域名捷径 | 有 | 无（全走协议探测） |
| 引擎默认域名 / 解析器默认站点 | 有 | 空串（必须由服务器配置提供） |
| 界面占位示例 | 中立域名 | 中立域名 |
| 关于页外链 | GitHub 仓库 / Issues | 无外链（仓库含站点表与内容截图） |

预置数据只有一处：`lib/boorus/engine/site_presets.dart`。改预置只需改它，
但**必须同时跑下面两条门禁**：

> **不要并行跑两个 `flutter build`。** 它们会写同一个
> `build/app/outputs/flutter-apk/app-release.apk`，后完成的把先完成的覆盖掉。
> 本轮就踩过：并行构建时拿「非 Play 包」去跑 Play 门禁，得到了一次**假通过**
>（那次通过来自被覆盖成 Play 的那个文件）。要对比两个构建，必须串行，并且
> 每次都在构建后立刻对**刚产出的那个路径**跑门禁。

0. `bash tool/check_i18n_coverage.sh` —— 源码级：界面层不得出现未走 `T` 的
   中文字面量（README 的「完整双语」宣称靠它成立）。CI 已跑。
0. `bash tool/check_preview_urls.sh` —— 源码级：「预览用哪张图」只允许由
   `previewUrlOf()` 决定（查看器 / 详情页 / 收藏弹层共用；previewQuality 设置
   才可能处处生效）。CI 已跑。
1. `bash tool/check_site_presets.sh` —— 源码级：站点字面量只允许出现在
   `site_presets.dart`（注释除外）。CI 每次 push / PR 都会跑。
2. `bash tool/check_play_bytecode.sh <release 产物>` —— **字节级**：Play 产物里
   不得出现任何站点域名。发 Play 包时必须跑（`release.yml` 的
   `play_build=true` 会自动跑）。

本地核验（Windows 上 flutter 是 .bat，WSL 里跑不了 flutter，分两步）：

```bash
flutter build apk --release --target-platform android-arm64 --dart-define=boorunova.play=true
bash tool/check_play_bytecode.sh build/app/outputs/flutter-apk/app-release.apk
```

**Play 上架用的是 AAB**（Play 不收 APK）：

```bash
flutter build appbundle --release --dart-define=boorunova.play=true
bash tool/check_play_bytecode.sh build/app/outputs/bundle/release/app-release.aab
```

`splits.abi` 只影响 APK 输出，**对 AAB 无害**（已实测：AAB 里同时含
arm64-v8a / armeabi-v7a / x86_64 三套 `libapp.so`，由 Play 按设备切分下发）。
APK 侧的 `--target-platform` 仍然不能省，那是给 GitHub 直装包控制体积的。

Play 版另有两条合规默认（见 §1.3）：**首启即开启安全模式**（浏览默认只取安全档，
关闭需本地年龄确认），以及**「内容来源与举报」说明页**（可屏蔽 / 可举报 / 有申诉）。
两者都在 `--dart-define=boorunova.play=true` 下体现，GitHub 直装版行为不变。

> **不要**拿 debug 的 `kernel_blob.bin` 当替身：debug kernel 为了堆栈可读会嵌整份
> 源码文本（连注释都在），必然命中，等于没测。只有 release 的 AOT 产物
> （`libapp.so` / `classes.dex`）才是权威口径。

## 5. CI

| 工作流 | 触发 | 作用 |
|---|---|---|
| `.github/workflows/ci.yml` | push main / PR | analyze + test + 合并清单断言 |
| `.github/workflows/release.yml` | push tag `v*` | 构建 + 断言签名证书 + 上传 Release 资产 |
| `.github/workflows/site-healthcheck.yml` | 每晚 18:00 UTC / 手动 | 海外 runner 上核验全部预置站点的协议特征（OPT §6.2，失败开 issue、**不拦发布**） |

Release 工作流需要四个仓库 Secret（Settings → Secrets → Actions）：

| Secret | 内容 |
|---|---|
| `KEYSTORE_BASE64` | `base64 -w0 android/release.jks` 的输出 |
| `KEYSTORE_PASSWORD` | keystore 口令 |
| `KEY_PASSWORD` | key 口令（PKCS12 下同 `KEYSTORE_PASSWORD`） |
| `KEY_ALIAS` | `key` |

CI 中写死了证书指纹断言：用错密钥会当场失败，不会发出装不上的包。

## 6. 依赖治理（OPT §6.3）

- **每轮 CI 跑 `flutter pub outdated`**（只报告、不拦）：依赖面健康是「持续看得见」
  的事，不该等到攒了一堆大版本才发现。
- **每季度一次小步升级**：一次只升一到两个包，升完跑 `flutter analyze --fatal-infos`
  + 两套渠道的 `flutter test` + 三道源码门禁。主力包（dio / riverpod / hive / 
  extended_image）跨大版本会牵动一大片，小步升才有干净的回归面。
- **直接依赖与传递依赖的边界由 analyze 守住**：`depend_on_referenced_packages` 会
  拦下「为了一个常量去 import 传递依赖」这类写法（本项目已经踩过一次：缓存目录名
  一度想从 `extended_image_library` 直接拿，最后改成用 `extended_image` 的再导出）。
- **新增依赖的门槛**：能用现有依赖做到的就不加；引入平台插件时要同时给**测试替身**，
  否则 widget 测试会因为 `MissingPluginException` 直接挂（`flutter_secure_storage`
  就是这么处理的）。
- **升级 Flutter / AGP** 另有注意项，见 §4.1。
