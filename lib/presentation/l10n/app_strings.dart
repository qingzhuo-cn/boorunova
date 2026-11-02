// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:dio/dio.dart';

/// 全应用文案（中 / 英双语）。
///
/// 所有 getter 按 [T.isEn] 返回对应语言。切换语言时除了更新
/// [T.isEn]，必须让整棵组件树重建才会刷新——BooruNova 在
/// MaterialApp 上以 locale 作为 key 强制整体重建。
/// 注意：因为返回值不再是编译期常量，包含 `T.x` 的 `const` 表达式
/// 一律不能再加 const。
class T {
  T._();

  /// 当前是否英文。由 AppSettings.language 驱动，启动与切换时赋值。
  static bool isEn = false;

  static void setLocale(String languageCode) {
    isEn = languageCode.startsWith('en');
  }

  // App
  static String get appTitle => _t('BooruNova', 'BooruNova');

  // 启动失败降级页（Hive 打不开时唯一能显示的界面，不能依赖任何 provider）
  static String get bootFailedTitle => _t('本地数据打不开', 'Local data unavailable');
  static String get bootFailedHint => _t(
      '应用数据文件可能已损坏或被占用。可尝试重启应用；若仍无法启动，请在系统设置里清除应用数据后重新添加站点。',
      'The app data files may be corrupted or locked. Try restarting; if it still fails, clear app data in system settings and add your sites again.');
  static String get recoveredDataHint => _t(
      '检测到本地数据损坏，已隔离损坏文件并重建（原文件保留在应用目录，后缀 .corrupt）。',
      'Local data was corrupted. The damaged file was quarantined (.corrupt suffix) and storage was rebuilt.');

  // Onboarding
  static String get obWelcome => _t('欢迎使用 BooruNova', 'Welcome to BooruNova');
  static String get obWelcomeSubtitle => _t(
      '一个应用，浏览所有 Booru 图站。先选择语言，再添加你想浏览的站点。',
      'One app for every booru. Pick a language, then add the sites you want to browse.');
  static String get obChooseLanguage => _t('选择语言', 'Choose language');
  static String get obChooseSites => _t('添加站点', 'Add sites');
  static String get obChooseSitesSubtitle => _t(
      '勾选想浏览的站点，之后可以随时在「服务器」中添加或删除。',
      'Pick the sites you want to browse. You can add or remove more later in Servers.');
  static String get obSiteAuthNote => _t(
      '部分站点（如 Gelbooru / Rule34）之后需要在其编辑页填写 API Key 才能使用图集等功能。',
      'Some sites (e.g. Gelbooru / Rule34) need an API Key later in their editor for pools and more.');
  static String get obStart => _t('开始使用', 'Get started');
  static String get obSkip => _t('跳过', 'Skip');
  static String get obNext => _t('下一步', 'Next');
  static String get langSystemName => _t('跟随系统', 'Follow system');
  static String get langSystemSub => _t(
      '按系统语言自动选择（仅区分英文与中文）',
      'Match the system language (English or Chinese)');
  static String get langZhName => _t('简体中文', '简体中文');
  static String get langZhSub => _t('当前语言', 'Current language');
  static String get langEnName => _t('English', 'English');
  static String get langEnSub => _t('切换界面语言', 'Switch UI language');

  // Home
  static String get searchHint => _t('搜索...', 'Search...');
  static String get tapToSearch => _t('点击搜索', 'Tap to search');
  static String get noPostsYet => _t('暂无帖子', 'No posts yet');
  static String get noSearchResults => _t('没有找到帖子', 'No posts found');
  static String get addBooruServer =>
      _t('添加一个 Booru 服务器开始浏览', 'Add a booru server to start browsing');
  static String get addServer => _t('添加服务器', 'Add server');
  static String get tryDifferentSearch =>
      _t('换一个关键词试试，或清除筛选条件', 'Try another keyword or clear the filters');
  static String get engineNotAvailable => _t('引擎不可用：', 'Engine unavailable: ');
  static String get switchServerTip => _t('点击切换站点', 'Tap to switch site');
  static String get onlyOneServerHint =>
      _t('只有一个站点，先去添加更多站点吧', 'Only one site so far. Add more to switch between them.');
  static String get favorites => _t('收藏', 'Favorites');
  static String get history => _t('历史', 'History');
  static String get settings => _t('设置', 'Settings');
  static String get servers => _t('服务器', 'Servers');
  static String get downloads => _t('下载', 'Downloads');
  static String get results => _t('结果', 'results');
  static String get selected => _t('已选', 'selected');

  /// 瀑布流瓦片的读屏标签（OPT §5.2）。
  ///
  /// 此前瓦片对读屏用户是「一张图」，连「可以点开」都听不出来。视频帖额外
  /// 说明一下，因为它们的打开行为与图片不同（进入播放器）。
  static String viewPostSemantics(String postId, {bool isVideo = false}) =>
      isVideo
          ? _t('查看视频帖 $postId', 'View video post $postId')
          : _t('查看帖子 $postId', 'View post $postId');
  static String selectionCountSemantics(int count) =>
      _t('已选 $count 张', '$count selected');
  static String get selectAll => _t('全选', 'Select all');
  static String get clear => _t('清除', 'Clear');
  static String get clearFilters => _t('清除筛选', 'Clear filters');
  static String get filters => _t('筛选', 'Filters');
  static String get sortBy => _t('排序方式', 'Sort by');
  static String get ratingFilter => _t('分级筛选', 'Rating filter');
  static String get all => _t('全部', 'All');
  static String get safe => _t('安全', 'Safe');
  static String get questionable => _t('可疑', 'Questionable');
  static String get explicit => _t('限制级', 'Explicit');
  static String get sortColon => _t('排序：', 'Sort: ');
  static String get ratingColon => _t('分级：', 'Rating: ');

  // Drawer (end drawer explore features)
  static String get blacklist => _t('黑名单', 'Blacklist');
  static String get blacklistSub => _t('屏蔽标签管理', 'Manage blocked tags');
  static String get explore => _t('探索', 'Explore');
  static String get pools => _t('图集', 'Pools');


  // Search Bar
  static String get sortRelevance => _t('相关度', 'Relevance');
  static String get sortScore => _t('分数', 'Score');
  static String get sortDate => _t('日期', 'Date');
  static String get sortRating => _t('分级', 'Rating');

  // Post Viewer
  static String get share => _t('分享', 'Share');
  static String get savedToGallery => _t('已保存到相册', 'Saved to gallery');
  static String get downloadFailed => _t('下载失败', 'Download failed');
  static String get alreadySaved =>
      _t('已保存过，本次跳过', 'Already saved — skipped');
  static String get savedWithoutRecord => _t(
      '已存入相册，但下载记录写入失败',
      'Saved to the gallery, but the download record could not be written.');
  static String get galleryPermissionDenied => _t(
      '没有相册写入权限，下载未保存。请在系统设置里允许本应用访问存储/照片后重试。',
      'No storage permission, so nothing was saved. Allow storage/photos access in system settings and try again.');
  static String get postDetails => _t('帖子详情', 'Post details');
  static String get stopSlideshow => _t('停止自动切换', 'Stop slideshow');
  static String get autoSlideshow => _t('自动切换', 'Auto slideshow');
  static String get videoPlayFailed =>
      _t('视频无法播放', 'This video cannot be played');

  // 视频播放地址解析失败（resolved_video）：此前状态层存裸英文串
  // （'no playback source' / 'playback url not found'）再在界面上直出，
  // 中文用户看到的是看不懂的英文。原因在这里按语言给出。
  static String get videoNoSource => _t(
      '这个帖子属于另一个站点，当前无法解析播放地址',
      'This post belongs to a different site, so its playback address cannot be resolved');
  static String get videoSourceNotFound => _t(
      '没有解析到可播放的视频地址', 'No playable video address was found');
  static String get streamCannotSave =>
      _t('该视频只有流地址，无法保存到相册', 'Stream-only video cannot be saved');

  // 视频播放器控制
  static String get play => _t('播放', 'Play');
  static String get pause => _t('暂停', 'Pause');
  static String get replay => _t('重播', 'Replay');
  static String get mute => _t('静音', 'Mute');
  static String get unmute => _t('取消静音', 'Unmute');
  static String get fullscreen => _t('全屏', 'Fullscreen');
  static String get exitFullscreen => _t('退出全屏', 'Exit fullscreen');
  static String get playbackSpeed => _t('播放速度', 'Playback speed');

  // Post Detail
  static String get score => _t('分数', 'Score');

  /// 评分/数量的紧凑缩写：中文用 k / w（万），英文用 k / M（百万）。
  ///
  /// 此前固定输出 `1.2w`，英文用户不知道 w 是「万」。英文没有「万」这一档，
  /// 所以 10k–999k 必须继续用 k，只有到百万才进 M。
  static String compactScore(int score) {
    if (isEn) {
      if (score >= 1000000) return '${(score / 1000000).toStringAsFixed(1)}M';
      if (score >= 1000) return '${(score / 1000).toStringAsFixed(1)}k';
      return '$score';
    }
    if (score >= 10000) return '${(score / 10000).toStringAsFixed(1)}w';
    if (score >= 1000) return '${(score / 1000).toStringAsFixed(1)}k';
    return '$score';
  }

  static String get rating => _t('分级', 'Rating');
  static String get size => _t('尺寸', 'Dimensions');
  static String get source => _t('来源', 'Source');
  static String get postUrl => _t('帖子链接', 'Post link');
  static String get tags => _t('标签', 'Tags');
  static String get openFullViewer => _t('打开全屏查看', 'Open full viewer');
  /// 批量屏蔽一律**全局**：入口没有作用域选择，所以文案里明说，别让用户以为
  /// 它和「长按单个标签」一样能选范围。
  static String get blockTagsDone => _t('已全局屏蔽标签', 'Tags blocked everywhere');
  static String get copiedTags => _t('已复制标签', 'Tags copied');
  static String get searchAction => _t('搜索', 'Search');
  static String get appendAction => _t('追加', 'Append');
  static String get blockAction => _t('全局屏蔽', 'Block everywhere');
  static String get copyAction => _t('复制', 'Copy');

  // Favorites
  static String get noFavoritesYet => _t('还没有收藏', 'No favorites yet');
  static String get tapHeartToSave =>
      _t('在查看器中点击心形图标收藏帖子', 'Tap the heart in the viewer to save posts');

  // History
  static String get clearHistory => _t('清除历史', 'Clear history');
  static String get clearHistoryTitle => _t('清除浏览历史？', 'Clear browsing history?');
  static String get clearHistoryContent =>
      _t('这将删除所有浏览记录。', 'This will delete all browsing history.');
  static String get noHistory => _t('暂无浏览历史', 'No browsing history');
  static String get historyHint =>
      _t('看过的帖子会出现在这里，点一下就能回到那张图', 'Posts you have viewed show up here. Tap one to go back to it.');
  static String get browseNow => _t('去逛逛', 'Browse now');
  static String get justNow => _t('刚刚', 'just now');
  static String get minutesAgo => _t('分钟前', 'm ago');
  static String get hoursAgo => _t('小时前', 'h ago');
  static String get daysAgo => _t('天前', 'd ago');
  static String get cancel => _t('取消', 'Cancel');

  // Downloads
  static String get clearDownloadHistory => _t('清除下载历史', 'Clear download history');
  static String get clearDownloadHistoryTitle =>
      _t('清除下载历史？', 'Clear download history?');
  static String get clearDownloadHistoryContent => _t(
      '删除下载历史记录，已下载的图片仍保留在相册中。',
      'Deletes the download log. Images already saved stay in your gallery.');
  static String get downloadsHint =>
      _t('下载过的图会列在这里，点一下可以预览', 'Downloaded images show up here. Tap one to preview.');
  static String get openFile => _t('用其他应用打开', 'Open with another app');
  static String get fileUnavailable =>
      _t('文件已不存在，可能被系统清理了', 'File is gone. It may have been cleaned up by the system.');
  static String get removedFromDownloads =>
      _t('已从下载记录中移除', 'Removed from downloads');
  static String get noDownloadsYet => _t('还没有下载', 'No downloads yet');
  static String get tapDownloadToSave =>
      _t('在查看器中点击下载按钮保存图片', 'Tap the download button in the viewer to save images');

  // Batch
  static String get downloadSelected => _t('下载选中', 'Download selected');
  static String get favoriteSelected => _t('收藏选中', 'Favorite selected');
  static String get shareSelected => _t('分享选中', 'Share selected');
  static String get clearSelection => _t('清除选择', 'Clear selection');
  static String get downloadedCount => _t('已下载', 'Downloaded');
  static String get ofImages => _t('张图片', 'images');
  static String get addedToFavorites => _t('已添加到收藏', 'Added to favorites');

  // Settings - main page
  static String get sectionGeneral => _t('通用', 'General');
  static String get sectionBrowsing => _t('浏览', 'Browsing');
  static String get sectionData => _t('数据', 'Data');
  static String get sectionServer => _t('服务器', 'Servers');
  static String get sectionOther => _t('其他', 'Other');
  static String get appearanceSub => _t('主题、颜色', 'Theme, colors');
  static String get language => _t('语言', 'Language');
  static String get languageSub => _t('界面语言', 'UI language');
  static String get viewerEntry => _t('图片查看器', 'Image viewer');
  static String get viewerEntrySub => _t('滑动、幻灯片、视频', 'Swipe, slideshow, video');
  static String get gestures => _t('手势', 'Gestures');
  static String get gesturesSub => _t('滑动、点击、长按动作', 'Swipe, tap and long-press actions');
  static String get searchEntry => _t('搜索', 'Search');
  static String get searchEntrySub => _t('搜索选项、过滤', 'Search options, filters');
  static String get searchHistoryEntry => _t('搜索历史', 'Search history');
  static String get searchHistoryEntrySub => _t('查看管理搜索记录', 'View and manage search history');
  static String get downloadEntry => _t('下载', 'Download');
  static String get downloadEntrySub => _t('下载路径、质量', 'Download path, quality');
  static String get dataAndStorage => _t('数据与存储', 'Data & storage');
  static String get dataAndStorageSub => _t('缓存管理、存储空间', 'Cache management, storage');
  static String get backup => _t('备份恢复', 'Backup & restore');
  static String get backupSub => _t('导出/导入数据', 'Export / import data');
  static String get serverManage => _t('服务器管理', 'Server management');
  static String get serverManageSub => _t('添加、编辑、排序', 'Add, edit, reorder');
  static String get hostsEntrySub => _t('自定义域名映射', 'Custom domain mapping');

  // Appearance
  static String get themeMode => _t('主题模式', 'Theme mode');
  /// 「跟随系统」在系统为深色时使用午夜观感——这是刻意设计，写成一行说明，
  /// 免得用户以为「跟随系统」和「深色」是同一个东西却长得不一样是 bug。
  static String get themeModeSystemNote => _t(
      '「跟随系统」在系统为深色时使用午夜观感；「深色」是普通深色。',
      'When the system is dark, “System” uses the midnight look; “Dark” is the regular dark theme.');
  static String get accentColor => _t('主题色', 'Accent color');
  static String get reduceAnimations => _t('减少动画', 'Reduce animations');
  static String get reduceAnimationsSub =>
      _t('提升低端设备流畅度', 'Better performance on low-end devices');
  static String get modeSystem => _t('系统', 'System');
  static String get modeLight => _t('浅色', 'Light');
  static String get modeDark => _t('深色', 'Dark');
  static String get modeMidnight => _t('午夜', 'Midnight');

  // Viewer settings
  static String get sectionSwipe => _t('滑动', 'Swipe');
  static String get horizontalSwipe => _t('水平滑动', 'Horizontal swipe');
  static String get horizontalSwipeSub =>
      _t('关闭则使用垂直滑动切换图片', 'When off, swipe vertically to switch images');
  static String get sectionSlideshow => _t('幻灯片', 'Slideshow');
  static String get autoInterval => _t('自动播放间隔', 'Auto-advance interval');
  static String get seconds => _t('秒', 's');
  static String get increase => _t('增加', 'Increase');
  static String get decrease => _t('减少', 'Decrease');

  // Gestures
  static String get sectionViewer => _t('图片查看器', 'Image viewer');
  static String get swipeDownAction => _t('下滑动作', 'Swipe down');
  static String get tapAction => _t('单击图片', 'Single tap');
  static String get doubleTapAction => _t('双击图片', 'Double tap');
  static String get addedToFavoritesShort => _t('已收藏', 'Added to favorites');
  static String get removedFromFavorites => _t('已取消收藏', 'Removed from favorites');
  static String get swipeDownNeedsHorizontal =>
      _t('仅在「横向翻页」模式下生效', 'Only applies in horizontal paging mode');
  static String get longPressAction => _t('长按图片', 'Long press');
  static String get actionClose => _t('关闭', 'Close');
  static String get actionDetail => _t('查看详情', 'View details');
  static String get actionNone => _t('无', 'None');
  static String get actionFav => _t('收藏', 'Favorite');

  /// 瓦片上的收藏按钮读屏标签（OPT §5.2）：状态不同，说法也该不同，
  /// 否则读屏用户听到「收藏」却不知道点下去是加还是取消。
  static String favoriteToggleSemantics(bool isFavorite) => isFavorite
      ? _t('取消收藏', 'Remove from favorites')
      : _t('收藏这张', 'Add to favorites');
  static String get actionZoom => _t('缩放', 'Zoom');

  // Language page
  static String get currentLanguage => _t('当前语言', 'Current language');

  // Search settings
  static String get sectionTagSuggest => _t('标签建议', 'Tag suggestions');
  static String get suggestionCount => _t('建议标签数量', 'Suggestion count');
  // 英文侧不能回退空串：调用方是 '$n${T.countUnit}'，空串会渲染成
  // 「12 」这种悬空数字。给一个可读单位（items），中文保持「12 个」。
  static String get countUnit => _t('个', ' items');

  // Data storage
  static String get sectionCache => _t('缓存', 'Cache');
  static String get sectionRecords => _t('记录', 'Records');
  static String get cache => _t('缓存', 'Cache');
  static String memoryCacheUsage(String usedMb, int maxImages, int capMb) =>
      _t('$usedMb MB / 上限 $maxImages 张、$capMb MB',
          '$usedMb MB / cap $maxImages images, $capMb MB');
  static String diskCacheUsage(String usedMb, int capMb) => _t(
      '磁盘缓存 $usedMb MB（超过 $capMb MB 自动清理最旧的）',
      'Disk cache $usedMb MB (auto-evicts oldest above $capMb MB)');
  static String get imageCache => _t('图片缓存', 'Image cache');
  static String get calculating => _t('计算中...', 'Calculating...');
  static String get unknown => _t('未知', 'Unknown');
  static String get recordsUnit => _t('条记录', 'records');
  static String get filesUnit => _t('个文件', 'files');
  static String get imagesUnit => _t('张', ' images, ');
  static String get clearedCacheFiles => _t('已清除 ', 'Cleared ');
  static String get browsingHistory => _t('浏览历史', 'Browsing history');
  static String get downloadHistory => _t('下载历史', 'Download history');
  static String get clearAction => _t('清除', 'Clear');

  // Download settings
  static String get sectionQuality => _t('质量', 'Quality');
  static String get sectionPath => _t('路径', 'Path');
  static String get downloadQuality => _t('下载质量', 'Download quality');
  static String get qualitySample => _t('预览', 'Sample');
  static String get qualityOriginal => _t('原图', 'Original');
  static String get downloadPath => _t('下载路径', 'Download path');
  static String get defaultPathPrefix => _t('默认: ', 'Default: ');
  static String get resetDefaultPath => _t('重置为默认路径', 'Reset to default path');
  static String get downloadSettingsTitle => _t('下载设置', 'Download settings');

  // Search history page
  static String get searchHistoryTitle => _t('搜索历史', 'Search history');
  static String get noSearchHistory => _t('暂无搜索历史', 'No search history');
  static String get searchHistoryHint =>
      _t('在首页搜索过的关键词会出现在这里', 'Keywords you search on the home page appear here');
  static String get clearSearchHistoryTip => _t('清空搜索历史', 'Clear search history');
  static String get deleteAction => _t('删除', 'Delete');

  // Backup
  static String get backupTitle => _t('数据备份恢复', 'Backup & restore');
  static String get backupContentHeader => _t('备份内容', 'Backup content');
  static String get serversCountUnit => _t(' 个', ' servers');
  static String get exportBackup => _t('导出备份', 'Export backup');
  static String get exportBackupSub => _t('保存为 JSON 文件', 'Save as JSON file');
  static String get importBackup => _t('导入备份', 'Import backup');
  static String get importBackupSub => _t('从 JSON 文件恢复', 'Restore from a JSON file');
  static String get backupImported => _t('备份已导入', 'Backup imported');
  static String get importFailed => _t('导入失败', 'Import failed');
  static String get exportFailed => _t('导出失败', 'Export failed');
  static String get exportedTo => _t('已导出: ', 'Exported: ');
  static String get backupShared => _t(
      '已调起分享面板，请选择保存位置或发送方式',
      'Share sheet opened — pick where to save or send it.');
  static String get confirmAction => _t('确认', 'Confirm');
  static String backupVersionTooNew(int supported) => _t(
      '备份版本过新，当前应用最高支持 v$supported',
      'Backup is from a newer version; this app supports up to v$supported');
  static String get unsavedChanges => _t('未保存的更改', 'Unsaved changes');
  static String get importConfirmTitle => _t('确认导入备份？', 'Import this backup?');
  static String get importConfirmBody => _t(
      '导入会：合并服务器 / 收藏 / 下载记录 / 浏览历史 / Hosts（同名保留较新的一条），并**覆盖**设置与搜索历史。此操作不可撤销。',
      'Importing will merge servers, favorites, downloads, browsing history and hosts (keeping the newer copy), and OVERWRITE settings and search history. This cannot be undone.');
  static String get skippedRecords => _t('跳过', 'skipped');

  // Privacy
  static String get privacyTitle => _t('隐私', 'Privacy');
  static String get sectionDataManage => _t('数据管理', 'Data management');
  static String get clearSearchHistory => _t('清除搜索历史', 'Clear search history');
  static String get clearSearchHistorySub =>
      _t('删除所有搜索关键词记录', 'Delete all saved search keywords');
  static String get clearViewHistory => _t('清除浏览历史', 'Clear browsing history');
  static String get clearViewHistorySub => _t('删除所有浏览记录', 'Delete all viewing history');
  static String get clearDownloadRecords => _t('清除下载记录', 'Clear download records');
  static String get clearDownloadRecordsSub => _t(
      '删除下载历史（已保存的图片不受影响）',
      'Delete the download log (saved images are not affected)');
  // 安全模式 / 年龄确认（Play 合规：首启即安全口径）
  static String get safeModeTitle => _t('安全模式', 'Safe mode');
  static String get safeModeSubOn => _t(
      '浏览时只取安全档内容（各站点按自己的口径映射）',
      'Browsing only requests safe-rated content (mapped per site)');
  static String get safeModeSubOff => _t(
      '已关闭：可能显示成人内容', 'Off: adult content may appear');
  static String get ageGateTitle => _t('确认年龄', 'Confirm your age');
  static String get ageGateBody => _t(
      '关闭安全模式后可能看到成人内容。请确认你已达到所在地区的法定成年年龄；本确认只保存在本机，不上传。',
      'Turning safe mode off may show adult content. Please confirm you are of legal age where you live. This confirmation is stored only on this device and is never uploaded.');
  static String get ageGateConfirm => _t('我已成年，继续', 'I am of legal age, continue');

  // 内容来源与举报（IFF：可屏蔽 / 可举报 / 有申诉）
  static String get contentSourceEntry => _t('内容来源与举报', 'Content sources & reporting');
  static String get contentSourceSub => _t(
      '本应用不提供任何内容来源', 'This app ships with no content sources');
  static String get contentSourceIntro => _t(
      '本应用是一个空白客户端：它不内置、不推荐、也不链接任何站点。你看到的所有内容都来自**你自己添加的服务器**，应用只是按你填写的地址去请求它们。',
      'This app is a blank client: it bundles, recommends and links no sites. Everything you see comes from the servers YOU added — the app only requests the addresses you typed in.');
  static String get contentSourceServersHeader => _t('你添加的服务器', 'Servers you added');
  static String get contentSourceServersHint => _t(
      '内容来自这些服务器。点一条可在浏览器中打开该站，使用它自己的举报入口。',
      'Content comes from these servers. Tap one to open it in a browser and use that site\'s own reporting entry.');
  static String get contentSourceBlockHeader => _t('屏蔽内容', 'Blocking content');
  static String get contentSourceBlockBody => _t(
      '标签黑名单可以屏蔽特定标签（首页、探索、图集都生效）；移除服务器则会彻底断开该站的一切访问。',
      'The tag blacklist hides specific tags (applies to home, explore and pools). Removing a server cuts off all access to that site.');
  static String get contentSourceReportHeader => _t('举报内容', 'Reporting content');
  static String get contentSourceReportBody => _t(
      '内容托管在你添加的服务器上，因此举报的正确去向是该站自身的举报入口（在上面的列表里打开站点，找到对应的帖子/图片并使用站内举报）。应用自身不托管、不中转任何内容。',
      'Content is hosted by the servers you added, so reports belong to that site\'s own reporting entry (open it above, find the post and use the site\'s report action). This app hosts and relays nothing.');
  static String get contentSourceAppealHeader => _t('联系我们', 'Contact');
  static String get contentSourceAppealBody => _t(
      '对本应用本身的问题（功能、合规、申诉），请通过应用商店页面公示的开发者联系方式联系。',
      'For issues with this app itself (features, compliance, appeals), use the developer contact published on the app store listing page.');
  static String get openInBrowser => _t('在浏览器中打开', 'Open in browser');
  static String get noServerToOpen => _t('还没有添加任何服务器', 'No servers added yet');

  // 安全模式与引擎能力冲突（引擎不支持按评级过滤）
  static String get safeModeBlockedTitle =>
      _t('该站点不支持评级过滤', 'This site cannot filter by rating');
  static String get safeModeBlockedBody => _t(
      '安全模式只放行安全档内容，而当前站点（视频站 / zerochan / shimmie2 一类）不支持按评级查询——继续浏览等于把安全模式当摆设。请切换到支持评级过滤的站点，或关闭安全模式（需先确认年龄）。',
      'Safe mode only allows safe-rated content, but the current site (video sites, zerochan, shimmie2 and the like) cannot query by rating — browsing it would make safe mode meaningless. Switch to a site that supports rating filters, or turn safe mode off (age confirmation required).');
  static String get openServers => _t('切换站点', 'Switch site');
  static String get openSafeModeSettings => _t('安全模式设置', 'Safe mode settings');

  /// 限流等待提示（OPT §3.8）：告诉用户为什么进度不动、以及会自动继续。
  static String rateLimitedRetry(int seconds) => _t(
      '服务器限流，$seconds 秒后自动重试',
      'Server is rate limiting; retrying in $seconds s');
  /// 未完成下载的续跑提示（OPT §3.3）。
  static String get resumeDownloadsTitle =>
      _t('有未完成的下载', 'Unfinished downloads');
  static String resumeDownloadsBody(int count) => _t(
      '上次有 $count 个下载没完成，要继续吗？（已下载的部分会接着下）',
      '$count download(s) were left unfinished. Continue? (partial files resume)');
  static String get resumeAction => _t('继续', 'Continue');
  static String get ignoreAction => _t('忽略', 'Ignore');
  static String get downloadStalled => _t(
      '下载超时：服务端长时间没有数据，请重试',
      'Download timed out: the server sent no data for a while, please retry');

  static String get sectionPrivacyNote => _t('隐私声明', 'Privacy notes');
  static String get dataCollection => _t('数据收集', 'Data collection');
  static String get dataCollectionSub => _t(
      'BooruNova 不会收集或上传任何个人信息。所有数据（设置、收藏、历史记录）仅存储在本地设备中。',
      'BooruNova never collects or uploads personal data. Everything (settings, favorites, history) stays on this device.');
  static String get networkRequests => _t('网络请求', 'Network requests');
  static String get networkRequestsSub => _t(
      '仅在你主动浏览、搜索和下载时向 Booru 服务器发起请求，不会连接第三方分析或追踪服务。',
      'Requests are only made to booru servers when you browse, search or download. No third-party analytics or tracking.');
  static String get searchHistoryCleared =>
      _t('搜索历史已清除', 'Search history cleared');
  static String get viewHistoryCleared => _t('浏览历史已清除', 'Browsing history cleared');
  static String get downloadRecordsCleared =>
      _t('下载记录已清除', 'Download records cleared');

  // Settings
  static String get appearance => _t('外观', 'Appearance');
  static String get theme => _t('主题', 'Theme');
  static String get defaultServer => _t('默认服务器', 'Default server');
  static String get defaultServerSubtitle =>
      _t('启动时默认加载的服务器', 'Server loaded on startup');
  static String get chooseTheme => _t('选择主题', 'Choose theme');
  static String get system => _t('跟随系统', 'System');
  static String get light => _t('浅色', 'Light');
  static String get dark => _t('深色', 'Dark');
  static String get midnight => _t('午夜', 'Midnight');
  static String get noneAutoSelect => _t('无（自动选择第一个）', 'None (first one automatically)');
  static String get hosts => _t('Hosts', 'Hosts');
  static String get useCustomHosts => _t('使用自定义 Hosts', 'Use custom hosts');
  static String get useCustomHostsSubtitle =>
      _t('将 Booru 域名指向自定义 IP', 'Point booru domains to custom IPs');
  static String get manageHostMappings => _t('管理 Host 映射', 'Manage host mappings');
  static String get manageHostMappingsSubtitle =>
      _t('添加、编辑或删除 Host 条目', 'Add, edit or remove host entries');
  static String get dataManagement => _t('数据管理', 'Data management');
  static String get clearCache => _t('清除缓存', 'Clear cache');
  static String get clearCacheSubtitle => _t('删除已下载的图片缩略图', 'Delete downloaded thumbnails');
  static String get about => _t('关于', 'About');
  static String get aboutSub => _t('版本信息、开源许可', 'Version info, license');
  static String get privacyEntrySub => _t('隐私设置', 'Privacy settings');
  static String get openSource => _t('开源协议', 'License');
  static String get tempFiles => _t(' 个临时文件', ' temp files');
  static String get historyCleared => _t('历史已清除', 'History cleared');
  static String get downloadHistoryCleared =>
      _t('下载历史已清除', 'Download history cleared');

  // Server Page
  static String get noServersAdded => _t('还没有添加服务器', 'No servers added');
  static String get addBooruSite =>
      _t('添加一个 Booru 站点开始浏览图片', 'Add a booru site to start browsing');
  static String get myServers => _t('我的服务器', 'My servers');
  static String get editExisting => _t('编辑现有', 'Edit existing');
  static String get addAnotherHint =>
      _t('点击可再添加一个', 'Tap to add another');
  static String get popularSites => _t('热门站点', 'Popular sites');
  static String get removeServer => _t('删除服务器？', 'Remove server?');
  static String get deleteConfirm => _t('确认删除"', 'Remove "');
  static String get deleteConfirmEnd => _t('？此操作不可撤销。', '"? This cannot be undone.');
  static String get delete => _t('删除', 'Delete');
  static String get edit => _t('编辑', 'Edit');
  static String get editServer => _t('编辑服务器', 'Edit server');
  static String get addNewServer => _t('添加服务器', 'Add server');
  static String get serverName => _t('服务器名称', 'Server name');
  /// 占位示例一律用中立域名：Play 版必须零站点名，GitHub 版也没必要
  /// 把某个具体站点当成「默认答案」（BYO 模式下用户填什么就浏览什么）。
  static String get serverNameHint => _t('我的图站', 'My board');
  static String get serverUrl => _t('服务器地址', 'Server URL');
  static String get serverUrlHint =>
      _t('https://your-board.example.com', 'https://your-board.example.com');
  static String get engineType => _t('引擎类型', 'Engine type');
  static String get searchTagHint => _t('搜索标签...', 'Search tags...');
  static String get required => _t('必填', 'Required');
  static String get authenticationOptional =>
      _t('身份验证（可选）', 'Authentication (optional)');
  static String get apiKey => _t('API Key', 'API Key');
  static String get apiKeyHint => _t('如不需要请留空', 'Leave empty if not needed');
  static String get login => _t('登录名 / 用户名', 'Login / username');
  static String get loginHint => _t('如不需要请留空', 'Leave empty if not needed');
  static String get saveChanges => _t('保存修改', 'Save changes');
  static String get addServerBtn => _t('添加服务器', 'Add server');
  static String get addSite => _t('添加站点', 'Add site');
  static String get engineMatchResults => _t('引擎匹配结果', 'Engine match results');
  static String get confirmAdd => _t('确认添加', 'Confirm');
  static String get enterUrlToMatch =>
      _t('输入站点地址自动匹配引擎', 'Enter a site URL to auto-match the engine');
  static String get urlHint =>
      _t('https://your-board.example.com', 'https://your-board.example.com');
  static String get reorder => _t('排序', 'Reorder');
  static String get done => _t('完成', 'Done');
  static String get addedTag => _t('已添加', 'Added');

  // Server probe / scan
  static String get scanTitle => _t('服务器探测', 'Server probe');
  static String get scanCancel => _t('取消', 'Cancel');
  static String get scanContinue => _t('继续', 'Continue');
  static String get scanStart => _t('探测', 'Probe');
  static String get scanClose => _t('关闭', 'Close');
  static String get scanIdleHint =>
      _t('点击"探测"开始匹配引擎', 'Tap "Probe" to match an engine');

  /// 探测页的输入提示（日志区第一行）。
  static String get probeInputHint =>
      _t('输入站点地址后点击"探测"', 'Enter a site URL, then tap "Probe"');

  // Content / Browse
  static String get content => _t('内容', 'Content');
  static String get tapToView => _t('点击查看', 'Tap to view');
  static String get nsfw => _t('NSFW', 'NSFW');
  static String get noContent => _t('暂无内容', 'Nothing here yet');
  static String get poolEmpty => _t('该图集暂无内容', 'This pool is empty');

  // Hosts Page
  static String get hostsTitle => _t('Host 规则', 'Host rules');
  static String get addHost => _t('添加映射', 'Add mapping');
  static String get noHostMappings => _t('还没有 Host 规则', 'No host rules yet');
  static String get addMappingsHint =>
      _t('添加规则以通过自定义 IP 访问 Booru 站点', 'Add rules to reach booru sites via custom IPs');
  static String get addHostMapping => _t('添加 Host 规则', 'Add host rule');
  static String get domain => _t('域名', 'Domain');
  static String get domainHint =>
      _t('例如 your-board.example.com', 'e.g. your-board.example.com');
  static String get ipAddress => _t('IP 地址', 'IP address');
  static String get ipHint => _t('例如 1.2.3.4', 'e.g. 1.2.3.4');
  static String get add => _t('添加', 'Add');
  static String get hostsEditorHint => _t('每行一条规则：IP 域名', 'One rule per line: IP domain');
  static String get hostsEditorExample => _t(
      '# 注释行以 # 开头\n# 格式: IP 域名\n1.2.3.4 your-board.example.com',
      '# Lines starting with # are comments\n# Format: IP domain\n1.2.3.4 your-board.example.com');
  static String get hostsParsed => _t('解析到 ', 'Parsed ');
  static String get hostsRules => _t(' 条规则', ' rules');
  static String get importHostsFile => _t('导入 Hosts 文件', 'Import hosts file');
  static String get importSuccess => _t('导入成功', 'Imported');
  static String get save => _t('保存', 'Save');
  static String get saved => _t('已保存', 'Saved');
  static String get hostsOnTip => _t('Hosts 已启用', 'Hosts enabled');
  static String get hostsOffTip => _t('Hosts 未启用', 'Hosts disabled');

  // Blacklist page
  static String get blockThisTag => _t('屏蔽这个标签？', 'Block this tag?');
  static String blockThisTagBody(String tag) => _t(
      '「$tag」将不再出现在列表里。选「全局」则在所有站点生效。',
      '“$tag” will no longer appear in lists. Choose global to hide it on every site.');
  static String get blockGlobally => _t('全局屏蔽', 'Block everywhere');
  static String get blockOnThisSite => _t('仅本站屏蔽', 'Block on this site');
  static String get blockScope => _t('作用域', 'Scope');
  static String get scopeGlobal => _t('全局（所有站点）', 'Global (all sites)');
  static String get scopeGlobalShort => _t('全局', 'Global');
  static String get scopeSiteHint => _t(
      '站点作用域只在该站点生效；各站标签体系不同，所以「只想在某站屏蔽」是常见需求',
      'A site scope applies only on that site — tag taxonomies differ per site, so this is a common need');
  static String blockScopeFor(String name) => _t('仅 $name', '$name only');

  static String get blacklistTitle => _t('已屏蔽标签', 'Blocked tags');
  static String get addBlockedTag => _t('添加屏蔽标签', 'Add blocked tag');
  static String get addBlockedTagHint =>
      _t('输入标签名，多个用空格分隔', 'Enter tag names separated by spaces');
  static String get noBlockedTags => _t('暂无屏蔽标签', 'No blocked tags yet');
  static String get removeAction => _t('移除', 'Remove');

  // Explore page
  static String get exploreHot => _t('热门', 'Popular');
  static String get exploreLatest => _t('最新', 'Latest');
  static String get exploreRandom => _t('随机', 'Random');

  // Pools page
  static String get poolsUnsupported => _t(
      '当前站点不支持图集，或暂无图集', 'This site has no pools, or does not support them');
  static String get poolCountUnit => _t('张', 'images');

  // Search page
  static String get noMatchingTags => _t('没有匹配的标签', 'No matching tags');
  static String get suggestionsFailed => _t('建议加载失败', 'Failed to load suggestions');
  static String get switchColumns => _t('切换列数', 'Cycle columns');
  static String get backToTop => _t('回到顶部', 'Back to top');
  static String get backAction => _t('返回', 'Back');
  static String get recentSearches => _t('最近搜索', 'Recent searches');
  static String get trendingTags => _t('热门标签', 'Trending tags');
  static String get noTrendingTags =>
      _t('当前站点暂无热门标签', 'No trending tags on this site');
  static String get trendingTagsFailed =>
      _t('热门标签加载失败', 'Failed to load trending tags');
  static String searchFor(String query) => _t('搜索「$query」', 'Search "$query"');

  // About page
  static String get versionLabel => _t('版本', 'Version');
  static String get sourceCode => _t('源代码', 'Source code');
  static String get reportIssue => _t('反馈问题', 'Report an issue');

  // 诊断导出（本地错误日志，用户主动分享才离开设备）
  static String get exportDiagnostics =>
      _t('导出诊断信息', 'Export diagnostics');
  static String get exportDiagnosticsSub => _t(
      '本地错误日志，仅在你主动分享时离开设备',
      'Local error log; it only leaves the device when you share it');
  /// 删除下载记录时的勾选项：是否连带删除本机那份文件。
  static String get deleteLocalFile => _t(
      '同时删除本机文件（相册里的副本不受影响）',
      'Also delete the file on this device (the gallery copy stays)');
  static String get noDiagnostics =>
      _t('暂无诊断记录（没有捕获到错误）', 'No diagnostics recorded (no errors captured)');

  // Server editor
  static String get engineTypeNotSet => _t('引擎类型未设置', 'Engine type not set');
  static String get engineTypeNotSetMessage => _t(
      '未选择引擎类型，此站点可能无法正常浏览。是否仍要保存？',
      'No engine type selected. This site may not work correctly. Save anyway?');
  static String get engineAutoOther => _t('自动/其他', 'Auto / Other');
  static String get engineNotImplemented => _t('此引擎尚未实现，添加后可能无法正常浏览',
      'This engine is not implemented yet, so browsing may not work.');
  // 站点级偏好（§6.4）：全部免费的核心可用性
  // 站点健康面板（OPT §5.4）
  static String get serverHealth => _t('站点健康', 'Site health');
  static String get checkAllServers => _t('检查全部', 'Check all');
  static String get healthUnknown => _t('未检查', 'Not checked');
  static String get healthChecking => _t('检查中', 'Checking');
  static String get healthOk => _t('正常', 'Reachable');
  static String get healthSlow => _t('偏慢', 'Slow');
  static String get healthRejected => _t('被拒绝（403/401）', 'Rejected (403/401)');
  static String get healthError => _t('服务端错误', 'Server error');
  static String get healthUnreachable => _t('连不上', 'Unreachable');
  static String get healthHostsActive => _t('hosts 映射生效中', 'Hosts mapping active');
  static String healthLatency(int ms) =>
      _t('$ms ms', '$ms ms');

  static String get serverPreferences => _t('站点偏好', 'Site preferences');
  static String get serverPreferencesSub =>
      _t('只影响这个站点', 'Applies to this site only');
  static String get visibleRating => _t('可见评级', 'Visible rating');
  static String get visibleRatingSub => _t(
      '浏览这个站点时默认取哪一档；安全模式开启时仍然只取安全档',
      'Default rating tier when browsing this site; safe mode still limits it to safe');
  static String get ratingFollowGlobal => _t('跟随全局', 'Follow global');
  static String get serverQualitySub =>
      _t('下载这个站点的图片时用的画质', 'Quality used when downloading from this site');
  static String get downloadConcurrency => _t('批量下载并发数', 'Batch download concurrency');
  static String downloadConcurrencyValue(int n) => _t(
      '同时下载 $n 张（1 最省流量、6 最快）',
      'Download $n at a time (1 = gentlest, 6 = fastest)');
  static String get previewQuality => _t('预览画质', 'Preview quality');
  static String get previewQualitySub => _t(
      '查看器里加载哪张（跟随全局时用设置 → 下载里的预览画质）',
      'Which image the viewer loads (follows the global preview quality in Settings → Downloads)');
  static String get defaultSort => _t('默认排序', 'Default sort');
  static String get defaultSortSub => _t(
      '打开搜索页时预选的排序；「搜索页当前选择」= 不干预',
      'Pre-selected sort when opening search; “Search page choice” means no override');
  static String get sortFollowSearch => _t('搜索页当前选择', 'Search page choice');
  static String get downloadSubdir => _t('下载子目录', 'Download subfolder');
  static String get downloadSubdirSub => _t(
      '相对全局下载目录；留空则直接放在全局目录里',
      'Relative to the global download folder; empty means the global folder itself');
  static String get downloadSubdirHint => _t('例如 danbooru', 'e.g. danbooru');
  static String get invalidSubdir => _t(
      '只能是一层目录名（不能有斜杠或 ..）',
      'Must be a single folder name (no slashes or ..)');
  static String get credentialsNotStored => _t(
      '站点已保存，但凭据没能写入系统安全存储（本次会话内有效，重启后需要重新填写）',
      'Site saved, but the credentials could not be written to secure storage (valid for this session only; re-enter after restart)');
  static String get engineNoAuthNeeded => _t(
      '此引擎无需凭据（登录信息只对 Danbooru / Gelbooru / Moebooru / e621 / Rule34 这类站点有效）',
      'This engine needs no credentials (login only applies to Danbooru / Gelbooru / Moebooru / e621 / Rule34 style sites)');
  static String get engineNotImplementedSuffix =>
      _t('（未实现）', ' (not implemented)');
  static String get invalidUrl => _t('请输入有效的站点地址', 'Enter a valid site address');
  static String get urlSchemeUnsupported => _t(
      '只支持 http:// 或 https:// 开头的地址', 'Only http:// or https:// addresses are supported');
  static String get urlSchemeWillBeAdded => _t('未填写协议，保存时会自动补全为 https://',
      'No scheme entered. https:// will be added on save.');
  static String get urlInsecureWarning => _t(
      'http:// 是明文传输，登录名与 API Key 可能被窃听，建议改用 https://',
      'http:// is not encrypted. Your login and API key could be intercepted; prefer https://.');
  static String get serverUrlExistsTitle => _t('该地址已存在', 'Address already added');
  static String serverUrlExistsMessage(String name) => _t(
      '「$name」已经在用这个地址。要改为编辑它吗？',
      '"$name" already uses this address. Edit it instead?');
  static String get saveAnyway => _t('仍然保存', 'Save anyway');

  // Invalid route page (router)
  static String get invalidLink => _t('链接无效', 'Invalid link');
  static String get invalidLinkHint =>
      _t('请从主页重新进入', 'Please re-enter from the home page');
  static String get backToHome => _t('返回主页', 'Back to home');

  // Errors
  static String get somethingWentWrong => _t('出错了', 'Something went wrong');
  static String get retry => _t('重试', 'Retry');

  // 加载更多
  static String get loadMoreFailed => _t('加载更多失败', 'Failed to load more');
  static String get retryLoadMore => _t('重试加载', 'Retry loading');
  static String get loadMore => _t('继续加载', 'Load more');

  // Hosts / 下载目录
  static String get hostsRuleInvalid => _t(
      '规则不合法：IP 需要是有效地址（如 1.2.3.4），域名至少包含一个点',
      'Invalid rule: the IP must be a valid address (e.g. 1.2.3.4) and the domain needs at least one dot.');

  /// 保存时有 [count] 行规则没通过校验、已被跳过。
  static String hostsInvalidLines(int count) => _t(
      '$count 行 Host 规则格式不合法，已跳过',
      '$count host rule(s) had an invalid format and were skipped.');

  static String get downloadDirNotWritable => _t(
      '这个目录不可写（系统限制或存储权限），请换一个目录',
      "That folder isn't writable (system restriction or storage permission). Pick another one.");

  // 整页都被黑名单屏蔽（不能和「没有结果」共用文案，否则用户以为搜不到）
  static String get allPostsBlocked => _t('结果均被黑名单屏蔽', 'All results are blocked');
  static String get allPostsBlockedHint => _t(
      '这一页的帖子都命中了你的标签黑名单。继续加载下一页，或去设置里调整黑名单。',
      'Every post on this page matched your tag blacklist. Load the next page, or adjust the blacklist in settings.');
  static String get noServerSelected =>
      _t('尚未选择站点，请先在「服务器」中添加一个', 'No site selected yet. Add one in Servers first.');

  // 底层异常 → 用户提示（供 _friendlyError 使用）
  static String get errTimeout =>
      _t('连接超时，请检查网络或尝试使用 Hosts 功能', 'Connection timed out. Check your network or try the Hosts feature.');
  static String get errReceiveTimeout =>
      _t('服务器响应超时，请稍后重试', 'Server took too long to respond. Try again later.');
  static String get errRefused =>
      _t('连接被拒绝，请检查服务器地址是否正确', 'Connection refused. Check the server address.');
  static String get errDns =>
      _t('域名解析失败，请检查网络或服务器地址', 'DNS lookup failed. Check your network or the server address.');
  static String get errTls => _t('安全连接失败（证书校验未通过），请检查系统时间或网络环境',
      'Secure connection failed (certificate not verified). Check the system clock or network.');
  static String get err403 =>
      _t('访问被拒绝（403），可能需要登录或 API 密钥', 'Access denied (403). You may need to sign in or set an API key.');
  static String get err404 =>
      _t('资源不存在（404），服务器地址可能已变更', 'Not found (404). The server address may have changed.');
  static String get err429 =>
      _t('请求过于频繁（429），请稍后再试', 'Too many requests (429). Try again later.');
  static String get err5xx =>
      _t('服务器内部错误（5xx），请稍后再试', 'Server error (5xx). Try again later.');
  static String get errNetwork =>
      _t('网络异常，请检查网络连接', 'Network error. Check your connection.');
  static String get errUnknown =>
      _t('请求失败，请稍后重试', 'Request failed. Please try again later.');
  static String get errBadPayload => _t('服务器返回数据异常，可能不是有效的 Booru 站点',
      'Unexpected response. This may not be a valid booru site.');

  // Sort options - labels for display
  static String sortLabel(String key) {
    switch (key) {
      case 'relevance':
        return sortRelevance;
      case 'score':
        return sortScore;
      case 'date':
        return sortDate;
      case 'rating':
        return sortRating;
      default:
        return key;
    }
  }

  /// 底层异常 → 面向用户的提示。
  ///
  /// 放在文案层而不是某个页面里：此前它是 `home_content` 的私有函数，
  /// 其他页面（探索/图集/图集详情）只能把 `e.toString()` 的英文栈丢给用户。
  /// 全应用一份映射，也保证同一个错误在任何页面说法一致。
  static String friendlyError(Object error) {
    final raw = error.toString();
    // 哨兵错误码（page_state 在「未选站点」时写入）在这里映射成文案，
    // 避免状态层硬编码语言。
    const noServerSentinel = 'noServerSelected';
    if (raw.contains(noServerSentinel)) {
      return noServerSelected;
    }

    // 结构化优先：DioException 自带**类型**与**状态码**，比在字符串里找
    // 'connection timeout' / 'status code of 404' 可靠得多——dio 换一句
    // 文案、换一个语言，字符串匹配就默默失效，用户又看到裸异常。
    // 字符串匹配仍然保留在下面，兜住被包装过的、非 dio 的异常。
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return errTimeout;
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return errReceiveTimeout;
        case DioExceptionType.badCertificate:
          return errTls;
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode ?? 0;
          if (code == 403) return err403;
          if (code == 404) return err404;
          if (code == 429) return err429;
          if (code >= 500) return err5xx;
        case DioExceptionType.connectionError:
          // 具体是 DNS 还是拒绝连接，要看内层 SocketException 的文案
          final inner = error.error?.toString() ?? '';
          if (inner.contains('Failed host lookup') ||
              inner.contains('No address associated with hostname')) {
            return errDns;
          }
          if (inner.contains('Connection refused')) return errRefused;
          return errNetwork;
        case DioExceptionType.transformTimeout:
          // 解析超时：用户该做的动作和接收超时一样（等等再试）
          return errReceiveTimeout;
        case DioExceptionType.cancel:
        case DioExceptionType.unknown:
          break;
      }
    }
    if (raw.contains('connection timeout') ||
        raw.contains('Connection timeout') ||
        raw.contains('connectionTimeout')) {
      return errTimeout;
    }
    if (raw.contains('receiveTimeout') || raw.contains('Receive timeout')) {
      return errReceiveTimeout;
    }
    if (raw.contains('Connection refused')) {
      return errRefused;
    }
    if (raw.contains('Failed host lookup') ||
        raw.contains('No address associated with hostname')) {
      return errDns;
    }
    if (raw.contains('HandshakeException') || raw.contains('CERTIFICATE')) {
      return errTls;
    }
    if (RegExp(r'status (code )?of 403').hasMatch(raw)) {
      return err403;
    }
    if (RegExp(r'status (code )?of 404').hasMatch(raw)) {
      return err404;
    }
    if (RegExp(r'status (code )?of 429').hasMatch(raw)) {
      return err429;
    }
    if (RegExp(r'status (code )?of 5\d\d').hasMatch(raw)) {
      return err5xx;
    }
    if (raw.contains('SocketException')) {
      return errNetwork;
    }
    if (raw.contains('XML') || raw.contains('parser') || raw.contains('json')) {
      return errBadPayload;
    }
    // 没命中任何已知形态：给一句通用文案，**不要**把原文丢给用户。
    //
    // 此前这里会返回原文的前两行——而原文是
    // `DioException [bad response]: ...\n#0 DioMixin.fetch ...` 这种英文栈，
    // 用户看不懂，也做不了任何事。技术细节有诊断日志（diagnostic_log）负责，
    // 面向用户的这一层只负责说「失败了，可以重试」。
    return errUnknown;
  }

  /// 中文优先、英文随语言切换返回。
  static String _t(String zh, String en) => isEn ? en : zh;
}
