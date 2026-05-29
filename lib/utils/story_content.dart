/// Serialized story body: ordered [text] and [image] blocks for Firestore field `content`.
class StoryContentCodec {
  StoryContentCodec._();

  static const String typeText = 'text';
  static const String typeImage = 'image';

  /// Parses Firestore `content` (array of maps). Returns null if missing/invalid.
  static List<Map<String, dynamic>>? parseContent(dynamic raw) {
    if (raw is! List) return null;
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(Map<String, dynamic>.from(e));
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out.isEmpty ? null : out;
  }

  /// Plain text for search, moderation, previews — concatenates text blocks only.
  static String joinPlainText(List<Map<String, dynamic>> blocks) {
    final parts = <String>[];
    for (final m in blocks) {
      if (m['type'] == typeText) {
        final t = plainTextFromFormatted((m['text'] as String?) ?? '');
        if (t.trim().isNotEmpty) parts.add(t.trim());
      }
    }
    return parts.join('\n\n');
  }

  static String plainTextFromFormatted(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]+\)'),
          (match) => match.group(1) ?? '',
        )
        .split('\n')
        .map((line) {
          return line
              .replaceFirst(RegExp(r'^\s{0,3}#{1,3}\s+'), '')
              .replaceFirst(RegExp(r'^\s{0,3}>\s?'), '')
              .replaceFirst(RegExp(r'^\s*[-*]\s+'), '')
              .replaceFirst(RegExp(r'^\s*\d+[.)]\s+'), '')
              .replaceAllMapped(
                RegExp(r'\*\*([^*]+)\*\*'),
                (match) => match.group(1) ?? '',
              )
              .replaceAllMapped(
                RegExp(r'__([^_]+)__'),
                (match) => match.group(1) ?? '',
              )
              .replaceAllMapped(
                RegExp(r'\*([^*]+)\*'),
                (match) => match.group(1) ?? '',
              )
              .replaceAllMapped(
                RegExp(r'_([^_]+)_'),
                (match) => match.group(1) ?? '',
              )
              .replaceAllMapped(
                RegExp(r'`([^`]+)`'),
                (match) => match.group(1) ?? '',
              )
              .trimRight();
        })
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// True when we should render rich layout (at least one image or structured text).
  static bool hasRichLayout(List<Map<String, dynamic>>? blocks) {
    if (blocks == null || blocks.isEmpty) return false;
    for (final m in blocks) {
      if (m['type'] == typeImage &&
          ((m['url'] as String?)?.trim().isNotEmpty ?? false)) {
        return true;
      }
    }
    return false;
  }

  static Map<String, dynamic> textBlock(
    String text, {
    List<dynamic>? delta,
  }) =>
      {
        'type': typeText,
        'text': text,
        if (delta != null) 'delta': delta,
      };

  static Map<String, dynamic> imageBlock({
    required String url,
    required String storagePath,
  }) =>
      {
        'type': typeImage,
        'url': url,
        'storagePath': storagePath,
      };
}
