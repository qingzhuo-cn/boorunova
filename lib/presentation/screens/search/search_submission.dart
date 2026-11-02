// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

/// 搜索页回传给首页的提交内容。
///
/// 评级**必须**是结构化短码（`s`/`q`/`e`），由各引擎映射成自己的写法，
/// 不能像此前那样把 `rating:s` 当普通标签拼进查询串：
/// 实测 safebooru 上 `rating:s` 命中 0 条、`rating:safe` 命中 385 万条，
/// 于是 gelbooru/rule34/safebooru 的评级筛选永远返回空列表，用户以为
/// "真的没图"。
typedef SearchSubmission = ({String query, String? rating});
