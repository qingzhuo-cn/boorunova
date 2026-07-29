# BooruNova

一个基于 Flutter 的 Android Booru 客户端

A Flutter-based booru client for Android

---

## Features

- **Multi-server Support** — Danbooru, Gelbooru, Safebooru, Moebooru, e621, Sankaku, Zerochan, Rule34, etc.
- **Server Management** — Add/edit/delete servers, auto-detect engine type, preset templates
- **Post Timeline** — Masonry grid layout with adjustable columns (2-6), staggered entry animations
- **Post Viewer** — Full-screen image viewer with pinch-to-zoom, slideshow, swipe navigation
- **Post Details** — Categorized tags (artist/character/copyright/general/meta), multi-select, SpeedDial FAB
- **Search** — Bottom search bar with autocomplete, trending tags from site, search history
- **Favorites & Downloads** — Save posts to favorites, download images to gallery
- **Tags Blocker** — Block unwanted tags from timeline
- **Hosts** — Custom domain-to-IP mapping for network-restricted environments
- **Gesture Controls** — Configurable swipe/tap/double-tap/long-press actions
- **Themes** — Light/dark/midnight modes with accent color picker
- **Navigation** — Left drawer (favorites/downloads/servers/settings), right drawer
- **Chinese UI** — Full Chinese language interface

## 功能特点

- **多服务器支持** — Danbooru、Gelbooru、Safebooru、Moebooru、e621、Sankaku、Zerochan、Rule34 等
- **服务器管理** — 添加/编辑/删除服务器，自动检测引擎类型，内置模板快速添加
- **帖子时间线** — 瀑布流布局，可调节列数（2-6），交错入场动画
- **查看器** — 全屏图片浏览，双指缩放，幻灯片模式，滑动切换
- **帖子详情** — 分类标签（画师/角色/版权/通用/元数据），多选，SpeedDial 操作按钮
- **搜索** — 底部搜索栏，标签自动补全，站点热门标签，搜索历史
- **收藏与下载** — 收藏帖子，下载图片到相册
- **标签屏蔽** — 屏蔽不想要的标签，管理黑名单
- **Hosts** — 自定义域名到 IP 映射，适用于网络受限环境
- **手势控制** — 可配置滑动/点击/双击/长按动作
- **主题** — 浅色/深色/午夜模式，强调色自定义
- **导航** — 左侧抽屉（收藏/下载/服务器/设置），右侧抽屉
- **中文界面** — 完整中文语言界面

---

## Screenshots / 截图

Coming soon / 即将添加

---

## Getting Started / 快速开始

### Prerequisites / 环境要求

- Flutter SDK >=3.0.3
- Android SDK

### Installation / 安装运行

```bash
git clone https://github.com/qingzhuo-cn/boorunova.git
cd boorunova
flutter pub get
flutter run
```

### Build Release APK / 构建

```bash
flutter build apk --release --target-platform android-arm64
```

Or download the latest APK from [GitHub Releases](https://github.com/qingzhuo-cn/boorunova/releases) / 或从 [GitHub Releases](https://github.com/qingzhuo-cn/boorunova/releases) 直接下载。

---

## Configuration / 配置说明

### Adding a Server / 添加服务器

1. Tap **+** FAB on the Servers page / 在服务器页面点击 **+** 悬浮按钮
2. Enter site URL (e.g. `https://safebooru.org`) / 输入站点地址
3. Tap **检测引擎** (Detect Engine) / 点击检测引擎自动识别
4. Name and save / 填写名称后保存

### Hosts

For restricted networks, add rules in **Settings → Hosts** or import a hosts file.

网络受限环境下，在 **设置 → Hosts** 中添加规则或导入 hosts 文件。

---

## License / 开源协议

MIT License
