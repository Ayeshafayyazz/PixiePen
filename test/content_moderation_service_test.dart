import 'package:flutter_test/flutter_test.dart';
import 'package:pixiepen/services/content_moderation_service.dart';

void main() {
  group('ContentModerationService', () {
    final service = ContentModerationService();

    test('allows kind story text', () {
      final result = service.moderateStory(
        title: 'The Brave Garden',
        body: 'Mia helped her friends plant flowers after school.',
      );

      expect(result.isSafe, isTrue);
    });

    test('blocks categorized keywords after normalization', () {
      final result = service.moderateText('You are a st.upid loser!');

      expect(result.isSafe, isFalse);
      expect(result.flagReason, 'bullying');
      expect(result.flaggedTerms, containsAll(['stupid', 'loser']));
    });

    test('blocks phone numbers and emails', () {
      expect(service.moderateText('Call me at 1234567890').isSafe, isFalse);
      expect(service.moderateText('email me kid@example.com').isSafe, isFalse);
    });

    test('sanitizes matched keyword terms', () {
      expect(service.sanitize('That was stupid.'), 'That was ***.');
    });
  });
}
