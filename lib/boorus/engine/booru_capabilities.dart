class BooruCapabilities {
  const BooruCapabilities({
    this.pools = false,
    this.forums = false,
    this.comments = false,
    this.notes = false,
    this.voting = false,
    this.artistPages = false,
    this.characterPages = false,
    this.videoSupport = false,
    this.tagTranslation = false,
    this.favorites = false,
    this.syntaxHighlighting = false,
    this.bulkDownload = false,
  });

  final bool pools;
  final bool forums;
  final bool comments;
  final bool notes;
  final bool voting;
  final bool artistPages;
  final bool characterPages;
  final bool videoSupport;
  final bool tagTranslation;
  final bool favorites;
  final bool syntaxHighlighting;
  final bool bulkDownload;

  static const none = BooruCapabilities();
  static const basic = BooruCapabilities(
    favorites: true,
    comments: true,
  );
  static const full = BooruCapabilities(
    pools: true,
    forums: true,
    comments: true,
    notes: true,
    voting: true,
    artistPages: true,
    characterPages: true,
    videoSupport: true,
    tagTranslation: true,
    favorites: true,
    syntaxHighlighting: true,
    bulkDownload: true,
  );
}
