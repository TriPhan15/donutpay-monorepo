import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/models/feedback_draft.dart';

void main() {
  group('FeedbackDraft.addChip', () {
    test('an empty comment becomes the chip', () {
      expect(FeedbackDraft.addChip('', 'Dễ dùng'), 'Dễ dùng');
      expect(FeedbackDraft.addChip('   ', 'Dễ dùng'), 'Dễ dùng');
    });

    test('a chip after typed text is joined with a comma', () {
      expect(FeedbackDraft.addChip('Hay', 'Dễ dùng'), 'Hay, Dễ dùng');
    });

    test('a trailing comma or space is not doubled', () {
      expect(FeedbackDraft.addChip('Hay, ', 'Dễ dùng'), 'Hay, Dễ dùng');
      expect(FeedbackDraft.addChip('Hay,', 'Dễ dùng'), 'Hay, Dễ dùng');
    });

    test('a chip already in the comment is not added twice', () {
      expect(FeedbackDraft.addChip('Dễ dùng', 'Dễ dùng'), 'Dễ dùng');
      expect(FeedbackDraft.addChip('Hay, Dễ dùng', 'Dễ dùng'), 'Hay, Dễ dùng');
    });
  });

  group('FeedbackDraft.hasChip', () {
    test('matches a whole comma-separated piece only', () {
      expect(FeedbackDraft.hasChip('Hay, Dễ dùng', 'Dễ dùng'), isTrue);
      expect(FeedbackDraft.hasChip(' Dễ dùng ', 'Dễ dùng'), isTrue);
      expect(FeedbackDraft.hasChip('Dễ dùng lắm', 'Dễ dùng'), isFalse);
      expect(FeedbackDraft.hasChip('', 'Dễ dùng'), isFalse);
    });
  });
}
