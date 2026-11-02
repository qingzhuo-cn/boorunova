---
name: 发版检查单
about: 发版前逐项核验（静态检查 / 发布链 / 真机项）
title: '发版检查单 v'
labels: release
---

<!--
用法：复制本模板成一次发版的 issue，填上版本号，逐项勾选。
权威说明分别在 docs/RELEASING.md（发布链）与 docs/DEVICE_VERIFICATION.md（真机项），
本模板只是把两份清单折叠成一个可勾选的执行面。
-->

## 0. 版本与提交

- [ ] `pubspec.yaml` 的 `version:` 已 bump（versionCode **只增不减**）
- [ ] 提交 `chore(release): bump version to x.y.z+N`，tag 打在**同一个提交**上
- [ ] 确认本次改动是否触及 Play 渠道（零预置 / 安全模式 / 合规模块）

## 1. 静态门禁（CI 已跑，本地复核）

- [ ] `flutter analyze --fatal-infos` 无问题
- [ ] `flutter test` 全绿（GitHub 渠道）
- [ ] `flutter test --dart-define=boorunova.play=true` 全绿（Play 渠道）
- [ ] `bash tool/check_site_presets.sh` 通过（站点预置只有一处）
- [ ] `bash tool/check_preview_urls.sh` 通过（预览图选择只有一处）
- [ ] `bash tool/check_i18n_coverage.sh` 通过（界面文案全部走 T）

## 2. 发布链（详见 docs/RELEASING.md §4）

- [ ] `apksigner verify --print-certs` 的证书 SHA-256 == 台账 `5687a294…`
- [ ] 装机清单：无 `REQUEST_INSTALL_PACKAGES` / `POST_NOTIFICATIONS`，`allowBackup="false"`
- [ ] 通用包 ≈38MB（不是 56MB）；arm64 专用包 ≈18.5MB
- [ ] `symbols.tar.gz` 已上传（否则用户导出的诊断日志无法还原成可读栈）
- [ ] README / README_cn / app_store_intro 的版本与体积已同步

## 3. Play 渠道专用（仅当本次发 Play 包）

- [ ] `flutter build appbundle --release --dart-define=boorunova.play=true`
- [ ] `tool/check_play_bytecode.sh <apk>` 与 `<aab>` 均通过（字节级禁串）
- [ ] 首启为空白客户端；安全模式默认开启；「内容来源与举报」页可用
- [ ] 关于页无 GitHub 外链；引擎显示名为中性名
- [ ] 开发者联系方式已在 Play Console 公示（应用内刻意不写死邮箱）

## 4. 真机项（详见 docs/DEVICE_VERIFICATION.md）

按本次改动勾选相关条目，至少覆盖：

- [ ] D1 相册权限（Android 8/9/10：首次弹窗、允许成功、拒绝给可读文案且授权后能立刻重试）
- [ ] D2 批量下载取消 / 重复下载跳过
- [ ] D3 自定义下载目录被拒
- [ ] D4 视频退后台暂停
- [ ] D5 放大后不再被下滑关闭劫持
- [ ] D6 黑名单改动后瓦片不串图
- [ ] D7 备份导出走分享面板、导入逐段汇报、重复导入幂等
- [ ] D8 danbooru/e621 四档评级徽章
- [ ] D12 探测秒级返回 / 取消 / 防并发
- [ ] D13 站点家族模板与「编辑现有」
- [ ] D14 探索/图集分页与黑名单
- [ ] D16 Play 空白首启 + 安全模式 + 内容来源页
- [ ] D17（仅上架前）targetSdk 35 边到边行为

## 5. 记录

```
构建：<git rev> / <versionName>+<versionCode>
设备：<型号 / Android 版本>
失败项：<编号 + 现象 + 日志片段>
```
