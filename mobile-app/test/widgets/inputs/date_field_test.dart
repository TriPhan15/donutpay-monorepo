import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/widgets/inputs/date_field.dart';

const String _today = 'Hôm nay';
const String _yesterday = 'Hôm qua';
const String _backToToday = 'Về hôm nay';

String _shown(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

/// Holds the value the way a form does and records each change.
class _Host extends StatefulWidget {
  const _Host({required this.initial, required this.changes});

  final DateTime initial;
  final List<DateTime> changes;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late DateTime _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DateField(
          value: _value,
          onChanged: (date) {
            widget.changes.add(date);
            setState(() => _value = date);
          },
        ),
      ),
    );
  }
}

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  late List<DateTime> changes;

  setUp(() => changes = []);

  Future<void> pump(
    WidgetTester tester,
    DateTime initial, {
    Locale locale = const Locale('vi'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _Host(initial: initial, changes: changes),
      ),
    );
  }

  bool selected(WidgetTester tester, String label) => tester
      .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
      .selected;

  testWidgets('on today: the Today chip is selected and there is no reset', (
    tester,
  ) async {
    await pump(tester, now);

    expect(find.text(_shown(now)), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
    expect(selected(tester, _today), isTrue);
    expect(selected(tester, _yesterday), isFalse);
    expect(find.byTooltip(_backToToday), findsNothing);
  });

  testWidgets(
    'the Yesterday chip moves the day and keeps the time, then the reset goes back to today',
    (tester) async {
      final start = DateTime(today.year, today.month, today.day, 8, 30);
      await pump(tester, start);

      await tester.tap(find.text(_yesterday));
      await tester.pumpAndSettle();

      expect(
        changes.single,
        DateTime(yesterday.year, yesterday.month, yesterday.day, 8, 30),
      );
      expect(find.text(_shown(yesterday)), findsOneWidget);
      expect(selected(tester, _yesterday), isTrue);
      expect(find.byTooltip(_backToToday), findsOneWidget);

      await tester.tap(find.byTooltip(_backToToday));
      await tester.pumpAndSettle();

      expect(changes.last, start);
      expect(find.byTooltip(_backToToday), findsNothing);
    },
  );

  testWidgets('choosing the day that is already shown changes nothing', (
    tester,
  ) async {
    await pump(tester, now);

    await tester.tap(find.text(_today));
    await tester.pumpAndSettle();

    expect(changes, isEmpty);
  });

  testWidgets('a tap on the field opens the date picker on the shown day', (
    tester,
  ) async {
    final shown = DateTime(2026, 3, 15, 9);
    await pump(tester, shown);

    await tester.tap(find.text(_shown(shown)));
    await tester.pumpAndSettle();

    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.initialDate, DateTime(2026, 3, 15));

    await tester.tap(find.text('20'));
    // Cancel, then OK, in the language of the picker.
    await tester.tap(
      find
          .descendant(
            of: find.byType(DatePickerDialog),
            matching: find.byType(TextButton),
          )
          .last,
    );
    await tester.pumpAndSettle();

    expect(changes.single, DateTime(2026, 3, 20, 9));
    expect(find.text('20/03/2026'), findsOneWidget);
  });

  testWidgets('speaks English', (tester) async {
    await pump(tester, DateTime(2026, 3, 15), locale: const Locale('en'));

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.byTooltip('Back to today'), findsOneWidget);
  });
}
