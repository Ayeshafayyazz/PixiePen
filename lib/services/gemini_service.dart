import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class StoryModerationVerdict {
  final bool isSafe;
  final String? flaggedSentence;
  final String? reason;

  const StoryModerationVerdict.safe()
      : isSafe = true,
        flaggedSentence = null,
        reason = null;

  const StoryModerationVerdict.unsafe({
    this.flaggedSentence,
    this.reason,
  }) : isSafe = false;
}

/// AI helper for child-safe story features.
///
/// **Note:** the class is still called `GeminiService` for backwards
/// compatibility with existing call-sites. Internally it now uses OpenAI
/// (`gpt-4o-mini` for text + free `omni-moderation-latest` for moderation),
/// matching the rest of the app's AI stack.
class GeminiService {
  static const String _chatModel = 'gpt-4o-mini';
  static const String _moderationModel = 'omni-moderation-latest';
  static const Duration _requestTimeout = Duration(seconds: 15);

  static const String _chatUrl =
      'https://api.openai.com/v1/chat/completions';
  static const String _moderationUrl =
      'https://api.openai.com/v1/moderations';

  /// Kid-safety category thresholds — stricter than OpenAI's default for an
  /// ages 9-12 app. Anything scoring above these gets treated as unsafe.
  static const Map<String, double> _strictThresholds = {
    'sexual': 0.1,
    'sexual/minors': 0.05,
    'violence': 0.4,
    'violence/graphic': 0.2,
    'hate': 0.3,
    'hate/threatening': 0.2,
    'harassment': 0.3,
    'harassment/threatening': 0.2,
    'self-harm': 0.2,
    'self-harm/intent': 0.1,
    'self-harm/instructions': 0.1,
    'illicit': 0.3,
    'illicit/violent': 0.2,
  };

  String get _apiKey => dotenv.env['OPENAI_API_KEY']?.trim() ?? '';

  bool get _hasApiKey =>
      _apiKey.isNotEmpty && _apiKey != 'your_api_key_here';

  bool get isConfigured => _hasApiKey;

  /// Rewrites a child-safe story scene from a selected perspective.
  ///
  /// Supported [shiftType]s:
  ///   • `first_person`, `second_person`, `third_person` — faithful narrative
  ///     voice conversion (pronouns + verb conjugation only, no plot changes).
  ///   • `villain`, `side_character`, `time_shift`, `emotional_joy`,
  ///     `emotional_fear` —
  ///     creative re-imaginings (the model may reinterpret freely).
  Future<String> shiftPerspective(String shiftType, String storyText) async {
    final trimmed = storyText.trim();
    try {
      if (!_hasApiKey || trimmed.isEmpty) return trimmed;

      final isPersonShift = shiftType == 'first_person' ||
          shiftType == 'second_person' ||
          shiftType == 'third_person';

      final system = isPersonShift
          // Faithful rewrite: preserve everything except narrative voice.
          ? 'You rewrite children\'s stories (ages 9-12) into a different '
              'narrative voice. Rules you MUST follow:\n'
              '• Preserve the plot, characters, character names, dialogue, '
              'setting, mood, and length exactly.\n'
              '• Change ONLY pronouns and verb conjugation so the grammar is '
              'natural in the requested voice.\n'
              '• Do not summarize, paraphrase, add scenes, or remove scenes.\n'
              '• Keep all dialogue inside quotes unchanged in meaning '
              '(adjusting only the surrounding narrative voice).\n'
              '• Return only the rewritten story — no preamble, no notes.'
          // Creative shift: model may reinterpret.
          : 'You rewrite scenes for children ages 9-12. Always keep content '
              'strictly child-safe: no scary, violent, romantic, or adult '
              'details. Return only the rewritten scene with no preamble.';

      final instruction = _perspectivePrompt(shiftType);
      final result = await _chat(
        system: system,
        // Lower temperature for faithful rewrites so the model sticks to the
        // original text instead of getting "creative".
        temperature: isPersonShift ? 0.2 : 0.6,
        user: '$instruction.\n\nStory:\n$trimmed',
      );
      return result.isEmpty ? trimmed : result;
    } catch (_) {
      return trimmed;
    }
  }

  /// Rewrites a story using a reader-provided custom instruction.
  ///
  /// This is used by the "Custom Suggestion" story-shift option in the reader.
  /// The instruction is treated as guidance only and is wrapped in child-safety
  /// constraints so output remains age-appropriate for 9-12.
  Future<String> shiftPerspectiveBySuggestion(
    String suggestion,
    String storyText,
  ) async {
    final trimmedStory = storyText.trim();
    final trimmedSuggestion = suggestion.trim();
    if (!_hasApiKey || trimmedStory.isEmpty || trimmedSuggestion.isEmpty) {
      return trimmedStory;
    }

    try {
      final result = await _chat(
        system:
            'You rewrite scenes for children ages 9-12. Always keep content '
            'strictly child-safe: no scary, violent, romantic, or adult '
            'details. Follow the user suggestion closely while preserving the '
            'core plot and character names unless explicitly asked to change '
            'them. Return only the rewritten story text with no preamble.',
        temperature: 0.6,
        user:
            'User suggestion for rewriting:\n$trimmedSuggestion\n\n'
            'Original story:\n$trimmedStory',
      );
      return result.isEmpty ? trimmedStory : result;
    } catch (_) {
      return trimmedStory;
    }
  }

  /// Generates child-safe eBook cover metadata as a JSON map.
  Future<Map<String, String>> generateEbookCover(
    String storyTitle,
    String storyText,
  ) async {
    final fallback = <String, String>{
      'title': storyTitle.trim().isEmpty ? 'Untitled Story' : storyTitle.trim(),
      'tagline': 'A magical child-friendly adventure',
      'theme': 'purple and gold',
      'mood': 'magical',
    };

    try {
      if (!_hasApiKey) return fallback;

      final raw = await _chat(
        system:
            'You create child-safe (ages 9-12) eBook cover metadata. '
            'Always return JSON only, no markdown, with EXACTLY these string '
            'keys: title, tagline, theme, mood.',
        user:
            'Story title: $storyTitle\nStory text: $storyText',
        jsonMode: true,
      );

      final parsed = _parseJsonObject(raw);
      return {
        'title': _readJsonString(parsed, 'title', fallback['title']!),
        'tagline': _readJsonString(parsed, 'tagline', fallback['tagline']!),
        'theme': _readJsonString(parsed, 'theme', fallback['theme']!),
        'mood': _readJsonString(parsed, 'mood', fallback['mood']!),
      };
    } catch (_) {
      return fallback;
    }
  }

  /// Checks whether text is appropriate for children ages 9-12.
  ///
  /// Uses OpenAI's free Moderation API plus stricter kid-safety thresholds.
  ///
  /// By default this is fail-open (`failOpen = true`) so temporary network/API
  /// errors do not block long-form authoring. For short social surfaces (e.g.
  /// comments/replies) callers can pass `failOpen: false` to enforce strict
  /// moderation when local checks are inconclusive.
  Future<bool> moderateContent(String text, {bool failOpen = true}) async {
    final input = text.trim();
    if (input.isEmpty) return true;
    if (!_hasApiKey) return failOpen;

    try {
      final response = await http
          .post(
            Uri.parse(_moderationUrl),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _moderationModel,
              'input': input,
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return failOpen;
      }

      final decoded = jsonDecode(response.body);
      final results = decoded is Map ? decoded['results'] : null;
      if (results is! List || results.isEmpty) return failOpen;
      final first = results.first;
      if (first is! Map) return failOpen;

      if (first['flagged'] == true) return false;

      final scores = first['category_scores'];
      if (scores is Map) {
        for (final entry in _strictThresholds.entries) {
          final value = scores[entry.key];
          if (value is num && value.toDouble() > entry.value) {
            return false;
          }
        }
      }
      return true;
    } catch (_) {
      return failOpen;
    }
  }

  /// Strict moderation policy for community comments/replies.
  ///
  /// Rules requested by product:
  /// - allow comments that are positive OR neutral, as long as they are
  ///   respectful and appropriate
  /// - reject profanity, vulgarity, hate, harassment, bullying, threats,
  ///   discrimination, sexual content, abusive language, and other harmful text
  /// - if OpenAI Moderation API is unavailable, fail closed (do not allow posting)
  Future<bool> moderateCommunityComment(String text) async {
    final input = text.trim();
    if (input.isEmpty) return true;
    if (!_hasApiKey) return false;

    // Pass 1: OpenAI Moderation API (broad safety categories).
    final safeByModerationApi = await moderateContent(input, failOpen: false);
    if (!safeByModerationApi) return false;

    // Pass 2: Context/tone gate for community quality.
    //
    // Important: this pass should reduce false negatives after Moderation API,
    // not create false positives for harmless comments. So if this classifier
    // fails transiently or returns malformed JSON, we allow by default because
    // pass 1 already performed strict fail-closed moderation.
    try {
      final raw = await _chat(
        system:
            'You are a community comment safety checker for children ages 9-12. '
            'Allow comments that are respectful, appropriate, and either '
            'positive or neutral. Do NOT require explicit positivity. '
            'Reject comments that are rude, hostile, insulting, degrading, '
            'sarcastically abusive, bullying, threatening, discriminatory, '
            'sexual, or otherwise harmful. Reject anything with profanity, '
            'vulgar language, hate speech, harassment, bullying, threats, '
            'discrimination, sexual content, abusive tone, or harmful intent. '
            'Return JSON ONLY with keys: allow (boolean), reason (string). '
            'Examples that should ALLOW: "nice to meet you", '
            '"good job on your story", "thanks for sharing".',
        user: 'Comment:\n$input',
        jsonMode: true,
        temperature: 0,
      );

      final parsed = _parseJsonObject(raw);
      final allow = parsed['allow'];
      if (allow is bool) return allow;
      return true; // avoid false blocks for harmless comments
    } catch (_) {
      return true; // avoid false blocks for harmless comments
    }
  }

  /// Context-aware moderation for full stories at publish/save time.
  ///
  /// Judges sentences by meaning and tone — not isolated words — so fictional
  /// adventure (swords, dragons, mild peril) can pass when kind and age-appropriate.
  Future<StoryModerationVerdict> moderateStoryContent({
    required String title,
    required String body,
  }) async {
    final storyTitle = title.trim();
    final storyBody = body.trim();
    final combined =
        storyTitle.isEmpty ? storyBody : '$storyTitle\n\n$storyBody';
    if (combined.trim().isEmpty) {
      return const StoryModerationVerdict.safe();
    }
    if (!_hasApiKey) return const StoryModerationVerdict.safe();

    try {
      final raw = await _chat(
        system:
            'You review children\'s creative stories (ages 9-12) for PixiePen. '
            'Judge by CONTEXT and overall sentence meaning — NOT isolated words. '
            'ALLOW age-appropriate fiction: adventure, fantasy, heroes vs villains, '
            'mild peril, characters overcoming fears, and neutral or gently sad '
            'storytelling that is not harsh or cruel. Words like fight, kill, sword, '
            'weapon, or battle are ALLOWED when they describe fictional story action '
            'and do NOT promote real-world violence, cruelty, or fear. '
            'ALLOW positive, neutral, and relevant sentences that sound kind. '
            'REJECT only when a specific sentence is profane, sexually inappropriate, '
            'hateful, bullying, promotes real violence/cruelty, self-harm, or is '
            'genuinely harsh or frightening for children. '
            'If rejecting, copy the EXACT problematic sentence from the story. '
            'Return JSON ONLY with keys: allow (boolean), reason (string), '
            'flagged_sentence (string or null).',
        user: 'Title:\n$storyTitle\n\nStory:\n$storyBody',
        jsonMode: true,
        temperature: 0,
      );

      final parsed = _parseJsonObject(raw);
      final allow = parsed['allow'];
      if (allow is bool && allow) {
        return const StoryModerationVerdict.safe();
      }
      if (allow is bool && !allow) {
        final sentence = parsed['flagged_sentence']?.toString().trim();
        final reason = parsed['reason']?.toString().trim();
        return StoryModerationVerdict.unsafe(
          flaggedSentence:
              sentence != null && sentence.isNotEmpty ? sentence : null,
          reason: reason != null && reason.isNotEmpty ? reason : null,
        );
      }
      return const StoryModerationVerdict.safe();
    } catch (_) {
      final apiSafe = await moderateContent(combined, failOpen: true);
      if (!apiSafe) {
        return const StoryModerationVerdict.unsafe(
          reason: 'This story may include content that is not safe for PixiePen.',
        );
      }
      return const StoryModerationVerdict.safe();
    }
  }

  /// Creates a colorful child-safe illustration prompt from a story.
  ///
  /// Accepts either a plain story or a combined string that includes a title
  /// (e.g. produced by the write-story screen). The title, when present, is
  /// used as the main subject of the cover.
  Future<String> generateStoryImagePrompt(String storyText) async {
    const fallback =
        'Colorful magical child-friendly book cover illustration, '
        'whimsical storybook style, soft lighting, cheerful mood, '
        'age-appropriate for children 9-12.';

    try {
      if (!_hasApiKey || storyText.trim().isEmpty) return fallback;

      final raw = await _chat(
        system:
            'You design book-cover illustration prompts for children ages '
            '9-12. Reply with the prompt text only, no preamble.',
        user:
            'Read the input below. It may include a TITLE and a STORY.\n'
            'Write ONE detailed image-generation prompt for a STORY COVER '
            'that:\n'
            '- Makes the TITLE the central subject and mood of the cover.\n'
            '- Uses key characters, setting, and atmosphere from the STORY.\n'
            '- Is colorful, magical, whimsical storybook style with soft '
            'lighting.\n'
            '- Is strictly child-safe (no scary, violent, romantic, or '
            'adult content).\n'
            '- Does NOT contain any text, letters, or watermarks in the '
            'image.\n\n'
            'Input:\n$storyText',
      );

      return raw.isEmpty ? fallback : raw;
    } catch (_) {
      return fallback;
    }
  }

  /// Internal: single chat-completion helper using `gpt-4o-mini`.
  Future<String> _chat({
    required String system,
    required String user,
    bool jsonMode = false,
    double temperature = 0.6,
  }) async {
    final body = <String, dynamic>{
      'model': _chatModel,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      'temperature': temperature,
    };
    if (jsonMode) {
      body['response_format'] = {'type': 'json_object'};
    }

    final response = await http
        .post(
          Uri.parse(_chatUrl),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return '';
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return '';
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return '';
    final first = choices.first;
    if (first is! Map) return '';
    final message = first['message'];
    if (message is! Map) return '';
    final content = message['content'];
    return content is String ? content.trim() : '';
  }

  String _perspectivePrompt(String shiftType) {
    switch (shiftType) {
      case 'first_person':
        return 'Rewrite this story strictly in FIRST PERSON. The main '
            'character narrates using I, me, my, mine, we, us, our. Convert '
            'every relevant pronoun and conjugate every verb correctly '
            '(e.g. "she goes" → "I go", "you were" → "I was"). Keep all '
            'character names, dialogue, plot, and length exactly the same';
      case 'second_person':
        return 'Rewrite this story strictly in SECOND PERSON. Address the '
            'main character as "you" throughout, using you, your, yours. '
            'Convert every relevant pronoun and conjugate every verb '
            'correctly (e.g. "she goes" → "you go", "I was" → "you were"). '
            'Keep all character names, dialogue, plot, and length exactly '
            'the same';
      case 'third_person':
        return 'Rewrite this story strictly in THIRD PERSON. Use he, she, '
            'they, him, her, them, his, her, their and the characters\' '
            'proper names instead of I or you. Convert every relevant '
            'pronoun and conjugate every verb correctly (e.g. "I go" → '
            '"she goes", "you were" → "he was"). Keep all character names, '
            'dialogue, plot, and length exactly the same';
      case 'villain':
        return "Rewrite this children's story scene from the villain's point "
            "of view in a fun and age-appropriate way";
      case 'side_character':
        return "Rewrite this scene from a minor background character's "
            "perspective for kids";
      case 'time_shift':
        return "Rewrite this showing the same character 10 years later for a "
            "children's story";
      case 'emotional_joy':
        return 'Rewrite this scene with a joyful emotional lens, keeping it '
            'child-friendly';
      case 'emotional_fear':
        return 'Rewrite this scene with a gentle fear/tension emotional lens, '
            'keeping it child-friendly and age-appropriate';
      default:
        return "Rewrite this children's story scene in a fresh, fun, "
            "age-appropriate way";
    }
  }

  Map<String, dynamic> _parseJsonObject(String rawText) {
    final cleaned = _cleanJsonText(rawText);
    if (cleaned.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // fall through to empty map
    }
    return <String, dynamic>{};
  }

  String _cleanJsonText(String rawText) {
    var text = rawText.trim();
    if (text.startsWith('```')) {
      text = text.replaceAll(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceAll(RegExp(r'\s*```$'), '');
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return text.substring(start, end + 1);
    }
    return text;
  }

  String _readJsonString(
    Map<String, dynamic> json,
    String key,
    String fallback,
  ) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }
}
