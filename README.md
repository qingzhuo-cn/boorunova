# BooruNova

BooruNova 是一个开源的 Android Booru 图库客户端，支持 Danbooru、Gelbooru、Safebooru、Moebooru、e621、Sankaku、Zerochan、Rule34 等主流站点。

BooruNova is an open-source Android client for booru image boards, supporting Danbooru, Gelbooru, Safebooru, Moebooru, e621, Sankaku, Zerochan, Rule34, and more.

## 功能特性 / Features

### 浏览与查看 / Browsing

- 多服务器支持，一个应用浏览所有站点
- 瀑布流时间线，可调列数（2-6 列）
- 全屏查看器：双指缩放、滑动切换、自动播放
- 帖子详情：画师/角色/版权/通用标签分类展示
- Multi-server support — browse every site in one app
- Masonry grid timeline with adjustable columns (2-6)
- Full-screen viewer: pinch-zoom, swipe navigation, slideshow
- Post details with categorized tags (artist/character/copyright/general)

### 搜索 / Search

- 标签自动补全建议
- 各站点热门标签推荐
- 搜索历史管理（最近 20 条）
- Tag autocomplete suggestions
- Trending tags from the current site
- Search history (last 20 entries)

### 收藏与下载 / Favorites & Downloads

- 收藏帖子，跨服务器独立管理
- 下载到系统相册，支持预览图/原图切换
- 批量收藏、批量下载、批量分享
- Favorite posts with per-server tracking
- Download to gallery with sample/original quality toggle
- Batch favorite, download, and share

### 个性化 / Personalization

- 标签屏蔽（黑名单）
- 浅色/深色/午夜主题，自定义强调色
- 可配置手势（滑动/点击/长按）
- Hosts 域名映射，应对网络受限环境
- Tag blocking (blacklist)
- Light/dark/midnight themes with custom accent colors
- Configurable gestures (swipe/tap/long-press)
- Custom Hosts domain mapping for restricted networks

### 数据管理 / Data Management

- 完整备份/恢复（服务器、收藏、历史、设置等 6 类数据）
- 缓存清理
- Full backup/restore (servers, favorites, history, settings, etc.)
- Cache management

## 下载 / Download

从 [GitHub Releases](https://github.com/qingzhuo-cn/boorunova/releases) 下载最新 APK。

Download the latest APK from [GitHub Releases](https://github.com/qingzhuo-cn/boorunova/releases).

## 快速开始 / Getting Started

### 环境要求 / Prerequisites

- Flutter SDK >= 3.0.3
- Android SDK

### 安装 / Installation

```bash
git clone https://github.com/qingzhuo-cn/boorunova.git
cd boorunova
flutter pub get
flutter run
```

### 构建 Release / Build

```bash
flutter build apk --release --target-platform android-arm64
```

## 使用说明 / Usage

### 添加服务器 / Adding a Server

1. 在「服务器」页面点击 **+** 按钮
2. 输入站点地址（如 `https://safebooru.org`）
3. 点击「探测」自动匹配引擎类型
4. 确认引擎类型，填写名称后保存
5. Tap **+** on the Servers page, enter a site URL, tap **探测** to auto-detect the engine, then save.

### 排序服务器 / Reordering Servers

在服务器页右上角点击排序按钮，进入拖拽排序模式。

Tap the sort button in the top-right corner of the Servers page to enter drag-reorder mode.

## 支持站点 / Supported Sites

| 引擎 | 站点示例 |
|------|----------|
| Danbooru | danbooru.donmai.us |
| Gelbooru | gelbooru.com |
| Moebooru | yande.re / konachan.com |
| Safebooru | safebooru.org |
| e621 | e621.net |
| Sankaku | chan.sankakucomplex.com |
| Zerochan | zerochan.net |
| Rule34 | rule34.xxx |

## 开源协议 / License

MIT License
