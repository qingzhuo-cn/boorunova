class SearchSession {
  const SearchSession({
    this.query = '',
    required this.serverId,
  });

  final String query;
  final String serverId;

  SearchSession copyWith({String? query, String? serverId}) {
    return SearchSession(
      query: query ?? this.query,
      serverId: serverId ?? this.serverId,
    );
  }
}
