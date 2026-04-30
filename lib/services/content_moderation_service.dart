class ModerationResult {
  final bool isSafe;
  final String? flagReason;
  final List<String> flaggedTerms;

  const ModerationResult.safe()
      : isSafe = true,
        flagReason = null,
        flaggedTerms = const [];

  const ModerationResult.unsafe({
    required this.flagReason,
    this.flaggedTerms = const [],
  }) : isSafe = false;
}

class ContentModerationService {
  static const String childFriendlyWarning =
      '⚠️ Please use kind and safe words 😊';

  static const List<String> profanityList = [
    'asshole',
    'bastard',
    'bitch',
    'crap',
    'damn',
    'fuck',
    'shit',
  ];

  static const List<String> violenceList = [
    'bomb',
    'gun',
    'kill',
    'murder',
    'stab',
    'weapon',
  ];

  static const List<String> bullyingList = [
    'dumb',
    'idiot',
    'loser',
    'moron',
    'stupid',
    'ugly',
  ];

  static const List<String> drugList = [
    'alcohol',
    'beer',
    'cocaine',
    'drunk',
    'marijuana',
    'weed',
    'wine',
  ];

  static final RegExp phoneRegex = RegExp(r'\b\d{10,13}\b');
  static final RegExp emailRegex = RegExp(
    r'\b[\w\.-]+@[\w\.-]+\.\w+\b',
    caseSensitive: false,
  );

  ModerationResult moderateText(String text) {
    final cleanText = normalize(text);
    final lowerText = text.toLowerCase();

    if (emailRegex.hasMatch(lowerText)) {
      return const ModerationResult.unsafe(flagReason: 'personal_info');
    }

    if (phoneRegex.hasMatch(cleanText)) {
      return const ModerationResult.unsafe(flagReason: 'personal_info');
    }

    final profanity = _matchedWords(cleanText, profanityList);
    if (profanity.isNotEmpty) {
      return ModerationResult.unsafe(
        flagReason: 'profanity',
        flaggedTerms: profanity,
      );
    }

    final violence = _matchedWords(cleanText, violenceList);
    if (violence.isNotEmpty) {
      return ModerationResult.unsafe(
        flagReason: 'violence',
        flaggedTerms: violence,
      );
    }

    final bullying = _matchedWords(cleanText, bullyingList);
    if (bullying.isNotEmpty) {
      return ModerationResult.unsafe(
        flagReason: 'bullying',
        flaggedTerms: bullying,
      );
    }

    final drugs = _matchedWords(cleanText, drugList);
    if (drugs.isNotEmpty) {
      return ModerationResult.unsafe(
        flagReason: 'drugs',
        flaggedTerms: drugs,
      );
    }

    return const ModerationResult.safe();
  }

  ModerationResult moderateStory({
    required String title,
    required String body,
  }) {
    return moderateText('$title $body');
  }

  bool isContentSafe(String text) => moderateText(text).isSafe;

  String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String sanitize(String text) {
    final result = moderateText(text);
    if (result.isSafe || result.flaggedTerms.isEmpty) return text;

    var sanitized = text;
    for (final term in result.flaggedTerms) {
      sanitized = sanitized.replaceAll(
        RegExp(r'\b' + RegExp.escape(term) + r'\b', caseSensitive: false),
        '***',
      );
    }
    return sanitized;
  }

  bool containsBadWords(String text, List<String> words) {
    return _matchedWords(normalize(text), words).isNotEmpty;
  }

  List<String> _matchedWords(String cleanText, List<String> words) {
    final matches = <String>[];

    for (final word in words) {
      final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b');
      if (pattern.hasMatch(cleanText)) {
        matches.add(word);
      }
    }

    return matches;
  }
}
