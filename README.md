# BooruNova

一个基于 Flutter 的 Android Booru 客户端

A Flutter-based booru client for Android

---

## 功能特点 / Features

- **多服务器支持** — Danbooru、Gelbooru、Safebooru、Moebooru、e621、Sankaku、Zerochan、Rule34 等
- **服务器管理** — 添加/编辑/删除服务器，自动检测引擎类型，内置模板快速添加
- **帖子时间线** — 瀑布流布局，可调节列数（2-6），交错入场动画
- **查看器** — 全屏图片浏览，双指缩放，幻灯片模式，滑动切换
- **帖子详情** — 分类标签（画师/角色/版权/通用/元数据），多选 + SpeedDial 操作按钮
- **搜索** — 底部搜索栏，标签自动补全，热门标签推荐，搜索历史
- **收藏与下载** — 收藏帖子，下载图片到相册
- **标签屏蔽** — 屏蔽不想要的标签，支持管理黑名单
- **Hosts 功能** — 自定义域名到 IP 的映射，适用于网络受限环境
- **手势控制** — 可配置的滑动/点击/双击/长按动作
- **主题** — 浅色/深色/午夜模式，强调色自定义
- **导航** — 左侧抽屉（收藏/下载/服务器/设置），右侧抽屉（浏览/论坛/画师）
- **中文界面** — 完整中文语言界面

---

## 截图 / Screenshots

（即将添加 / Coming soon）

---

## 快速开始 / Getting Started

### 环境要求 / Prerequisites

- Flutter SDK >=3.0.3
- Android SDK

### 安装运行 / Installation

```bash
git clone https://github.com/qingzhuo-cn/boorunova.git
cd boorunova
flutter pub get
flutter run
```

### 构建 Release APK / Build

```bash
flutter build apk --release --target-platform android-arm64
```

或从 [GitHub Releases](https://github.com/qingzhuo-cn/boorunova/releases) 直接下载最新 APK。

---

## 使用说明 / Configuration

### 添加服务器 / Adding a Server

1. 在服务器页面点击 **+** 悬浮按钮
2. 输入站点地址（如 `https://safebooru.org`）
3. 点击 **检测引擎** 自动识别 Booru 类型
4. 填写名称后保存

### Hosts 域名映射

适用于网络受限环境。在 **设置 → Hosts** 中添加规则，或导入 hosts 文件。

---

## 开源协议 / License

MIT License
