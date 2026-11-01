import 'dart:async';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ledger/ledger_page.dart';
import 'package:finance_ai_app/screens/ledger/widgets/stats_header_band.dart';
import 'package:finance_ai_app/services/budget_alert_tracker.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/budget/budget_alert_presenter.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';

const String _mine = '/api/transactions/mine';
const int exportPolls = 100;
const Duration exportPollStep = Duration(milliseconds: 50);
const String _shareChannel = 'dev.fluttercommunity.plus/share';

/// How intl names a month in Vietnamese ("MMMM"): "tháng 11".
String _viMonth(DateTime d) => 'tháng ${d.month}';

Map<String, Object?> _serverRow(
  int id,
  String title,
  double amount,
  DateTime date,
  String category, {
  bool isExpense = true,
}) => {
  'id': id,
  'title': title,
  'amount': amount,
  'date': date.toIso8601String(),
  'category': category,
  'isExpense': isExpense,
};

/// One cell as the user reads it: numbers as double, an empty cell as ''.
Object _read(Data? cell) {
  final value = cell?.value;
  return switch (value) {
    null => '',
    DoubleCellValue(:final value) => value,
    IntCellValue(:final value) => value.toDouble(),
    _ => value.toString(),
  };
}

/// What the export shares: the workbook, the name of its file and the texts sent with it.
class _Shared {
  _Shared(this.fileName, this.subject, this.text, this.excel);

  final String fileName;
  final String? subject;
  final String? text;
  final Excel excel;

  Sheet get sheet => excel.tables.values.firstWhere((s) => s.rows.isNotEmpty);

  /// The rows as they read: the file leaves out empty rows and the empty cells at the end of a row.
  List<List<Object>> get rows => [
    for (final row in sheet.rows)
      if (row.any((cell) => _read(cell) != ''))
        [for (final cell in row) _read(cell)],
  ].map(_withoutTrailingEmpty).toList();

  static List<Object> _withoutTrailingEmpty(List<Object> row) {
    final end = row.lastIndexWhere((cell) => cell != '');
    return row.sublist(0, end + 1);
  }
}

void main() {
  final backend = FakeBackend();
  final now = DateTime.now();
  final firstOfMonth = DateTime(now.year, now.month, 1, 9);
  final lastMonth = DateTime(now.year, now.month - 1, 15, 9);
  final loc = lookupAppLocalizations(const Locale('vi'));

  setUpAll(() async {
    await initializeDateFormatting();
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});
    BudgetAlertTracker.instance.resetMemory();
    BudgetAlertPresenter.resetQueue();
    TransactionCategories.expenseSelectable.clear();
    TransactionCategories.incomeSelectable.clear();

    AppRepository.instance.localStore = FakeLocalStore();
    backend.reset();
    backend.on(
      'GET',
      _mine,
      (_) => okResponse([
        _serverRow(1, 'Ăn trưa', 45000, firstOfMonth, 'Ăn uống'),
        _serverRow(
          2,
          'Lương',
          1000000,
          firstOfMonth,
          'Thu nhập',
          isExpense: false,
        ),
        _serverRow(
          3,
          'Góp quỹ',
          200000,
          firstOfMonth,
          TransactionCategories.savings,
        ),
        _serverRow(4, 'Tháng trước', 99000, lastMonth, 'Ăn uống'),
      ]),
    );
    backend.on(
      'GET',
      '/api/budgets',
      (_) => okResponse([
        {
          'id': 1,
          'categoryName': 'Ăn uống',
          'amount': 500000,
          'periodType': 'MONTH',
          'startDate': _isoDate(DateTime(now.year, now.month, 1)),
          'endDate': _isoDate(DateTime(now.year, now.month + 1, 0)),
        },
      ]),
    );
    backend.on(
      'GET',
      '/api/categories',
      (_) => okResponse([
        {'id': 10, 'name': 'Ăn uống', 'type': 'EXPENSE'},
        {'id': 6, 'name': 'Thu nhập', 'type': 'INCOME'},
      ]),
    );
  });

  /// Opens the ledger, taps the export button and returns what reached the share sheet (null when nothing did).
  Future<_Shared?> export(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final shared = Completer<Map<Object?, Object?>>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(_shareChannel),
      (call) async {
        shared.complete(call.arguments as Map<Object?, Object?>);
        return 'dev.fluttercommunity.plus/share/unavailable';
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel(_shareChannel),
        null,
      ),
    );

    await tester.pumpWidget(
      withAmountVisibility(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('vi'),
          home: LedgerPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(StatsHeaderBand.exportKey));

    // The file is written with real IO: let it finish, then let the page go on with the fake clock.
    for (var i = 0; i < exportPolls && !shared.isCompleted; i++) {
      await tester.runAsync(() => Future<void>.delayed(exportPollStep));
      await tester.pump();
    }
    if (!shared.isCompleted) return null;
    final args = await shared.future;
    return tester.runAsync(() async {
      final path = (args['paths']! as List).single as String;
      final bytes = await File(path).readAsBytes();
      return _Shared(
        path.split(RegExp(r'[\\/]')).last,
        args['subject'] as String?,
        args['text'] as String?,
        Excel.decodeBytes(bytes),
      );
    });
  }

  String today() =>
      '${now.day.toString().padLeft(2, '0')}'
      '${now.month.toString().padLeft(2, '0')}${now.year}';

  testWidgets(
    'the export holds the month, its totals, the balance and the budgets',
    (tester) async {
      final shared = (await export(tester))!;
      final dateText = '01/${now.month.toString().padLeft(2, '0')}/${now.year}';

      expect(shared.rows, [
        [
          loc.ledgerExcelDate,
          loc.transactionCategoryLabel,
          loc.transactionExpenseMoney,
          loc.transactionIncomeMoney,
        ],
        [dateText, 'Ăn uống', 45000.0],
        [dateText, 'Thu nhập', '', 1000000.0],
        [dateText, loc.categorySavings, 200000.0],
        [loc.ledgerExcelTotal, '', 45000.0, 1000000.0],
        [loc.ledgerBalance, '', '', 955000.0],
        [loc.ledgerExcelBudgetHeader('${_viMonth(now)} ${now.year}')],
        [
          loc.transactionCategoryLabel,
          loc.ledgerExcelLimit,
          loc.ledgerExcelSpent,
          loc.ledgerExcelRemaining,
        ],
        ['Ăn uống', 500000.0, 45000.0, 455000.0],
      ]);
    },
  );

  testWidgets('the export is named after the month and shared with its texts', (
    tester,
  ) async {
    final shared = (await export(tester))!;
    final monthName = '${_viMonth(now)} ${now.year}';

    // The empty default sheet of a new workbook is still in the file, in front of the month.
    expect(shared.excel.tables.keys.toList(), [
      'Sheet1',
      loc.ledgerExcelSheet(monthName),
    ]);
    expect(shared.sheet.sheetName, loc.ledgerExcelSheet(monthName));
    expect(
      shared.fileName,
      '${loc.ledgerExcelFileName(monthName, today())}.xlsx',
    );
    expect(shared.subject, loc.ledgerExcelSheet(monthName));
    expect(shared.text, loc.ledgerExcelShareText(monthName));
  });
}

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
