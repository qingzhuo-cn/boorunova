// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

class BooruPost {
  const BooruPost({
    required this.id,
    required this.serverId,
    required this.thumbnailUrl,
    required this.sampleUrl,
    required this.originalUrl,
    required this.tags,
    required this.aspectRatio,
    required this.width,
    required this.height,
    required this.rating,
    required this.score,
    this.source,
    this.postUrl,
    this.uploader,
    this.duration,
    this.tagGeneral = const [],
    this.tagArtist = const [],
    this.tagCharacter = const [],
    this.tagCopyright = const [],
    this.tagMeta = const [],
    this.isVideo = false,
  });

  factory BooruPost.fromJson(Map<String, dynamic> json) => BooruPost(
        id: json['id']?.toString() ?? '',
        serverId: json['serverId']?.toString() ?? '',
        thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
        sampleUrl: json['sampleUrl']?.toString() ?? '',
        originalUrl: json['originalUrl']?.toString() ?? '',
        tags: _tagList(json['tags']),
        // 宽高比必须落在合法区间：0 / NaN / 无穷会让 AspectRatio 直接抛断言
        aspectRatio: _aspect(json['aspectRatio']),
        width: _int(json['width']),
        height: _int(json['height']),
        rating: json['rating']?.toString() ?? 'q',
        score: _int(json['score']),
        source: json['source']?.toString(),
        postUrl: json['postUrl']?.toString(),
        uploader: json['uploader']?.toString(),
        duration: json['duration']?.toString(),
        tagGeneral: _tagList(json['tagGeneral']),
        tagArtist: _tagList(json['tagArtist']),
        tagCharacter: _tagList(json['tagCharacter']),
        tagCopyright: _tagList(json['tagCopyright']),
        tagMeta: _tagList(json['tagMeta']),
        // 老数据没有这个字段：默认 false，读回来仍按 URL 判定兼容
        isVideo: json['isVideo'] == true,
      );

  /// 宽容取标签列表：`List<String>.from(v)` 只要列表里混进一个非字符串
  /// （站点确实会这么干）就抛 TypeError，导入备份时会整段中断。
  static double _aspect(Object? v) {
    if (v is! num) return 1.0;
    final value = v.toDouble();
    return value > 0 && value.isFinite ? value : 1.0;
  }

  static List<String> _tagList(Object? v) =>
      v is List ? v.whereType<String>().toList() : const [];

  /// 宽容取 int：历史数据里可能是 double（`width: 1200.0`）或字符串。
  static int _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  final String id;
  final String serverId;
  final String thumbnailUrl;
  final String sampleUrl;
  final String originalUrl;
  final List<String> tags;
  final double aspectRatio;
  final int width;
  final int height;
  final String rating;
  final int score;
  final String? source;
  final String? postUrl;

  /// 作者 / 上传者（danbooru 的 uploader_name、moebooru·sankaku·zerochan 的
  /// author）。
  final String? uploader;

  /// 视频时长（`mm:ss` / `h:mm:ss`），只有视频站给得出。
  ///
  /// 此前 KVS 把这个值塞进 [uploader] —— 字段名与内容不符，读到的人只会
  /// 困惑，而时长本身也没有任何消费点。现在它有独立字段，并在时间线瓦片上
  /// 显示出来。
  final String? duration;
  final List<String> tagGeneral;
  final List<String> tagArtist;
  final List<String> tagCharacter;
  final List<String> tagCopyright;
  final List<String> tagMeta;

  /// 视频帖标记。
  ///
  /// 视频站的列表页**只给缩略图**，帖子里没有任何 mp4/HLS 地址（播放地址要
  /// 打开详情页才解析得出来）。因此"这是不是视频"必须由解析器显式告知，
  /// 不能靠 URL 后缀去猜——猜的结果是视频帖被当成图片帖渲染。
  final bool isVideo;

  Map<String, dynamic> toJson() => {
        'id': id,
        'serverId': serverId,
        'thumbnailUrl': thumbnailUrl,
        'sampleUrl': sampleUrl,
        'originalUrl': originalUrl,
        'tags': tags,
        'aspectRatio': aspectRatio,
        'width': width,
        'height': height,
        'rating': rating,
        'score': score,
        'source': source,
        'postUrl': postUrl,
        'uploader': uploader,
        'duration': duration,
        'tagGeneral': tagGeneral,
        'tagArtist': tagArtist,
        'tagCharacter': tagCharacter,
        'tagCopyright': tagCopyright,
        'tagMeta': tagMeta,
        'isVideo': isVideo,
      };

  static const empty = BooruPost(
    id: '',
    serverId: '',
    thumbnailUrl: '',
    sampleUrl: '',
    originalUrl: '',
    tags: [],
    aspectRatio: 1.0,
    width: 0,
    height: 0,
    rating: 'q',
    score: 0,
  );
}
