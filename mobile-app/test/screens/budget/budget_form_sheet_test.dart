import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/screens/budget/budget_form_sheet.dart';

const List<BudgetCategory> _categories = [
  (id: 10, name: 'Ăn uống'),
  (id: 11, name: 'Di chuyển'),
];

Future<List<BudgetCategory>> _loadCategories() async => _categories;

/// Opens the sheet from a button, like the budget screen does, and reports how the sheet was closed.
Future<void> _openSheet(
  WidgetTester tester, {
  required Future<String?> Function(BudgetModel budget) onSubmit,
  BudgetModel? budget,
  Future<List<BudgetCategory>> Function()? loadCategories,
  void Function(bool? result)? onClosed,
  bool settle = true,
}) async {
  // Tall enough for the whole sheet (amount, period, day, categories, save) without scrolling.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => BudgetFormSheet(
                    budget: budget,
                    loadCategories: loadCategories ?? _loadCategories,
                    onSubmit: onSubmit,
                  ),
                );
                onClosed?.call(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // A sheet that is still loading keeps a spinner running, which pumpAndSettle would wait for forever.
  await (settle
      ? tester.pumpAndSettle()
      : tester.pump(const Duration(milliseconds: 400)));
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Lưu ngân sách'));
  await tester.tap(find.text('Lưu ngân sách'));
  await tester.pumpAndSettle();
}

ChoiceChip _chip(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

String _range(String periodType, [DateTime? day]) {
  final range = BudgetPeriodType.rangeContaining(
    periodType,
    day ?? DateTime.now(),
  );
  String show(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  return '${show(range.start)} – ${show(range.end)}';
}

/// The sheet is pumped without the app's localizations, so it shows the default language.
final AppLocalizations _vi = lookupAppLocalizations(const Locale('vi'));

void main() {
  testWidgets(
    'offers both periods and every category, with the month and every category preselected',
    (tester) async {
      await _openSheet(tester, onSubmit: (_) async => null);

      expect(find.text('Thiết lập ngân sách'), findsOneWidget);
      expect(_chip(tester, 'Tháng').selected, isTrue);
      expect(_chip(tester, 'Tuần').selected, isFalse);
      expect(_chip(tester, 'Năm').selected, isFalse);
      expect(
        _chip(tester, BudgetModel.allCategoriesLabel(_vi)).selected,
        isTrue,
      );
      expect(find.widgetWithText(ChoiceChip, 'Ăn uống'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Di chuyển'), findsOneWidget);
      expect(
        find.text('Tháng này: ${_range(BudgetPeriodType.month)}'),
        findsOneWidget,
      );
    },
  );

  testWidgets('choosing the week shows this week as the period', (
    tester,
  ) async {
    await _openSheet(tester, onSubmit: (_) async => null);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Tuần'));
    await tester.pumpAndSettle();

    expect(
      find.text('Tuần này: ${_range(BudgetPeriodType.week)}'),
      findsOneWidget,
    );
  });

  testWidgets(
    'the year period covers the whole calendar year and is sent as YEAR',
    (tester) async {
      BudgetModel? sent;
      await _openSheet(
        tester,
        onSubmit: (budget) async {
          sent = budget;
          return null;
        },
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Năm'));
      await tester.pumpAndSettle();
      final year = DateTime.now().year;
      expect(find.text('Năm nay: 01/01/$year – 31/12/$year'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '24000000');
      await _tapSave(tester);

      expect(sent!.periodType, BudgetPeriodType.year);
      expect(sent!.startDate, '$year-01-01');
      expect(sent!.endDate, '$year-12-31');
      expect(sent!.toJson()['periodType'], 'YEAR');
    },
  );

  testWidgets('the amount is grouped as it is typed', (tester) async {
    await _openSheet(tester, onSubmit: (_) async => null);

    await tester.enterText(find.byType(TextField), '1500000');
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '1.500.000',
    );
  });

  testWidgets('a day picked in another month moves the period to that month', (
    tester,
  ) async {
    BudgetModel? sent;
    await _openSheet(
      tester,
      onSubmit: (budget) async {
        sent = budget;
        return null;
      },
    );

    // The "Yesterday" choice of the date sheet: on the 1st of a month it is in the previous month.
    await tester.tap(find.byIcon(Icons.calendar_today_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Chọn ngày'), findsOneWidget);
    await tester.tap(find.text('Hôm qua'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2000000');
    await _tapSave(tester);

    final now = DateTime.now();
    final month = BudgetPeriodType.rangeContaining(
      BudgetPeriodType.month,
      DateTime(now.year, now.month, now.day - 1),
    );
    expect(sent!.startDate, BudgetModel.formatApiDate(month.start));
    expect(sent!.endDate, BudgetModel.formatApiDate(month.end));
  });

  group('"Khác" with a typed category name', () {
    const withOther = <BudgetCategory>[
      (id: 10, name: 'Ăn uống'),
      (id: 16, name: 'Khác'),
      (id: 31, name: 'Cà phê'),
    ];

    /// Opens the sheet on [withOther] with an amount typed and "Khác" chosen; [onSubmit] counts what is sent.
    Future<void> openWithOther(
      WidgetTester tester,
      Future<String?> Function(BudgetModel budget) onSubmit,
    ) async {
      await _openSheet(
        tester,
        loadCategories: () async => withOther,
        onSubmit: onSubmit,
      );
      await tester.enterText(find.byType(TextField), '500000');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Khác'));
      await tester.pumpAndSettle();
    }

    Finder nameField() => find.widgetWithText(TextField, 'Tên danh mục');

    testWidgets('the name field shows only once "Khác" is chosen', (
      tester,
    ) async {
      await _openSheet(
        tester,
        loadCategories: () async => withOther,
        onSubmit: (_) async => null,
      );
      expect(nameField(), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Khác'));
      await tester.pumpAndSettle();
      expect(nameField(), findsOneWidget);
      expect(
        tester.widget<TextField>(nameField()).maxLength,
        50,
        reason: 'at most 50 characters',
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Ăn uống'));
      await tester.pumpAndSettle();
      expect(nameField(), findsNothing);
    });

    testWidgets('an empty name is refused and nothing is sent', (tester) async {
      var sent = 0;
      await openWithOther(tester, (_) async {
        sent++;
        return null;
      });

      await _tapSave(tester);

      expect(find.text('Nhập tên danh mục'), findsOneWidget);
      expect(sent, 0);
    });

    testWidgets(
      'a typed name is sent trimmed by name, without a category id, for the server to reuse or create',
      (tester) async {
        BudgetModel? sent;
        await openWithOther(tester, (budget) async {
          sent = budget;
          return null;
        });
        await tester.enterText(nameField(), '  cà PHÊ ');
        await _tapSave(tester);

        expect(sent, isNotNull);
        expect(
          sent!.categoryId,
          isNull,
          reason: 'the server matches the name ignoring case',
        );
        expect(sent!.categoryName, 'cà PHÊ');
        expect(sent!.toJson()['categoryId'], isNull);
        expect(sent!.toJson()['categoryName'], 'cà PHÊ');
      },
    );

    testWidgets('a name no transaction has used yet is sent too, not refused', (
      tester,
    ) async {
      BudgetModel? sent;
      await openWithOther(tester, (budget) async {
        sent = budget;
        return null;
      });
      await tester.enterText(nameField(), 'Thú cưng');
      await _tapSave(tester);

      expect(sent, isNotNull);
      expect(sent!.categoryId, isNull);
      expect(sent!.toJson()['categoryName'], 'Thú cưng');
      expect(find.textContaining('Chưa có giao dịch nào'), findsNothing);
      expect(find.text('Đã lưu ngân sách'), findsOneWidget);
    });
  });

  testWidgets(
    'an empty amount is refused with an AppDialog and nothing is sent',
    (tester) async {
      var sent = 0;
      await _openSheet(
        tester,
        onSubmit: (_) async {
          sent++;
          return null;
        },
      );

      await _tapSave(tester);

      expect(find.text('Số tiền không hợp lệ'), findsOneWidget);
      expect(sent, 0);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      expect(find.text('Lưu ngân sách'), findsOneWidget);
    },
  );

  testWidgets('an amount of zero is refused too', (tester) async {
    var sent = 0;
    await _openSheet(
      tester,
      onSubmit: (_) async {
        sent++;
        return null;
      },
    );

    await tester.enterText(find.byType(TextField), '0');
    await _tapSave(tester);

    expect(find.text('Số tiền không hợp lệ'), findsOneWidget);
    expect(sent, 0);
  });

  testWidgets(
    'sends the chosen amount, period, category and the computed dates, then closes with true',
    (tester) async {
      BudgetModel? sent;
      bool? closedWith;
      await _openSheet(
        tester,
        onSubmit: (budget) async {
          sent = budget;
          return null;
        },
        onClosed: (result) => closedWith = result,
      );

      await tester.enterText(find.byType(TextField), '1.500.000');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tuần'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Ăn uống'));
      await tester.pumpAndSettle();
      await _tapSave(tester);

      final week = BudgetPeriodType.rangeContaining(
        BudgetPeriodType.week,
        DateTime.now(),
      );
      expect(sent, isNotNull);
      expect(sent!.id, isNull);
      expect(sent!.categoryId, 10);
      expect(sent!.categoryName, 'Ăn uống');
      expect(sent!.amount, 1500000.0);
      expect(sent!.periodType, BudgetPeriodType.week);
      expect(sent!.startDate, BudgetModel.formatApiDate(week.start));
      expect(sent!.endDate, BudgetModel.formatApiDate(week.end));

      expect(find.text('Đã lưu ngân sách'), findsOneWidget);
      expect(
        closedWith,
        isNull,
        reason: 'the sheet stays until the success dialog is dismissed',
      );
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();
      expect(closedWith, isTrue);
      expect(find.text('Lưu ngân sách'), findsNothing);
    },
  );

  testWidgets('a budget for every category is sent without a category', (
    tester,
  ) async {
    BudgetModel? sent;
    await _openSheet(
      tester,
      onSubmit: (budget) async {
        sent = budget;
        return null;
      },
    );

    await tester.enterText(find.byType(TextField), '2000000');
    await _tapSave(tester);

    expect(sent!.categoryId, isNull);
    expect(sent!.categoryName, isNull);
    expect(sent!.periodType, BudgetPeriodType.month);
    expect(sent!.toJson()['categoryId'], isNull);
  });

  testWidgets(
    'a failure reported by the screen is shown in an AppDialog and the sheet stays open',
    (tester) async {
      bool? closedWith;
      await _openSheet(
        tester,
        onSubmit: (_) async =>
            'Ngân sách cho danh mục và kỳ hạn này đã tồn tại',
        onClosed: (result) => closedWith = result,
      );

      await tester.enterText(find.byType(TextField), '2000000');
      await _tapSave(tester);

      expect(find.text('Không lưu được ngân sách'), findsOneWidget);
      expect(
        find.text('Ngân sách cho danh mục và kỳ hạn này đã tồn tại'),
        findsOneWidget,
      );
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      expect(find.text('Lưu ngân sách'), findsOneWidget);
      expect(closedWith, isNull);
    },
  );

  testWidgets(
    'a category list that fails to load is reported, and every category stays available',
    (tester) async {
      await _openSheet(
        tester,
        loadCategories: () async => throw Exception('no network'),
        onSubmit: (_) async => null,
      );

      expect(find.text('Không tải được danh mục'), findsOneWidget);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      expect(
        _chip(tester, BudgetModel.allCategoriesLabel(_vi)).selected,
        isTrue,
      );
    },
  );

  group('editing', () {
    const august = BudgetModel(
      id: 42,
      categoryId: 11,
      categoryName: 'Di chuyển',
      amount: 2000000,
      periodType: BudgetPeriodType.month,
      startDate: '2026-08-01',
      endDate: '2026-08-31',
    );

    testWidgets(
      'starts from the existing budget and keeps its id, category and dates',
      (tester) async {
        BudgetModel? sent;
        await _openSheet(
          tester,
          budget: august,
          onSubmit: (budget) async {
            sent = budget;
            return null;
          },
        );

        expect(find.text('Sửa ngân sách'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '2.000.000',
          reason: 'the amount is grouped like every money field',
        );
        expect(_chip(tester, 'Di chuyển').selected, isTrue);
        expect(
          find.text('Kỳ áp dụng: 01/08/2026 – 31/08/2026'),
          findsOneWidget,
        );

        await tester.enterText(find.byType(TextField), '2500000');
        await _tapSave(tester);

        expect(sent!.id, 42);
        expect(sent!.categoryId, 11);
        expect(sent!.amount, 2500000.0);
        expect(sent!.startDate, '2026-08-01');
        expect(sent!.endDate, '2026-08-31');
      },
    );

    testWidgets(
      'changing the period type moves the budget to the current week',
      (tester) async {
        BudgetModel? sent;
        await _openSheet(
          tester,
          budget: august,
          onSubmit: (budget) async {
            sent = budget;
            return null;
          },
        );

        await tester.tap(find.widgetWithText(ChoiceChip, 'Tuần'));
        await tester.pumpAndSettle();
        expect(
          find.text('Tuần này: ${_range(BudgetPeriodType.week)}'),
          findsOneWidget,
        );
        await _tapSave(tester);

        final week = BudgetPeriodType.rangeContaining(
          BudgetPeriodType.week,
          DateTime.now(),
        );
        expect(sent!.id, 42);
        expect(sent!.periodType, BudgetPeriodType.week);
        expect(sent!.startDate, BudgetModel.formatApiDate(week.start));
      },
    );

    testWidgets(
      'keeps the category selectable even when the loaded list does not contain it',
      (tester) async {
        await _openSheet(
          tester,
          budget: august,
          loadCategories: () async => const [(id: 10, name: 'Ăn uống')],
          onSubmit: (_) async => null,
        );

        expect(_chip(tester, 'Di chuyển').selected, isTrue);
      },
    );
  });

  testWidgets(
    'closing the sheet while the request is still running does not touch the disposed sheet',
    (tester) async {
      final pending = Completer<String?>();
      await _openSheet(tester, onSubmit: (_) => pending.future);

      await tester.enterText(find.byType(TextField), '2000000');
      await tester.ensureVisible(find.text('Lưu ngân sách'));
      await tester.tap(find.text('Lưu ngân sách'));
      await tester.pump();
      expect(find.text('Đang lưu...'), findsOneWidget);

      Navigator.of(tester.element(find.byType(BudgetFormSheet))).pop();
      await tester.pumpAndSettle();
      pending.complete(null);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Đã lưu ngân sách'), findsNothing);
    },
  );

  for (final loadFails in [false, true]) {
    testWidgets(
      'closing the sheet while the categories are still loading does not touch the disposed sheet '
      '(the load ${loadFails ? 'fails' : 'succeeds'})',
      (tester) async {
        final pending = Completer<List<BudgetCategory>>();
        await _openSheet(
          tester,
          settle: false,
          loadCategories: () => pending.future,
          onSubmit: (_) async => null,
        );

        Navigator.of(tester.element(find.byType(BudgetFormSheet))).pop();
        await tester.pump(const Duration(milliseconds: 400));
        if (loadFails) {
          pending.completeError(Exception('no network'));
        } else {
          pending.complete(_categories);
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  }
}
