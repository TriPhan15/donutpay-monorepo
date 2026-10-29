import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/widgets/inputs/date_picker_sheet.dart';

const String _title = 'Chọn ngày giao dịch';

String _dayMonth(DateTime day) => DateFormat('dd/MM').format(day);

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  late List<DateTime?> results;

  setUp(() => results = []);

  /// Opens the sheet from a button and records what it closes with.
  Future<void> open(
    WidgetTester tester, {
    required DateTime initial,
    DateTime? firstDate,
    DateTime? lastDate,
    DateTime? lastRecordedDay,
    Locale locale = const Locale('vi'),
    String title = _title,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => results.add(
                  await showDatePickerSheet(
                    context,
                    initial: initial,
                    firstDate: firstDate ?? DateTime(2000),
                    lastDate: lastDate ?? DateTime(2100),
                    title: title,
                    lastRecordedDay: lastRecordedDay,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// The cell of [day] in the month grid.
  Finder cell(int day) => find.byKey(ValueKey('day-$day'));

  BoxDecoration? decorationOf(WidgetTester tester, int day) =>
      tester
              .widget<Container>(
                find
                    .descendant(of: cell(day), matching: find.byType(Container))
                    .first,
              )
              .decoration
          as BoxDecoration?;

  testWidgets(
    'shows the title, Hôm nay / Hôm qua with their dd/MM, and a Monday-first Vietnamese month',
    (tester) async {
      await open(tester, initial: today);

      expect(find.text(_title), findsOneWidget);
      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text(_dayMonth(today)), findsOneWidget);
      expect(find.text('Hôm qua'), findsOneWidget);
      expect(find.text(_dayMonth(yesterday)), findsOneWidget);
      expect(find.text('Tháng ${today.month}, ${today.year}'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('T2')).dx,
        lessThan(tester.getTopLeft(find.text('CN')).dx),
      );
      // The first of the month sits under its weekday.
      final first = DateTime(today.year, today.month);
      const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
      expect(
        tester.getCenter(cell(1)).dx,
        moreOrLessEquals(
          tester.getCenter(find.text(weekdays[first.weekday - 1])).dx,
          epsilon: 1,
        ),
      );
    },
  );

  testWidgets(
    'Ngày vừa ghi appears with its date when it differs from today and yesterday',
    (tester) async {
      final earlier = DateTime(now.year, now.month, now.day - 4);
      await open(tester, initial: today, lastRecordedDay: earlier);

      expect(find.text('Ngày vừa ghi'), findsOneWidget);
      expect(find.text(_dayMonth(earlier)), findsOneWidget);
    },
  );

  testWidgets('Ngày vừa ghi is left out when it is yesterday or unknown', (
    tester,
  ) async {
    await open(tester, initial: today, lastRecordedDay: yesterday);
    expect(find.text('Ngày vừa ghi'), findsNothing);

    await open(tester, initial: today);
    expect(find.text('Ngày vừa ghi'), findsNothing);
  });

  testWidgets('a last recorded day outside the range is not offered', (
    tester,
  ) async {
    await open(
      tester,
      initial: today,
      firstDate: DateTime(now.year, now.month, now.day - 2),
      lastRecordedDay: DateTime(now.year, now.month, now.day - 4),
    );

    expect(find.text('Ngày vừa ghi'), findsNothing);
  });

  testWidgets('tapping a day closes the sheet with that day', (tester) async {
    await open(tester, initial: DateTime(2026, 3, 15, 9));

    await tester.tap(cell(20));
    await tester.pumpAndSettle();

    expect(results, [DateTime(2026, 3, 20)]);
    expect(find.text(_title), findsNothing);
  });

  testWidgets('tapping a quick chip closes the sheet with its day', (
    tester,
  ) async {
    await open(tester, initial: DateTime(2026, 3, 15));

    await tester.tap(find.text('Hôm qua'));
    await tester.pumpAndSettle();

    expect(results, [yesterday]);
  });

  testWidgets('the close button returns null', (tester) async {
    await open(tester, initial: today);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('today is outlined, the chosen day filled', (tester) async {
    final chosen = today.day == 1
        ? DateTime(today.year, today.month, 2)
        : DateTime(today.year, today.month, 1);
    await open(tester, initial: chosen);
    final colors = AppTheme.lightTheme.colorScheme;

    final todayBox = decorationOf(tester, today.day)!;
    expect(todayBox.border, isA<Border>());
    expect((todayBox.border! as Border).top.color, colors.primary);
    expect(decorationOf(tester, chosen.day)!.color, colors.primary);
  });

  testWidgets('days after lastDate are faded and do not respond', (
    tester,
  ) async {
    // A month with a 28th, and a last day before it.
    await open(
      tester,
      initial: DateTime(2026, 2, 10),
      lastDate: DateTime(2026, 2, 20),
    );

    final faded = tester.widget<Text>(
      find.descendant(of: cell(25), matching: find.byType(Text)),
    );
    expect(faded.style!.color!.a, lessThan(0.5));
    await tester.tap(cell(25));
    await tester.pumpAndSettle();
    expect(results, isEmpty, reason: 'the sheet stays open');
    expect(find.text(_title), findsOneWidget);
  });

  testWidgets(
    '› stops at the month of lastDate and ‹ at the month of firstDate',
    (tester) async {
      await open(
        tester,
        initial: DateTime(2026, 2, 10),
        firstDate: DateTime(2026, 1, 5),
        lastDate: DateTime(2026, 3, 20),
      );
      IconButton nav(String tooltip) => tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      );

      await tester.tap(find.byTooltip('Tháng sau'));
      await tester.pumpAndSettle();
      expect(find.text('Tháng 3, 2026'), findsOneWidget);
      expect(nav('Tháng sau').onPressed, isNull);

      await tester.tap(find.byTooltip('Tháng trước'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tháng trước'));
      await tester.pumpAndSettle();
      expect(find.text('Tháng 1, 2026'), findsOneWidget);
      expect(nav('Tháng trước').onPressed, isNull);
    },
  );

  testWidgets('quick chips outside the range are left out', (tester) async {
    await open(
      tester,
      initial: DateTime(2026, 2, 10),
      lastDate: DateTime(2026, 2, 20),
    );

    expect(find.text('Hôm nay'), findsNothing);
    expect(find.text('Hôm qua'), findsNothing);
  });

  testWidgets(
    'a short landscape screen scrolls the sheet instead of overflowing',
    (tester) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await open(tester, initial: DateTime(2026, 8, 10));

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        cell(31),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(cell(31));
      await tester.pumpAndSettle();
      expect(results, [DateTime(2026, 8, 31)]);
    },
  );

  testWidgets('speaks English', (tester) async {
    await open(
      tester,
      initial: DateTime(2026, 10, 3),
      locale: const Locale('en'),
      title: 'Choose the transaction date',
    );

    expect(find.text('Choose the transaction date'), findsOneWidget);
    expect(find.text('Mo'), findsOneWidget);
    expect(find.text('Su'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });
}
