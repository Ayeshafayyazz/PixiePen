import 'dart:math' as math;

import '../utils/levenshtein.dart';

/// Where text is used — drives copy and a few rules (e.g. length limits).
enum ModerationSurface {
  story,
  comment,
  reply,
  appFeedback,
  parentFeedback,
  aiPrompt,
}

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

/// Live typing preview (debounced in UI): toxicity meter + whether submit would fail.
class ModerationLiveFeedback {
  /// Weighted risk / toxicity estimate (0–100). Not identical to scientific NLP toxicity.
  final double toxicityScore;

  /// True when [ContentModerationService.moderateWithSurface] would reject the text.
  final bool wouldBeBlocked;

  /// Short line for inline banner; null when nothing to show.
  final String? bannerMessage;

  const ModerationLiveFeedback({
    required this.toxicityScore,
    required this.wouldBeBlocked,
    this.bannerMessage,
  });
}

class ContentModerationService {
  static const String childFriendlyWarning =
      'Please use kind and safe words so PixiePen stays friendly for everyone.';

  /// Max characters per surface (after trim) before blocking.
  static int maxCharsFor(ModerationSurface surface) {
    switch (surface) {
      case ModerationSurface.story:
        return 120000;
      case ModerationSurface.comment:
      case ModerationSurface.reply:
        return 4000;
      case ModerationSurface.appFeedback:
        return 8000;
      case ModerationSurface.parentFeedback:
        return 6000;
      case ModerationSurface.aiPrompt:
        return 4000;
    }
  }

  static const List<String> profanityList = [
    'asshole',
    'bastard',
    'bitch',
    'crap',
    'damn',
    'fuck',
    'fucking',
    'fucker',
    'motherfucker',
    'shit',
    'shitty',
  ];

  /// Regex roots catch common inflections/slang that exact-word lists miss
  /// (e.g. "fucking", "fucked", "shitty"), especially in short comments.
  static final List<RegExp> _profanityPatterns = [
    RegExp(r'\bfuck(?:ing|ed|er|ers)?\b', caseSensitive: false),
    RegExp(r'\bmotherfuck(?:er|ers|ing|ed)?\b', caseSensitive: false),
    RegExp(r'\bshit(?:ty|head|heads)?\b', caseSensitive: false),
    RegExp(r'\bbitch(?:es|y)?\b', caseSensitive: false),
    RegExp(r'\basshole(?:s)?\b', caseSensitive: false),
    RegExp(r'\bbastard(?:s)?\b', caseSensitive: false),
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
    'cocaine',
    'marijuana',
    'weed',
  ];

  static final RegExp phoneRegex = RegExp(r'\b\d{10,13}\b');
  static final RegExp emailRegex = RegExp(
    r'\b[\w\.-]+@[\w\.-]+\.\w+\b',
    caseSensitive: false,
  );
  static final RegExp _urlRegex = RegExp(
    r'https?://|www\.\S+',
    caseSensitive: false,
  );
  static final RegExp _spamRepeatChar = RegExp(r'(.)\1{9,}');

  /// Block if aggregated social risk meets or exceeds this (comments / replies).
  static const double toxicityBlockThreshold = 78;

  /// Directed insults / hostility common in short social text (comments & replies).
  /// Stories intentionally skip this so fictional dialogue can stay allowed.
  static final List<RegExp> _socialHostilityPatterns = [
    RegExp(r'\b(i\s+)?hate\s+(you|u|ya|yall|you\s+all)\b', caseSensitive: false),
    RegExp(r'\b(i\s+)?h8\s+(you|u|them)\b', caseSensitive: false),
    RegExp(r'\b(you|u|ya)\s*suck(s|ed|ing)?\b', caseSensitive: false),
    RegExp(r'\b(you|u)\s+(are|r)\s+(so\s+)?(the\s+)?(worst|trash|garbage|pathetic|worthless|useless)\b',
        caseSensitive: false),
    RegExp(r'\b(you|u)\s+(are|r)\s+(a\s+)?(stupid|dumb|idiot|moron|loser|ugly)\b',
        caseSensitive: false),
    RegExp(
        r'\b(shut\s+up|stfu|go\s+(die|away)|go\s+kill\s+yourself|kill\s+yourself|kys)\b',
        caseSensitive: false),
    RegExp(
        r'\b(i\s+)?(hope|wish)\s+you(\s+would|\s+will)?\s+(die|drown|burn|fail|disappear)\b',
        caseSensitive: false),
    RegExp(
        r'\b(nobody\s+likes\s+you|everyone\s+hates\s+you|no\s+one\s+likes\s+you|die\s+already)\b',
        caseSensitive: false),
    RegExp(r'\b(f[\s\*]*u[\s\*]*c?k\s+(you|off)|f\s*off)\b', caseSensitive: false),
  ];

  /// Same insult repeated in one line (harassment / spammed slurs).
  static final RegExp _repeatedInsultPattern = RegExp(
    r'\b(stupid|dumb|ugly|idiot|loser|moron|hate|fuck|shit|bitch|asshole|loser|pathetic|trash|garbage|useless|worthless|hate|suck|worst)\b(?:\s*[,;!.]?\s*\b\1\b)+',
    caseSensitive: false,
  );

  /// Shouting, dismissal, and other aggressive social phrases.
  static final List<RegExp> _aggressiveSocialPatterns = [
    RegExp(
        r'\b(what|whats|what\s+is)\s+wrong\s+with\s+you\b',
        caseSensitive: false),
    RegExp(r'\bget\s+lost\b', caseSensitive: false),
    RegExp(
        r"\b(nobody\s+cares|no\s+one\s+cares|who\s+cares|i\s+don't\s+care\s+about\s+you|i\s+dont\s+care\s+about\s+you|shut\s+your\s+mouth|shut\s+it)\b",
        caseSensitive: false),
    RegExp(
        r"\b(you\s+make\s+me\s+sick|i\s+can't\s+stand\s+you|i\s+cant\s+stand\s+you|i\s+loathe\s+you|you're\s+disgusting|youre\s+disgusting|you're\s+pathetic|youre\s+pathetic)\b",
        caseSensitive: false),
    RegExp(
        r'\b(go\s+to\s+hell|burn\s+in\s+hell|rot\s+in\s+hell)\b',
        caseSensitive: false),
    RegExp(r'\b(loser\s+loser|idiot\s+idiot|stupid\s+stupid)\b',
        caseSensitive: false),
  ];

  /// Dramatic punctuation piles often accompany hostile comments.
  static final RegExp _rantPunctuationPattern =
      RegExp(r'(!{3,}|\?{3,}|!{2,}\?|,{3,})');

  static String dialogTitleFor(ModerationSurface surface) {
    switch (surface) {
      case ModerationSurface.story:
        return 'Story needs a small change';
      case ModerationSurface.comment:
        return 'Comment needs a small change';
      case ModerationSurface.reply:
        return 'Reply needs a small change';
      case ModerationSurface.appFeedback:
        return 'Feedback needs a small change';
      case ModerationSurface.parentFeedback:
        return 'Feedback needs a small change';
      case ModerationSurface.aiPrompt:
        return 'Prompt needs a small change';
    }
  }

  /// User-facing explanation (shown in a blocking dialog).
  static String messageForResult(ModerationResult r, ModerationSurface surface) {
    if (r.isSafe) return '';

    final lead = switch (surface) {
      ModerationSurface.story =>
        'We could not save this story yet because something in the text does not meet PixiePen safety rules.',
      ModerationSurface.comment =>
        'We could not post this comment yet because something in the text does not meet PixiePen safety rules.',
      ModerationSurface.reply =>
        'We could not post this reply yet because something in the text does not meet PixiePen safety rules.',
      ModerationSurface.appFeedback =>
        'We could not send this feedback yet because something in the text does not meet PixiePen safety rules.',
      ModerationSurface.parentFeedback =>
        'We could not send this feedback yet because something in the text does not meet PixiePen safety rules.',
      ModerationSurface.aiPrompt =>
        'We could not use this prompt yet because something in the text does not meet PixiePen safety rules.',
    };

    final detail = switch (r.flagReason) {
      'personal_info' =>
        'Please do not share phone numbers or email addresses in PixiePen. If an adult needs your contact details, they can use the app in another safe way.',
      'profanity' =>
        'Some words are not allowed here. Try saying the same idea with kind, friendly language.',
      'violence' =>
        'Please avoid violent or dangerous topics. PixiePen is a gentle place for creative stories and kind chat.',
      'bullying' =>
        'Please do not use words that put others down. Everyone here deserves respect.',
      'drugs' =>
        'Please avoid drug-related topics. If you need help with something serious, talk with a trusted adult.',
      'too_long' =>
        'This text is longer than we allow in this box. Try shortening it and send again.',
      'spam_pattern' =>
        'This looks like repeated characters or spam. Try writing in normal sentences.',
      'link' =>
        'Please do not paste website links here. That helps keep everyone safer online.',
      'hostility' =>
        'That sounds hurtful or mean toward someone. Please rewrite it in a kind, respectful way so PixiePen stays friendly for everyone.',
      'toxicity_score' =>
        'Several things together (tone, punctuation, or wording) suggest this message is too harsh for PixiePen. Try calmer, kinder language.',
      'generic' => childFriendlyWarning,
      _ => childFriendlyWarning,
    };

    return '$lead\n\n$detail';
  }

  ModerationResult moderateText(String text) {
    final cleanText = normalize(text);
    final lowerText = text.toLowerCase();

    if (emailRegex.hasMatch(lowerText)) {
      return const ModerationResult.unsafe(flagReason: 'personal_info');
    }

    if (phoneRegex.hasMatch(cleanText)) {
      return const ModerationResult.unsafe(flagReason: 'personal_info');
    }

    if (_containsProfanityVariant(lowerText)) {
      return const ModerationResult.unsafe(flagReason: 'profanity');
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

  /// Context-aware checks: length, links (except feedback where links may help),
  /// obvious spam patterns, then word rules on the same text.
  ModerationResult moderateWithSurface(
    ModerationSurface surface,
    String text, {
    String? storyExcerpt,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const ModerationResult.safe();
    }

    final max = maxCharsFor(surface);
    if (trimmed.length > max) {
      return const ModerationResult.unsafe(flagReason: 'too_long');
    }

    if (_spamRepeatChar.hasMatch(trimmed)) {
      return const ModerationResult.unsafe(flagReason: 'spam_pattern');
    }

    if (surface != ModerationSurface.appFeedback &&
        surface != ModerationSurface.parentFeedback &&
        _urlRegex.hasMatch(trimmed)) {
      return const ModerationResult.unsafe(flagReason: 'link');
    }

    if (surface == ModerationSurface.comment ||
        surface == ModerationSurface.reply) {
      return _moderateShortSocialText(trimmed);
    }

    final base = moderateText(trimmed);
    if (!base.isSafe) return base;

    if (_shouldRunFuzzyScan(surface, trimmed.length)) {
      final fuzzy = _fuzzyTokenScan(normalize(trimmed));
      if (!fuzzy.isSafe) return fuzzy;
    }

    final extra = storyExcerpt?.trim();
    if (extra != null && extra.isNotEmpty) {
      final combined = '$trimmed $extra';
      final comboResult = moderateText(combined);
      if (!comboResult.isSafe) return comboResult;
      if (_shouldRunFuzzyScan(surface, combined.length)) {
        final fuzzyCombo = _fuzzyTokenScan(normalize(combined));
        if (!fuzzyCombo.isSafe) return fuzzyCombo;
      }
    }

    return const ModerationResult.safe();
  }

  /// Live preview tuned for **story writing** (very lenient — fiction-friendly).
  ///
  /// Only blocks things that are unsafe **regardless of narrative context** and
  /// have no legitimate use in a children's story:
  ///   • real profanity / swear words
  ///   • phone numbers, emails (PII leak)
  ///   • external URLs (off-platform contact)
  ///   • extreme character spam (e.g. `aaaaaaa…`)
  ///
  /// It deliberately does NOT flag:
  ///   • violence words (kill, sword, weapon, die)
  ///   • "hate" / hostility phrases — characters can argue
  ///   • drugs / bullying word lists — too many false positives in dialogue
  ///   • tone, intent, or context
  ///
  /// Those judgements are reserved for the **Publish** step, where the full
  /// document is sent to OpenAI `omni-moderation-latest` and context-aware
  /// thresholds are applied. The live banner's job is only to prevent the
  /// obviously-bad-everywhere set — not to coach style or police fiction.
  ModerationLiveFeedback previewStoryTyping(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const ModerationLiveFeedback(
        toxicityScore: 0,
        wouldBeBlocked: false,
      );
    }

    if (_spamRepeatChar.hasMatch(trimmed)) {
      return ModerationLiveFeedback(
        toxicityScore: 95,
        wouldBeBlocked: true,
        bannerMessage: liveBannerHintForReason('spam_pattern'),
      );
    }

    final lower = trimmed.toLowerCase();
    if (emailRegex.hasMatch(lower) || phoneRegex.hasMatch(trimmed)) {
      return ModerationLiveFeedback(
        toxicityScore: 95,
        wouldBeBlocked: true,
        bannerMessage: liveBannerHintForReason('personal_info'),
      );
    }
    if (_urlRegex.hasMatch(trimmed)) {
      return ModerationLiveFeedback(
        toxicityScore: 90,
        wouldBeBlocked: true,
        bannerMessage: liveBannerHintForReason('link'),
      );
    }

    final clean = normalize(trimmed);
    if (_matchedWords(clean, profanityList).isNotEmpty) {
      return ModerationLiveFeedback(
        toxicityScore: 95,
        wouldBeBlocked: true,
        bannerMessage: liveBannerHintForReason('profanity'),
      );
    }

    return const ModerationLiveFeedback(
      toxicityScore: 0,
      wouldBeBlocked: false,
    );
  }

  /// Debounced in the UI: shows toxicity meter + whether send would be blocked.
  ModerationLiveFeedback previewWhileTyping(
    ModerationSurface surface,
    String text, {
    String? storyExcerpt,
  }) {
    final result = moderateWithSurface(
      surface,
      text,
      storyExcerpt: storyExcerpt,
    );
    if (!result.isSafe) {
      return ModerationLiveFeedback(
        toxicityScore: 100,
        wouldBeBlocked: true,
        bannerMessage: liveBannerHintForReason(result.flagReason),
      );
    }

    final displayScore = _liveDisplayRiskScore(text, surface);
    String? banner;
    if (displayScore >= 48) {
      banner =
          'This may sound quite strong. Consider softer, kinder words before you send.';
    } else if (displayScore >= 28) {
      banner = 'Tip: calm, friendly language fits PixiePen best.';
    }

    return ModerationLiveFeedback(
      toxicityScore: displayScore,
      wouldBeBlocked: false,
      bannerMessage: banner,
    );
  }

  /// Short hint for the inline banner when text would be blocked.
  static String liveBannerHintForReason(String? reason) {
    switch (reason) {
      case 'hostility':
        return 'Sounds hurtful — soften this before sending.';
      case 'toxicity_score':
        return 'Tone looks too harsh for PixiePen.';
      case 'profanity':
      case 'bullying':
      case 'violence':
        return 'Contains words that are not allowed here.';
      case 'drugs':
        return 'This topic is not allowed here.';
      case 'personal_info':
        return 'Do not share phone numbers or email addresses.';
      case 'link':
        return 'Links are not allowed here.';
      case 'too_long':
        return 'Text is too long for this box.';
      case 'spam_pattern':
        return 'Too many repeated characters.';
      default:
        return 'This may not meet PixiePen safety rules.';
    }
  }

  ModerationResult moderateStory({
    required String title,
    required String body,
  }) {
    return moderateWithSurface(
      ModerationSurface.story,
      '$title\n\n$body',
    );
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

  bool _containsProfanityVariant(String lowerText) {
    for (final pattern in _profanityPatterns) {
      if (pattern.hasMatch(lowerText)) return true;
    }
    return false;
  }

  List<String>? _cachedFuzzyTerms;

  List<String> _allFuzzyTerms() {
    _cachedFuzzyTerms ??= <String>{
      ...profanityList,
      ...violenceList,
      ...bullyingList,
      ...drugList,
    }.where((w) => w.length >= 4).toList();
    return _cachedFuzzyTerms!;
  }

  bool _shouldRunFuzzyScan(ModerationSurface surface, int byteLen) {
    if (byteLen > 20000) return false;
    switch (surface) {
      case ModerationSurface.comment:
      case ModerationSurface.reply:
        return false;
      case ModerationSurface.story:
      case ModerationSurface.aiPrompt:
        return true;
      case ModerationSurface.appFeedback:
      case ModerationSurface.parentFeedback:
        return false;
    }
  }

  ModerationResult _moderateShortSocialText(String trimmed) {
    final clean = normalize(trimmed);
    if (clean.isEmpty) return const ModerationResult.safe();

    for (final pattern in _socialHostilityPatterns) {
      if (pattern.hasMatch(clean)) {
        return const ModerationResult.unsafe(flagReason: 'hostility');
      }
    }
    if (_repeatedInsultPattern.hasMatch(clean)) {
      return const ModerationResult.unsafe(flagReason: 'hostility');
    }
    for (final pattern in _aggressiveSocialPatterns) {
      if (pattern.hasMatch(clean)) {
        return const ModerationResult.unsafe(flagReason: 'hostility');
      }
    }
    if (_aggressiveShoutingWithSlur(trimmed, clean)) {
      return const ModerationResult.unsafe(flagReason: 'hostility');
    }

    final base = moderateText(trimmed);
    if (!base.isSafe) return base;

    final agg = _aggregatedSocialToxicityScore(trimmed, clean);
    if (agg >= toxicityBlockThreshold) {
      return const ModerationResult.unsafe(flagReason: 'toxicity_score');
    }

    return const ModerationResult.safe();
  }

  ModerationResult _fuzzyTokenScan(String clean) {
    final tokens = clean.split(' ');
    var tokenBudget = 0;
    for (final token in tokens) {
      if (token.length < 4 || token.length > 18) continue;
      if (tokenBudget++ > 120) break;

      for (final bad in _allFuzzyTerms()) {
        if (bad.length < 4) continue;
        if (token == bad) continue;
        final maxDist = _maxAllowedFuzzyDistance(token.length, bad.length);
        if (maxDist == 0) continue;
        if (levenshteinDistance(token, bad) <= maxDist) {
          return ModerationResult.unsafe(
            flagReason: _flagReasonForBannedWord(bad),
            flaggedTerms: [token],
          );
        }
      }
    }
    return const ModerationResult.safe();
  }

  int _maxAllowedFuzzyDistance(int tokenLen, int badLen) {
    final m = math.min(tokenLen, badLen);
    if (m < 4) return 0;
    if (m <= 5) return 1;
    return 2;
  }

  String _flagReasonForBannedWord(String bad) {
    if (profanityList.contains(bad)) return 'profanity';
    if (violenceList.contains(bad)) return 'violence';
    if (bullyingList.contains(bad)) return 'bullying';
    if (drugList.contains(bad)) return 'drugs';
    return 'generic';
  }

  double _aggregatedSocialToxicityScore(String raw, String clean) {
    var score = 0.0;
    if (_rantPunctuationPattern.hasMatch(raw)) score += 26;
    final shout = _shoutingAggressionRatio(raw);
    if (shout >= 0.52) score += 32;
    if (shout >= 0.48 && _rantPunctuationPattern.hasMatch(raw)) {
      score += 22;
    }
    if (shout >= 0.45 &&
        RegExp(r'\b(hate|stupid|idiot|ugly|loser|moron|dumb|pathetic|die|kill|hell)\b')
            .hasMatch(clean)) {
      score += 28;
    }
    return math.min(100, score);
  }

  bool _aggressiveShoutingWithSlur(String raw, String clean) {
    if (_shoutingAggressionRatio(raw) < 0.58) return false;
    return RegExp(
      r'\b(hate|stupid|idiot|ugly|loser|moron|dumb|pathetic|trash|garbage|die|kill|hell|fuck|shit|bitch|asshole)\b',
    ).hasMatch(clean);
  }

  double _shoutingAggressionRatio(String raw) {
    var letters = 0;
    var uppercaseLetters = 0;
    for (final unit in raw.runes) {
      if (unit >= 65 && unit <= 90) {
        letters++;
        uppercaseLetters++;
      } else if (unit >= 97 && unit <= 122) {
        letters++;
      }
    }
    if (letters < 16) return 0;
    return uppercaseLetters / letters;
  }

  double _liveDisplayRiskScore(String raw, ModerationSurface surface) {
    if (surface == ModerationSurface.comment ||
        surface == ModerationSurface.reply) {
      final clean = normalize(raw);
      if (clean.isEmpty) return 0;
      var s = 0.0;
      if (_rantPunctuationPattern.hasMatch(raw)) s += 20;
      final shout = _shoutingAggressionRatio(raw);
      if (shout >= 0.48) s += 24;
      if (shout >= 0.42 && _rantPunctuationPattern.hasMatch(raw)) s += 14;
      return math.min(100, s);
    }
    if (surface == ModerationSurface.appFeedback ||
        surface == ModerationSurface.parentFeedback) {
      var s = 0.0;
      if (_rantPunctuationPattern.hasMatch(raw)) s += 14;
      if (_shoutingAggressionRatio(raw) >= 0.52) s += 18;
      return math.min(42, s);
    }
    return 0;
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
