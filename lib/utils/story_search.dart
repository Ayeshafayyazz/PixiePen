class StorySearch {
  const StorySearch._();

  static const int minTermLength = 2;

  static String normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool hasSearchTerms(String query) {
    return _terms(query).isNotEmpty;
  }

  static bool matchesStory(
    Map<String, dynamic> data,
    String query, {
    Iterable<Object?> extraFields = const [],
  }) {
    final terms = _terms(query);
    if (terms.isEmpty) return true;

    final searchable = [
      data['title'],
      data['body'],
      data['authorName'],
      data['username'],
      data['handle'],
      ...extraFields,
    ].whereType<String>().map(normalize).join(' ');

    return terms.every(searchable.contains);
  }

  static List<String> _terms(String query) {
    return normalize(query)
        .split(RegExp(r'\s+'))
        .where((term) => term.length >= minTermLength)
        .toList(growable: false);
  }
}
