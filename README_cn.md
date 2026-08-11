<div align="center">

<p align="center"><img width="1000px" alt="BooruNova banner" src="docs/assets/banner.svg"></p>

# BooruNova [![Awesome](https://awesome.re/badge-flat.svg)](https://awesome.re)

**一个客户端，浏览所有图站。** 开源的 Android Booru 图库客户端。

[English](README.md) / 简体中文

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%208.0%2B-green.svg)](https://github.com/qingzhuo-cn/boorunova/releases)
[![Language](https://img.shields.io/badge/language-Dart%20%2F%20Flutter-0175C2.svg)](https://flutter.dev)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Release](https://img.shields.io/github/v/release/qingzhuo-cn/boorunova)](https://github.com/qingzhuo-cn/boorunova/releases)

</div>

## 目录

- [为什么做 BooruNova](#为什么做-boorunova)
- [功能特性](#功能特性)
- [支持站点](#支持站点)
- [下载](#下载)
- [快速开始](#快速开始)
- [使用说明](#使用说明)
- [实现原理](#实现原理)
- [开发](#开发)
- [相关项目](#相关项目)
- [开源协议](#开源协议)

## 为什么做 BooruNova

在多个 booru 图站之间切换，通常意味着同时装好几个应用，或者忍受难用的移动网页——每家的搜索语法、标签布局、怪癖都不一样。BooruNova 的目标是做一个统一、快速、原生的客户端，说遍所有主流 booru 引擎的「语言」：一个搜索框、一条时间线、一个收藏与下载的家。

## 功能特性

### 浏览
- 🖼️ **多服务器支持** —— 一个应用浏览所有已配置站点
- 🌊 **瀑布流时间线** —— 可调列数（2–6 列），无缝无限滚动
- 🔍 **全屏查看器** —— 双指缩放、滑动切换、幻灯片播放
- 🏷️ **标签分类** —— 画师 / 角色 / 版权 / 通用 / 元信息

### 搜索
- ✨ **标签自动补全** —— 防抖处理，按站点缓存的建议
- 🔥 **热门标签** —— 实时取自当前站点
- 🕘 **搜索历史** —— 最近 20 条，一键重搜
- 🎚️ **排序与分级筛选** —— 相关度 / 分数 / 日期 / 分级，自动拼入查询

### 收藏与下载
- ⭐ **收藏** —— 按站点独立追踪
- 💾 **下载到相册** —— 预览图 / 原图画质可选
- 📦 **批量操作** —— 批量收藏、下载、分享

### 个性化
- 🚫 **标签黑名单** —— 屏蔽不想看到的内容
- 🎨 **主题** —— 浅色 / 深色 / 午夜，自定义强调色
- 👆 **手势配置** —— 滑动 / 点击 / 长按行为自定义
- 🌐 **Hosts 域名映射** —— 网络受限环境下直连站点

### 数据管理
- 🗄️ **完整备份与恢复** —— 服务器、收藏、历史、黑名单、设置等 6 类数据
- 🧹 **缓存清理** —— 一键释放存储

## 支持站点

任何运行以下引擎的站点都可以通过 URL 添加——应用会自动探测引擎类型：

| 引擎 | 站点示例 |
|------|----------|
| Danbooru | danbooru.donmai.us |
| Gelbooru（v0.2 API） | gelbooru.com |
| Moebooru | yande.re、konachan.com |
| Safebooru | safebooru.org |
| e621 | e621.net |
| Sankaku | chan.sankakucomplex.com |
| Zerochan | zerochan.net |
| Rule34 | rule34.xxx |

## 下载

从 [GitHub Releases](https://github.com/qingzhuo-cn/boorunova/releases) 下载最新 APK。

| ABI | 安装包 |
|-----|--------|
| arm64-v8a / x86_64（通用） | `app-release.apk` |

## 快速开始

### 环境要求

| 依赖 | 版本 |
|------|------|
| Flutter SDK | >= 3.10.4 |
| Dart | >= 3.0.3 |
| Android SDK | API 26+ |

### 从源码运行

```bash
git clone https://github.com/qingzhuo-cn/boorunova.git
cd boorunova
flutter pub get
flutter run
```

### 构建 Release 包

```bash
flutter build apk --release
```

产物位于 `build/app/outputs/flutter-apk/app-release.apk`。

## 使用说明

### 添加服务器

| 步骤 | 操作 |
|------|------|
| 1 | 打开「服务器」页，点击 **+** |
| 2 | 输入站点地址（如 `https://safebooru.org`） |
| 3 | 点击「探测」自动匹配引擎 |
| 4 | 确认引擎类型，命名后保存 |

### 排序服务器

点击服务器页右上角的排序按钮进入拖拽排序模式，随心拖动。

### 搜索

输入标签后从实时建议中选取；也可以配合工具栏的排序 / 分级筛选（`order:score`、`rating:s` 等），它们会自动拼入查询。

## 实现原理

```
┌─────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  UI（Riverpod）│──▶│  BooruRegistry    │──▶│  引擎（8 个实现）│
│  页面 / 组件   │    │  createRepository │   │  站点级 repo     │
└─────────────┘    └──────────────────┘    └────────┬────────┘
                                                    │
                          ┌─────────────────────────┘
                          ▼
                   ┌──────────────┐    ┌──────────────┐
                   │  BaseBooru    │──▶│   Parser      │──▶ BooruPost
                   │  Repository   │   │（各引擎实现）  │
                   │（dio+server） │   └──────────────┘
                   └──────┬───────┘
                         │
                   ┌─────▼──────┐
                   │ DioFactory │──▶ hosts 拦截、超时、UA 统一配置
                   └────────────┘
```

每个引擎只是一个薄薄的 `BaseBooruRepository` 子类——只需声明端点和解析器。网络层（超时、hosts 重映射、认证头）集中在 `DioFactory`，一处修复全网生效。

## 开发

| 任务 | 命令 |
|------|------|
| 静态分析 | `flutter analyze` |
| 运行测试 | `flutter test` |
| 新增引擎 | 继承 `BaseBooruRepository`，在 `BooruRegistry` 注册 |

解析层由 fixture 驱动的单元测试覆盖（`test/boorus/`）——每个引擎的 parser 都会用真实形态的响应和畸形输入用例双重验证。

## 相关项目

- [Boorusphere](https://github.com/nullxception/boorusphere) —— UI/交互灵感
- [Boorusama](https://github.com/khoadng/Boorusama) —— 功能与设置灵感
- [awesome-booru](https://awesome.re) —— booru 生态

## 开源协议

[MIT](LICENSE) © BooruNova 贡献者
