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

    test('allows positive comment even when story title has risky words', () {
      final result = service.moderateWithSurface(
        ModerationSurface.comment,
        'Great story, I loved the ending!',
        storyExcerpt: 'The Wooden Toy Gun',
      );

      expect(result.isSafe, isTrue);
    });

    test('allows positive comments with words close to blocked terms', () {
      final result = service.moderateWithSurface(
        ModerationSurface.comment,
        'Classic work, this is such a good story!',
      );

      expect(result.isSafe, isTrue);
    });

    test('still blocks directly hostile comments', () {
      final result = service.moderateWithSurface(
        ModerationSurface.comment,
        'You are stupid',
      );

      expect(result.isSafe, isFalse);
      expect(result.flagReason, 'bullying');
    });

    test('allows feedback category text that says I need help', () {
      final result = service.moderateWithSurface(
        ModerationSurface.appFeedback,
        'I need help',
      );

      expect(result.isSafe, isTrue);
    });

    test('still blocks exact drug terms in feedback', () {
      final result = service.moderateWithSurface(
        ModerationSurface.appFeedback,
        'Someone mentioned weed',
      );

      expect(result.isSafe, isFalse);
      expect(result.flagReason, 'drugs');
    });
  });
}
