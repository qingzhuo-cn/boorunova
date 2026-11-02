// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_type.dart';

/// Play 版编译期开关：`--dart-define=boorunova.play=true`。
///
/// 必须是**编译期**常量：Dart AOT 会把死分支连同其中的字符串字面量一起摇掉，
/// 于是站点域名根本不进 Play 构建的字节。运行时开关（shared_preferences、
/// 隐藏菜单、远程配置）做不到这一点——字面量仍在二进制里，反编译即见，
/// 而「藏起来的预置」在审核语境下比明着预置更糟。
const bool kPlayBuild = bool.fromEnvironment('boorunova.play');

/// 模板的视觉样式令牌。
///
/// 引擎层不认识 IconData / MaterialColor（那是表示层的事），所以这里只给一个
/// 不透明令牌，由 booru_site_template.dart 映射成图标与配色。
/// 这样「预置数据只有一处」与「引擎层不依赖 Flutter」两个约束同时成立。
enum PresetStyle {
  photoLibrary,
  image,
  shield,
  autoAwesome,
  pets,
  lensBlur,
  filterVintage,
  warningAmber,
  gridView,
  photoCameraBack,
  collectionsBookmark,
  link,
  photoLibraryOutlined,
  playCircleOutline,
  palette,
  collections,
}

/// 一条站点预置（模板）。
class SitePreset {
  const SitePreset({
    required this.type,
    required this.name,
    required this.baseUrl,
    required this.style,
    this.description,
  });

  final BooruType type;
  final String name;
  final String baseUrl;
  final PresetStyle style;
  final String? description;
}

// ---------------------------------------------------------------------------
// 引擎默认域名 / 解析器默认站点（同一份数据，Play 版全部为空串）
// ---------------------------------------------------------------------------

const String kDanbooruBaseUrl = kPlayBuild ? '' : 'https://danbooru.donmai.us';
const String kGelbooruV2BaseUrl = kPlayBuild ? '' : 'https://gelbooru.com';
const String kMoebooruBaseUrl = kPlayBuild ? '' : 'https://yande.re';
const String kE621BaseUrl = kPlayBuild ? '' : 'https://e621.net';
const String kSankakuBaseUrl =
    kPlayBuild ? '' : 'https://chan.sankakucomplex.com';
const String kZerochanBaseUrl =
    kPlayBuild ? '' : 'https://www.zerochan.net';
const String kRule34BaseUrl = kPlayBuild ? '' : 'https://api.rule34.xxx';
const String kSafebooruBaseUrl = kPlayBuild ? '' : 'https://safebooru.org';
const String kShimmie2BaseUrl = kPlayBuild ? '' : 'https://rule34.paheal.net';
const String kKvsBaseUrl = kPlayBuild ? '' : 'https://rule34video.com';

/// rule34 的**网页**域名（帖子链接用），与 DAPI 域名不同。
const String kRule34SiteUrl = kPlayBuild ? '' : 'https://rule34.xxx';

// ---------------------------------------------------------------------------
// 探测：域名捷径表
// ---------------------------------------------------------------------------

/// 域名 → 类型。命中就不发请求（也避免把 safebooru.org 认成 zerochan）。
///
/// Play 版置空：全部 URL 走 probe()，而探测特征是协议层字符串
/// （`<post`、`/posts.json`…），不含站点名——这正是 BYO 的核心能力。
const Map<BooruType, String> kPresetDomains =
    kPlayBuild ? <BooruType, String>{} : <BooruType, String>{
  BooruType.danbooru: 'danbooru.donmai.us',
  BooruType.gelbooruV2: 'gelbooru.com',
  BooruType.moebooru: 'yande.re',
  BooruType.e621: 'e621.net',
  BooruType.sankaku: 'sankakucomplex.com',
  BooruType.zerochan: 'zerochan.net',
  BooruType.rule34: 'rule34.xxx',
  BooruType.safebooru: 'safebooru.org',
  BooruType.shimmie2: 'paheal.net',
  BooruType.kvs: 'rule34video.com',
};

// ---------------------------------------------------------------------------
// 站点模板（出厂预置的全部来源）
// ---------------------------------------------------------------------------

/// 出厂模板。Play 版为空 —— 应用装出来就是空白客户端，
/// 所有站点都由用户自己填 URL，引擎类型由协议探测识别。
const List<SitePreset> kSitePresets =
    kPlayBuild ? <SitePreset>[] : <SitePreset>[
  SitePreset(
    type: BooruType.danbooru,
    name: 'Danbooru',
    baseUrl: 'https://danbooru.donmai.us',
    style: PresetStyle.photoLibrary,
    description: 'danbooru.donmai.us',
  ),
  SitePreset(
    type: BooruType.gelbooruV2,
    name: 'Gelbooru',
    baseUrl: 'https://gelbooru.com',
    style: PresetStyle.image,
    description: 'gelbooru.com',
  ),
  SitePreset(
    type: BooruType.safebooru,
    name: 'Safebooru',
    baseUrl: 'https://safebooru.org',
    style: PresetStyle.shield,
    description: 'safebooru.org',
  ),
  SitePreset(
    type: BooruType.moebooru,
    name: 'yande.re',
    baseUrl: 'https://yande.re',
    style: PresetStyle.autoAwesome,
    description: 'yande.re / konachan.com',
  ),
  SitePreset(
    type: BooruType.moebooru,
    name: 'Konachan',
    baseUrl: 'https://konachan.com',
    style: PresetStyle.autoAwesome,
    description: 'konachan.com',
  ),
  SitePreset(
    type: BooruType.e621,
    name: 'e621',
    baseUrl: 'https://e621.net',
    style: PresetStyle.pets,
    description: 'e621.net',
  ),
  SitePreset(
    type: BooruType.sankaku,
    name: 'Sankaku',
    baseUrl: 'https://chan.sankakucomplex.com',
    style: PresetStyle.lensBlur,
    description: 'chan.sankakucomplex.com',
  ),
  SitePreset(
    type: BooruType.zerochan,
    name: 'Zerochan',
    baseUrl: 'https://www.zerochan.net',
    style: PresetStyle.filterVintage,
    description: 'zerochan.net',
  ),
  SitePreset(
    type: BooruType.rule34,
    name: 'Rule 34',
    baseUrl: 'https://api.rule34.xxx',
    style: PresetStyle.warningAmber,
    description: 'api.rule34.xxx',
  ),
  // ---- gelbooru DAPI 协议的同族镜像 ----
  SitePreset(
    type: BooruType.gelbooruV2,
    name: 'Xbooru',
    baseUrl: 'https://xbooru.com',
    style: PresetStyle.gridView,
    description: 'xbooru.com',
  ),
  SitePreset(
    type: BooruType.gelbooruV2,
    name: 'Realbooru',
    baseUrl: 'https://realbooru.com',
    style: PresetStyle.photoCameraBack,
    description: 'realbooru.com',
  ),
  SitePreset(
    type: BooruType.gelbooruV2,
    name: 'TBIB',
    baseUrl: 'https://tbib.org',
    style: PresetStyle.collectionsBookmark,
    description: 'tbib.org',
  ),
  SitePreset(
    type: BooruType.gelbooruV2,
    name: 'Rule34.us',
    baseUrl: 'https://rule34.us',
    style: PresetStyle.link,
    description: 'rule34.us',
  ),
  // ---- paheal 系（Shimmie2）----
  SitePreset(
    type: BooruType.shimmie2,
    name: 'Rule 34 Paheal',
    baseUrl: 'https://rule34.paheal.net',
    style: PresetStyle.photoLibraryOutlined,
    description: 'rule34.paheal.net',
  ),
  SitePreset(
    type: BooruType.shimmie2,
    name: 'AllGirls (Paheal)',
    baseUrl: 'https://allgirls.paheal.net',
    style: PresetStyle.photoLibrary,
    description: 'allgirls.paheal.net',
  ),
  // ---- 视频站（KVS）----
  SitePreset(
    type: BooruType.kvs,
    name: 'Rule34 Video',
    baseUrl: 'https://rule34video.com',
    style: PresetStyle.playCircleOutline,
    description: 'rule34video.com · 视频',
  ),
];

/// 尚未实现引擎的站点模板。
///
/// 它们从 [kSitePresets] 里移出来：此前引导页与添加入口会列出这两个站，
/// 而这两个类型没有注册任何引擎——用户勾选后只会得到「引擎不可用」。
/// 类型本身留在枚举里，已有服务器不受影响。实现引擎后移回去即可。
const List<SitePreset> kPlannedSitePresets =
    kPlayBuild ? <SitePreset>[] : <SitePreset>[
  SitePreset(
    type: BooruType.animePictures,
    name: 'Anime-Pictures',
    baseUrl: 'https://anime-pictures.net',
    style: PresetStyle.palette,
    description: 'anime-pictures.net',
  ),
  SitePreset(
    type: BooruType.eshuushuu,
    name: 'E-Shuushuu',
    baseUrl: 'https://e-shuushuu.net',
    style: PresetStyle.collections,
    description: 'e-shuushuu.net',
  ),
];

/// 引导页默认勾选的类型。Play 版为空（引导改为「自己添加第一个服务器」）。
const Set<BooruType> kPresetOnboardingSelection = kPlayBuild
    ? <BooruType>{}
    : <BooruType>{BooruType.safebooru};

/// Play 版的中性引擎显示名：不出现任何站点名，只描述协议/引擎家族。
///
/// 协议/软件家族名（danbooru / gelbooru / moebooru / shimmie2）本就是协议标识，
/// 可以保留；e621 / rule34 / safebooru / zerochan / sankaku 既是方言名也是站点名，
/// 在 Play 版的**界面显示**里换成中性说法（内部枚举码不变，用户的服务器照常工作）。
const Map<BooruType, String> kNeutralEngineNames = <BooruType, String>{
  BooruType.danbooru: 'Danbooru API',
  BooruType.gelbooruV2: 'Gelbooru 0.2 API',
  BooruType.moebooru: 'Moebooru API',
  BooruType.e621: 'Furry booru API',
  BooruType.sankaku: 'Chan-style tag API',
  BooruType.zerochan: 'Anime image API',
  BooruType.rule34: 'DAPI JSON board',
  BooruType.safebooru: 'DAPI XML board',
  BooruType.shimmie2: 'Shimmie2 gallery',
  BooruType.kvs: 'KVS video site',
};
