import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/screens/ledger/widgets/experience_rating_field.dart';
import 'package:finance_ai_app/widgets/transactions/experience_rating_badge.dart';

Widget _wrapWithL10n(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('ExperienceRatingField', () {
    test('ratingAtPosition snaps horizontal positions to 0.5 increments in [0.5, 5.0]', () {
      expect(ExperienceRatingField.ratingAtPosition(0, 160), 0.5);
      expect(ExperienceRatingField.ratingAtPosition(15, 160), 0.5);
      expect(ExperienceRatingField.ratingAtPosition(17, 160), 1.0);
      expect(ExperienceRatingField.ratingAtPosition(140, 160), 4.5);
      expect(ExperienceRatingField.ratingAtPosition(160, 160), 5.0);
    });

    testWidgets('shows unrated label initially and updates on half-star selection and clear', (tester) async {
      double? currentRating;
      final noteCtrl = TextEditingController();
      addTearDown(noteCtrl.dispose);

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _wrapWithL10n(
              ExperienceRatingField(
                rating: currentRating,
                onRatingChanged: (val) => setState(() => currentRating = val),
                reviewNoteController: noteCtrl,
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đánh giá trải nghiệm (tùy chọn)'), findsOneWidget);
      expect(find.text('Chạm hoặc vuốt sao để đánh giá (0.5 – 5.0)'), findsOneWidget);

      // Tap near 4.5★ on the star row (width = 160, dx = 140 -> 4.5)
      final starRowTopLeft = tester.getTopLeft(find.byKey(ExperienceRatingField.starRowKey));
      await tester.tapAt(starRowTopLeft + const Offset(140, 16));
      await tester.pumpAndSettle();

      expect(currentRating, 4.5);
      expect(find.text('4.5 ★'), findsOneWidget);
      expect(find.text('Trải nghiệm tốt'), findsOneWidget);

      // Tap near 0.5★ on the star row (dx = 8 -> 0.5)
      final updatedStarRowTopLeft = tester.getTopLeft(find.byKey(ExperienceRatingField.starRowKey));
      await tester.tapAt(updatedStarRowTopLeft + const Offset(8, 16));
      await tester.pumpAndSettle();

      expect(currentRating, 0.5);
      expect(find.text('0.5 ★'), findsOneWidget);
      expect(find.text('Trải nghiệm tệ'), findsOneWidget);

      // Clear rating back to null
      await tester.tap(find.byKey(ExperienceRatingField.clearButtonKey));
      await tester.pumpAndSettle();

      expect(currentRating, isNull);
      expect(find.text('Chạm hoặc vuốt sao để đánh giá (0.5 – 5.0)'), findsOneWidget);

      // Enter review note
      await tester.enterText(
        find.byKey(ExperienceRatingField.reviewNoteFieldKey),
        'Cà phê đậm vị, nhân viên thân thiện',
      );
      expect(noteCtrl.text, 'Cà phê đậm vị, nhân viên thân thiện');
    });
  });

  group('ExperienceRatingBadge', () {
    testWidgets('renders nothing when both rating and reviewNote are null/empty', (tester) async {
      await tester.pumpWidget(
        _wrapWithL10n(const ExperienceRatingBadge(rating: null, reviewNote: '')),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('renders compact badge with rating and note', (tester) async {
      await tester.pumpWidget(
        _wrapWithL10n(
          const ExperienceRatingBadge(
            rating: 4.5,
            reviewNote: 'Rất hài lòng',
            compact: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('"Rất hài lòng"'), findsOneWidget);
    });

    testWidgets('renders full badge with stars and sentiment label', (tester) async {
      await tester.pumpWidget(
        _wrapWithL10n(
          const ExperienceRatingBadge(
            rating: 5.0,
            reviewNote: 'Quán đẹp, phục vụ xuất sắc',
            compact: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('5.0 / 5.0'), findsOneWidget);
      expect(find.textContaining('Rất hài lòng'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
    });
  });
}
