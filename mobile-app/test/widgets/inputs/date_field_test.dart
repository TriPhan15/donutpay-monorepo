import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/di/injection_container.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/repositories/settings_repository.dart';
import 'package:finance_ai_app/widgets/inputs/date_field.dart';

import '../../helpers/fake_settings_repository.dart';

String _shown(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

/// Holds the value the way a form does and records each change.
class _Host extends StatefulWidget {
  const _Host({
    required this.initial,
    required this.changes,
    this.forTransaction = false,
    this.errorText,
  });

  final DateTime initial;
  final List<DateTime> changes;
  final bool forTransaction;
  final String? errorText;

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
          forTransaction: widget.forTransaction,
          errorText: widget.errorText,
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
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  late List<DateTime> changes;

  setUp(() => changes = []);

  Future<void> pump(
    WidgetTester tester,
    DateTime initial, {
    Locale locale = const Locale('vi'),
    bool forTransaction = false,
    String? errorText,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _Host(
          initial: initial,
          changes: changes,
          forTransaction: forTransaction,
          errorText: errorText,
        ),
      ),
    );
  }

  testWidgets('today reads Hôm nay, dd/MM/yyyy', (tester) async {
    await pump(tester, now);

    expect(find.text('Hôm nay, ${_shown(now)}'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
    expect(
      find.byType(ChoiceChip),
      findsNothing,
      reason: 'the quick days live in the sheet',
    );
  });

  testWidgets('yesterday reads Hôm qua, dd/MM/yyyy', (tester) async {
    await pump(tester, yesterday);

    expect(find.text('Hôm qua, ${_shown(yesterday)}'), findsOneWidget);
  });

  testWidgets('another day reads dd/MM/yyyy', (tester) async {
    await pump(tester, DateTime(2026, 3, 15));

    expect(find.text('15/03/2026'), findsOneWidget);
  });

  testWidgets(
    'a tap opens the sheet; a picked day keeps the time of the value',
    (tester) async {
      await pump(tester, DateTime(2026, 3, 15, 18, 40));

      await tester.tap(find.text('15/03/2026'));
      await tester.pumpAndSettle();
      expect(find.text('Chọn ngày'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('day-20')));
      await tester.pumpAndSettle();

      expect(changes.single, DateTime(2026, 3, 20, 18, 40));
      expect(find.text('20/03/2026'), findsOneWidget);
    },
  );

  testWidgets('choosing the shown day changes nothing', (tester) async {
    await pump(tester, DateTime(2026, 3, 15, 9));

    await tester.tap(find.text('15/03/2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('day-15')));
    await tester.pumpAndSettle();

    expect(changes, isEmpty);
  });

  group('with settings', () {
    late FakeSettingsRepository settings;

    setUp(() {
      settings = FakeSettingsRepository();
      sl.registerSingleton<SettingsRepository>(settings);
    });
    tearDown(() => sl.unregister<SettingsRepository>());

    testWidgets('forTransaction offers the last recorded day from settings', (
      tester,
    ) async {
      settings.lastRecordedDay = DateTime(now.year, now.month, now.day - 4);
      await pump(tester, now, forTransaction: true);

      await tester.tap(find.byIcon(Icons.calendar_today_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Chọn ngày giao dịch'), findsOneWidget);
      await tester.tap(find.text('Ngày vừa ghi'));
      await tester.pumpAndSettle();
      expect(
        changes.single,
        DateTime(
          now.year,
          now.month,
          now.day - 4,
          now.hour,
          now.minute,
          now.second,
          now.millisecond,
          now.microsecond,
        ),
      );
    });

    testWidgets(
      'a plain date field titles the sheet Chọn ngày and offers no last recorded day',
      (tester) async {
        settings.lastRecordedDay = DateTime(now.year, now.month, now.day - 4);
        await pump(tester, now);

        await tester.tap(find.byIcon(Icons.calendar_today_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Chọn ngày'), findsOneWidget);
        expect(find.text('Ngày vừa ghi'), findsNothing);
      },
    );
  });

  testWidgets('forTransaction without settings registered still opens', (
    tester,
  ) async {
    await pump(tester, now, forTransaction: true);

    await tester.tap(find.byIcon(Icons.calendar_today_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Chọn ngày giao dịch'), findsOneWidget);
    expect(find.text('Ngày vừa ghi'), findsNothing);
  });

  testWidgets('an error outlines the field and is shown under it', (
    tester,
  ) async {
    await pump(tester, now, errorText: 'Ngày không hợp lệ');

    expect(find.text('Ngày không hợp lệ'), findsOneWidget);
  });

  testWidgets('speaks English', (tester) async {
    await pump(tester, now, locale: const Locale('en'));

    expect(find.text('Today, ${_shown(now)}'), findsOneWidget);
  });
}
