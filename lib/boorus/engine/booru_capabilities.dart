// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

/// 引擎能力声明：控制 UI 显隐，避免给不支持的站点展示无效入口。
///
/// 字段只保留**真正被消费**的那些。历史上这里有 11 个字段，其中
/// comments / notes / voting / characterPages / videoSupport / tagTranslation /
/// syntaxHighlighting / bulkDownload 八个零消费点——声明了但没有任何 UI 读
/// 它们。留着会让人误以为这些能力已经接好，也让「这个引擎到底支持什么」
/// 变得无法一眼读完。
///
/// 单页上限（maxPageSize）**刻意不在这里**：那是仓库对端点参数上限的知识，
/// 已经声明在 `BaseBooruRepository.maxPageSize` 上，并直接参与 clampLimit。
/// 同一件事声明两处必然分叉。
/// 安全模式是否**禁止**浏览这个引擎。
///
/// 抽成纯函数是为了能单测：这条判断决定「Play 版用户看到内容还是看到说明页」，
/// 而它的两个输入（设置项、引擎能力）都来自别处。
bool safeModeBlocksBrowsing({
  required bool safeMode,
  required BooruCapabilities capabilities,
}) =>
    safeMode && !capabilities.ratingFilter;

class BooruCapabilities {
  const BooruCapabilities({
    this.pools = false,
    this.auth = false,
    this.ratingFilter = true,
  });

  /// 支持图集（fetchPools 有实现）。
  final bool pools;

  /// 站点用得到凭据（API Key / 登录名）。
  ///
  /// 为 false 时服务器编辑页**不显示**凭据输入框：填了也不会有任何效果，
  /// 展示出来只会让用户以为自己配错了。默认 false——凭据输入是少数引擎的
  /// 特性，需要它的引擎显式声明。
  final bool auth;

  /// 站点支持按评级过滤查询。
  ///
  /// 为 false 的引擎（视频站、zerochan、shimmie2）**忽略** `BooruQuery.rating`：
  /// 用户选了「安全」却照样拿到限制级内容。所以：
  /// - 搜索页不显示评级下拉（不再给一个无效选项）；
  /// - 安全模式（Play 合规）下这类站点**禁止浏览**，而不是假装过滤了。
  final bool ratingFilter;
}
