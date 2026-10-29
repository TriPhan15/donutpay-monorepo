import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/screens/budget/budget_form_sheet.dart';
import 'package:finance_ai_app/screens/ledger/widgets/category_shortcut_grid.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';

const List<BudgetCategory> _categories = [
  (id: 10, name: 'Ăn uống'),
  (id: 11, name: 'Di chuyển'),
  (id: 13, name: 'Mua sắm'),
  (id: 14, name: 'Giáo dục'),
  (id: 12, name: 'Khác'),
];

Future<List<BudgetCategory>> _loadCategories() async => _categories;

/// Opens the sheet from a button, like the budget screen does, and reports how the sheet was closed.
Future<void> _openSheet(
  WidgetTester tester, {
  required Future<String?> Function(BudgetModel budget) onSubmit,
  BudgetModel? budget,
  String initialPeriodType = BudgetPeriodType.month,
  Iterable<TransactionModel> history = const [],
  Future<List<BudgetCategory>> Function()? loadCategories,
  void Function(bool? result)? onClosed,
  bool settle = true,
}) async {
  // Tall enough for the whole sheet without scrolling.
  tester.view.physicalSize = const Size(800, 1800);
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
                    initialPeriodType: initialPeriodType,
                    history: history,
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

Future<void> _typeAmount(WidgetTester tester, String amount) async {
  await tester.enterText(find.byType(TextField).first, amount);
  await tester.pump();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.byKey(BudgetFormSheet.saveKey));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

bool _saveEnabled(WidgetTester tester) =>
    tester
        .widget<FormSubmitBar>(find.byKey(BudgetFormSheet.saveKey))
        .onPressed !=
    null;

/// The category tiles, in order.
Finder get _tiles => find.descendant(
  of: find.byType(CategoryShortcutGrid),
  matching: find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.selected != null,
  ),
);

/// The label of the selected tile, or null when none is selected.
String? _selectedTile(WidgetTester tester) {
  for (final element in _tiles.evaluate()) {
    final semantics = element.widget as Semantics;
    if (semantics.properties.selected == true) {
      final text =
          find
                  .descendant(
                    of: find.byWidget(semantics),
                    matching: find.byType(Text),
                  )
                  .evaluate()
                  .first
                  .widget
              as Text;
      return text.data;
    }
  }
  return null;
}

List<String?> _tileLabels(WidgetTester tester) => [
  for (final element in _tiles.evaluate())
    (find
                .descendant(
                  of: find.byWidget(element.widget),
                  matching: find.byType(Text),
                )
                .evaluate()
                .first
                .widget
            as Text)
        .data,
];

/// The "Khác" tile, the fourth one.
Finder get _moreTile => find.byKey(CategoryShortcutGrid.moreKey);

String _range(String periodType, [DateTime? day]) {
  final range = BudgetPeriodType.rangeContaining(
    periodType,
    day ?? DateTime.now(),
  );
  String show(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  return '${show(range.start)} – ${show(range.end)}';
}

TransactionModel _spent(String category) => TransactionModel(
  title: category,
  amount: 1000,
  date: DateTime.now(),
  category: category,
  isExpense: true,
);

void main() {
  testWidgets(
    'a new budget starts on the month and every category, with three tiles plus Khác',
    (tester) async {
      await _openSheet(tester, onSubmit: (_) async => null);

      expect(find.text('Thiết lập ngân sách'), findsOneWidget);
      expect(
        find.text('Tháng này: ${_range(BudgetPeriodType.month)}'),
        findsOneWidget,
      );
      expect(_tileLabels(tester), [
        'Ăn uống',
        'Di chuyển',
        'Mua sắm',
        'Tất cả',
      ]);
      expect(_selectedTile(tester), 'Tất cả');
    },
  );

  testWidgets('the tiles put the most used categories first', (tester) async {
    await _openSheet(
      tester,
      history: [_spent('Giáo dục'), _spent('Giáo dục'), _spent('Mua sắm')],
      onSubmit: (_) async => null,
    );

    expect(_tileLabels(tester).take(3), ['Giáo dục', 'Mua sắm', 'Ăn uống']);
  });

  testWidgets('Save stays faded until an amount above zero is typed', (
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

    expect(_saveEnabled(tester), isFalse);
    await _typeAmount(tester, '0');
    expect(_saveEnabled(tester), isFalse);
    await _tapSave(tester);
    expect(sent, isNull);

    await _typeAmount(tester, '2000000');
    expect(_saveEnabled(tester), isTrue);
    expect(find.text('2.000.000'), findsOneWidget, reason: 'grouped as typed');
  });

  testWidgets(
    'sends the amount, a tile category, the week and its dates, then closes with true',
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

      await _typeAmount(tester, '1500000');
      await _tap(tester, find.text('Tuần'));
      expect(
        find.text('Tuần này: ${_range(BudgetPeriodType.week)}'),
        findsOneWidget,
      );
      await _tap(tester, find.text('Di chuyển'));
      expect(_selectedTile(tester), 'Di chuyển');
      await _tapSave(tester);

      final week = BudgetPeriodType.rangeContaining(
        BudgetPeriodType.week,
        DateTime.now(),
      );
      expect(sent!.id, isNull);
      expect(sent!.categoryId, 11);
      expect(sent!.categoryName, 'Di chuyển');
      expect(sent!.amount, 1500000.0);
      expect(sent!.periodType, BudgetPeriodType.week);
      expect(sent!.startDate, BudgetModel.formatApiDate(week.start));
      expect(sent!.endDate, BudgetModel.formatApiDate(week.end));

      expect(find.text('Đã lưu ngân sách'), findsOneWidget);
      expect(closedWith, isNull, reason: 'stays until the dialog is dismissed');
      await _tap(tester, find.text('Xong'));
      expect(closedWith, isTrue);
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

    await _typeAmount(tester, '2000000');
    await _tapSave(tester);

    expect(sent!.categoryId, isNull);
    expect(sent!.categoryName, isNull);
    expect(sent!.periodType, BudgetPeriodType.month);
  });

  testWidgets(
    'the Khác sheet offers every category first and its pick takes the fourth tile',
    (tester) async {
      BudgetModel? sent;
      await _openSheet(
        tester,
        onSubmit: (budget) async {
          sent = budget;
          return null;
        },
      );

      await _tap(tester, _moreTile);
      final listed = [
        for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
          (tile.title as Text).data,
      ];
      expect(listed.first, 'Tất cả');
      await _tap(tester, find.widgetWithText(ListTile, 'Giáo dục'));

      expect(_selectedTile(tester), 'Giáo dục');
      await _typeAmount(tester, '900000');
      await _tapSave(tester);
      expect(sent!.categoryId, 14);
    },
  );

  testWidgets('a new budget can start on the year', (tester) async {
    await _openSheet(
      tester,
      initialPeriodType: BudgetPeriodType.year,
      onSubmit: (_) async => null,
    );

    expect(
      find.text('Năm nay: ${_range(BudgetPeriodType.year)}'),
      findsOneWidget,
    );
  });

  group('a category the user names under "Khác"', () {
    Future<void> pickOther(WidgetTester tester) async {
      await _tap(tester, _moreTile);
      await _tap(tester, find.widgetWithText(ListTile, 'Khác'));
    }

    testWidgets('an empty name is refused and nothing is sent', (tester) async {
      BudgetModel? sent;
      await _openSheet(
        tester,
        onSubmit: (budget) async {
          sent = budget;
          return null;
        },
      );

      expect(find.text('Tên danh mục'), findsNothing);
      await pickOther(tester);
      expect(find.text('Tên danh mục'), findsOneWidget);
      await _typeAmount(tester, '500000');
      await _tapSave(tester);

      expect(sent, isNull);
      expect(find.text('Nhập tên danh mục'), findsOneWidget);
    });

    testWidgets('a typed name is sent by name, without a category id', (
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

      await pickOther(tester);
      await _typeAmount(tester, '500000');
      await tester.enterText(find.byType(TextField).last, '  Cà phê ');
      await _tapSave(tester);

      expect(sent!.categoryId, isNull);
      expect(sent!.categoryName, 'Cà phê');
    });
  });

  testWidgets(
    'a failure reported by the screen is shown and the sheet stays open',
    (tester) async {
      bool? closedWith;
      await _openSheet(
        tester,
        onSubmit: (_) async =>
            'Ngân sách cho danh mục và kỳ hạn này đã tồn tại',
        onClosed: (result) => closedWith = result,
      );

      await _typeAmount(tester, '2000000');
      await _tapSave(tester);

      expect(find.text('Không lưu được ngân sách'), findsOneWidget);
      expect(
        find.text('Ngân sách cho danh mục và kỳ hạn này đã tồn tại'),
        findsOneWidget,
      );
      await _tap(tester, find.text('Đã hiểu'));
      expect(find.byType(BudgetFormSheet), findsOneWidget);
      expect(closedWith, isNull);
    },
  );

  testWidgets(
    'a category list that fails to load is reported, and every category stays chosen',
    (tester) async {
      await _openSheet(
        tester,
        loadCategories: () async => throw Exception('no network'),
        onSubmit: (_) async => null,
      );

      expect(find.text('Không tải được danh mục'), findsOneWidget);
      await _tap(tester, find.text('Đã hiểu'));
      expect(_selectedTile(tester), 'Tất cả');
    },
  );

  testWidgets('the close button pops without saving', (tester) async {
    bool? closedWith = true;
    await _openSheet(
      tester,
      onSubmit: (_) async => null,
      onClosed: (result) => closedWith = result,
    );

    await _tap(tester, find.byKey(BudgetFormSheet.closeKey));
    expect(find.byType(BudgetFormSheet), findsNothing);
    expect(closedWith, isNull);
  });

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

    testWidgets('keeps its id, category and dates', (tester) async {
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
      expect(find.text('2.000.000'), findsOneWidget);
      expect(find.text('Kỳ áp dụng: 01/08/2026 – 31/08/2026'), findsOneWidget);
      expect(_selectedTile(tester), 'Di chuyển');
      await _tapSave(tester);

      expect(sent!.id, 42);
      expect(sent!.categoryId, 11);
      expect(sent!.startDate, '2026-08-01');
      expect(sent!.endDate, '2026-08-31');
    });

    testWidgets('changing the period type moves it to the current week', (
      tester,
    ) async {
      BudgetModel? sent;
      await _openSheet(
        tester,
        budget: august,
        onSubmit: (budget) async {
          sent = budget;
          return null;
        },
      );

      await _tap(tester, find.text('Tuần'));
      expect(
        find.text('Tuần này: ${_range(BudgetPeriodType.week)}'),
        findsOneWidget,
      );
      await _tapSave(tester);

      final week = BudgetPeriodType.rangeContaining(
        BudgetPeriodType.week,
        DateTime.now(),
      );
      expect(sent!.periodType, BudgetPeriodType.week);
      expect(sent!.startDate, BudgetModel.formatApiDate(week.start));
    });

    testWidgets(
      'keeps its category chosen when the loaded list does not contain it',
      (tester) async {
        await _openSheet(
          tester,
          budget: const BudgetModel(
            id: 42,
            categoryId: 99,
            categoryName: 'Thú cưng',
            amount: 2000000,
            periodType: BudgetPeriodType.month,
            startDate: '2026-08-01',
            endDate: '2026-08-31',
          ),
          onSubmit: (_) async => null,
        );

        expect(_selectedTile(tester), 'Thú cưng');
      },
    );
  });

  testWidgets(
    'closing the sheet while the request is still running does not touch the disposed sheet',
    (tester) async {
      final pending = Completer<String?>();
      await _openSheet(tester, onSubmit: (_) => pending.future);

      await _typeAmount(tester, '2000000');
      await tester.tap(find.byKey(BudgetFormSheet.saveKey));
      await tester.pump();
      expect(
        tester.widget<FormSubmitBar>(find.byKey(BudgetFormSheet.saveKey)).busy,
        isTrue,
      );

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
