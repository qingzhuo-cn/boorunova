enum BooruType {
  danbooru('danbooru'),
  gelbooru('gelbooru'),
  gelbooruV2('gelbooru_v2'),
  moebooru('moebooru'),
  e621('e621'),
  sankaku('sankaku'),
  szurubooru('szurubooru'),
  philomena('philomena'),
  shimmie2('shimmie2'),
  hydrus('hydrus'),
  zerochan('zerochan'),
  rule34('rule34'),
  safebooru('safebooru'),
  hybooru('hybooru'),
  nozomi('nozomi'),
  animePictures('anime_pictures'),
  eshuushuu('eshuushuu'),
  unknown('unknown');

  const BooruType(this.value);
  final String value;

  static BooruType fromValue(String value) {
    return BooruType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => BooruType.unknown,
    );
  }
}
