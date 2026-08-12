# BooruNova

**一款开源的 Android 端 Booru 图站聚合浏览器。**

BooruNova 将多个 Booru 图站整合进同一个应用，用统一的搜索栏、统一的时间线、统一的收藏与下载，取代过去在多个应用和移动网页之间来回切换的体验。

---

## 核心特性

### 浏览体验

- **多站点聚合** — 一个应用浏览所有已配置的图站，长按底部站点图标即可快速切换
- **瀑布流时间线** — 2–6 列可调网格，无缝无限滚动，紧凑贴边布局
- **全屏查看器** — 双指缩放、滑动翻页、幻灯片模式，跟手下滑手势即可关闭
- **长按速览** — 网格中长按即可浮起大图预览，松手即关，无需进入详情页
- **分类标签** — 画师 / 角色 / 版权 / 通用 / 元数据，五色区分一目了然

### 搜索

- **标签自动补全** — 防抖输入，按站点缓存建议
- **热门标签** — 实时拉取当前站点的热门标签
- **搜索历史** — 保留最近 20 条查询，一键重新搜索
- **可编辑查询** — 搜索后点击搜索栏即可在原有标签基础上继续修改
- **排序与分级过滤** — 相关度 / 分数 / 日期 / 分级，直接内置于查询

### 收藏与下载

- **收藏** — 按站点独立追踪，跨应用同步
- **下载到相册** — 可选采样图或原图画质
- **批量操作** — 多选后批量收藏、下载、分享

### 个性化

- **标签黑名单** — 屏蔽不想看到的内容
- **主题** — 浅色 / 深色 / 午夜，自定义强调色
- **可配置手势** — 滑动 / 点按 / 长按动作均可自定义
- **自定义 Hosts 映射** — 在受限网络环境下访问站点

### 数据管理

- **完整备份与恢复** — 站点、收藏、历史、黑名单、设置一键导出导入
- **缓存管理** — 一键回收存储空间

---

## 支持的站点

任何运行以下引擎的站点都可以通过 URL 添加，应用会自动识别引擎类型：

| 引擎 | 示例站点 |
|------|----------|
| Danbooru | danbooru.donmai.us |
| Gelbooru (v0.2 API) | gelbooru.com |
| Moebooru | yande.re, konachan.com |
| Safebooru | safebooru.org |
| e621 | e621.net |
| Sankaku | chan.sankakucomplex.com |
| Zerochan | zerochan.net |
| Rule34 | rule34.xxx |

---

## 下载

从 [GitHub Releases](https://github.com/qingzhuo-cn/boorunova/releases) 获取最新 APK。

| ABI | 安装包 |
|-----|--------|
| arm64-v8a / x86_64（通用） | `app-release.apk` |

**系统要求：** Android 8.0（API 26）及以上

---

## 开源

BooruNova 以 [MIT 协议](LICENSE) 开源，欢迎提交 Issue 和 Pull Request。

- 源代码：https://github.com/qingzhuo-cn/boorunova
- 问题反馈：https://github.com/qingzhuo-cn/boorunova/issues
