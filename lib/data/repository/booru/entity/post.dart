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
    this.tagGeneral = const [],
    this.tagArtist = const [],
    this.tagCharacter = const [],
    this.tagCopyright = const [],
    this.tagMeta = const [],
  });

  factory BooruPost.fromJson(Map<String, dynamic> json) => BooruPost(
        id: json['id'] as String,
        serverId: json['serverId'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String,
        sampleUrl: json['sampleUrl'] as String,
        originalUrl: json['originalUrl'] as String,
        tags: List<String>.from(json['tags'] as List),
        aspectRatio: (json['aspectRatio'] as num).toDouble(),
        width: json['width'] as int,
        height: json['height'] as int,
        rating: json['rating'] as String,
        score: json['score'] as int,
        source: json['source'] as String?,
        postUrl: json['postUrl'] as String?,
        uploader: json['uploader'] as String?,
        tagGeneral: _tagList(json['tagGeneral']),
        tagArtist: _tagList(json['tagArtist']),
        tagCharacter: _tagList(json['tagCharacter']),
        tagCopyright: _tagList(json['tagCopyright']),
        tagMeta: _tagList(json['tagMeta']),
      );

  static List<String> _tagList(Object? v) =>
      v is List ? List<String>.from(v) : [];

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
  final String? uploader;
  final List<String> tagGeneral;
  final List<String> tagArtist;
  final List<String> tagCharacter;
  final List<String> tagCopyright;
  final List<String> tagMeta;

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
        'tagGeneral': tagGeneral,
        'tagArtist': tagArtist,
        'tagCharacter': tagCharacter,
        'tagCopyright': tagCopyright,
        'tagMeta': tagMeta,
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
