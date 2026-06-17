import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/content_moderation_service.dart';

/// High-visibility moderation feedback (dialog centered in front of the user).
class ModerationUi {
  static Future<void> showBlockDialog(
    BuildContext context, {
    required ModerationResult result,
    required ModerationSurface surface,
    String? highlightedSentence,
    List<String> highlightedTerms = const [],
    VoidCallback? onEditSentence,
    String? extraDetail,
  }) async {
    if (result.isSafe) return;
    if (!context.mounted) return;
    var body = ContentModerationService.messageForResult(result, surface);
    final extra = extraDetail?.trim();
    if (extra != null && extra.isNotEmpty) {
      body = '$body\n\n$extra';
    }
    final title = ContentModerationService.dialogTitleFor(surface);
    return _showModerationAlert(
      context,
      title: title,
      body: body,
      highlightedSentence: highlightedSentence,
      highlightedTerms: highlightedTerms,
      onEditSentence: onEditSentence,
    );
  }

  /// Same chrome for a free-form message (e.g. server-side [ArgumentError] text).
  static Future<void> showPlainMessage(
    BuildContext context, {
    required String message,
    required ModerationSurface surface,
  }) async {
    if (!context.mounted) return;
    final title = ContentModerationService.dialogTitleFor(surface);
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
    final full = '$lead\n\n$message';
    return _showModerationAlert(context, title: title, body: full);
  }

  static Future<void> _showModerationAlert(
    BuildContext context, {
    required String title,
    required String body,
    String? highlightedSentence,
    List<String> highlightedTerms = const [],
    VoidCallback? onEditSentence,
  }) async {
    if (!context.mounted) return;

    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final horizontal = math.max(16.0, w * 0.05).clamp(16.0, 40.0);
    final maxBodyWidth = math.min(440.0, w - horizontal * 2);
    final titleSize = w < 340 ? 17.0 : 19.0;
    final bodySize = w < 340 ? 14.5 : 16.0;
    final sentence = highlightedSentence?.trim();
    final hasSentence = sentence != null && sentence.isNotEmpty;
    final canJump = hasSentence && onEditSentence != null;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      useSafeArea: true,
      builder: (ctx) {
        void handleEdit() {
          Navigator.of(ctx).pop();
          onEditSentence?.call();
        }

        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 24),
          titlePadding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          icon: Icon(
            Icons.shield_outlined,
            size: w < 360 ? 38 : 44,
            color: Colors.deepPurple.shade700,
          ),
          title: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBodyWidth),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(
                    body,
                    style: TextStyle(
                      fontSize: bodySize,
                      height: 1.45,
                      color: Colors.black87,
                    ),
                  ),
                  if (hasSentence) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Sentence to fix:',
                      style: TextStyle(
                        fontSize: bodySize,
                        fontWeight: FontWeight.w700,
                        color: Colors.deepPurple.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: canJump ? handleEdit : null,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE57373)),
                          ),
                          child: SelectableText.rich(
                            _highlightedSentenceSpan(
                              sentence,
                              highlightedTerms,
                              TextStyle(
                                fontSize: bodySize,
                                height: 1.45,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (canJump) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Tap the sentence to jump to it in your story.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: bodySize - 1,
                          color: Colors.black54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: canJump ? handleEdit : () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(
                minimumSize: Size(math.min(maxBodyWidth - 24, 300), 48),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('OK, I will edit it'),
            ),
          ],
        );
      },
    );
  }

  static TextSpan _highlightedSentenceSpan(
    String sentence,
    List<String> terms,
    TextStyle style,
  ) {
    final cleanTerms = terms
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toList();
    if (cleanTerms.isEmpty) return TextSpan(text: sentence, style: style);

    final pattern = RegExp(
      r'\b(' + cleanTerms.map(RegExp.escape).join('|') + r')\b',
      caseSensitive: false,
    );
    final spans = <TextSpan>[];
    var last = 0;
    for (final match in pattern.allMatches(sentence)) {
      if (match.start > last) {
        spans.add(TextSpan(text: sentence.substring(last, match.start)));
      }
      spans.add(
        TextSpan(
          text: sentence.substring(match.start, match.end),
          style: style.copyWith(fontWeight: FontWeight.w900),
        ),
      );
      last = match.end;
    }
    if (last < sentence.length) {
      spans.add(TextSpan(text: sentence.substring(last)));
    }
    return TextSpan(style: style, children: spans);
  }
}

/// Inline banner + meter while the user types (debounce [ContentModerationService.previewWhileTyping] in the screen).
class ModerationLiveBanner extends StatelessWidget {
  final ModerationLiveFeedback? feedback;

  const ModerationLiveBanner({super.key, this.feedback});

  @override
  Widget build(BuildContext context) {
    final f = feedback;
    if (f == null) return const SizedBox.shrink();

    final show = f.wouldBeBlocked ||
        (f.bannerMessage != null && f.bannerMessage!.trim().isNotEmpty) ||
        f.toxicityScore >= 22;
    if (!show) return const SizedBox.shrink();

    final blocked = f.wouldBeBlocked;
    final mq = MediaQuery.of(context);
    final narrow = mq.size.width < 360;
    final bg = blocked ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1);
    final border = blocked ? const Color(0xFFE57373) : const Color(0xFFFFB74D);
    final icon = blocked ? Icons.warning_rounded : Icons.tips_and_updates_outlined;
    final score = (f.toxicityScore.clamp(0, 100)) / 100.0;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: narrow ? 10 : 12,
            vertical: narrow ? 10 : 11,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: narrow ? 20 : 22, color: border),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f.bannerMessage ??
                          (blocked
                              ? ContentModerationService.childFriendlyWarning
                              : ''),
                      style: TextStyle(
                        fontSize: narrow ? 13 : 14,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score,
                  minHeight: 5,
                  backgroundColor: Colors.black.withValues(alpha: 0.06),
                  color: blocked ? Colors.red.shade600 : Colors.amber.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                blocked ? 'Not ready to send' : 'Kindness meter',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
