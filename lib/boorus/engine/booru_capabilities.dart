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
  final bool syntaxHighlighting;
  final bool bulkDownload;

  static const none = BooruCapabilities();
  static const basic = BooruCapabilities(
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
    syntaxHighlighting: true,
    bulkDownload: true,
  );
}
