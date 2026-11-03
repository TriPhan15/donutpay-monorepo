import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/utils/ledger_excel_builder.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/models/transaction_source.dart';

TransactionModel _tx(
  double amount,
  DateTime date, {
  bool isExpense = true,
  String category = 'Ăn uống',
  TransactionSource source = TransactionSource.normal,
}) => TransactionModel(
  title: 'x',
  amount: amount,
  date: date,
  category: category,
  isExpense: isExpense,
  source: source,
);

BudgetModel _budget(double amount, {String? category}) => BudgetModel(
  categoryName: category,
  amount: amount,
  periodType: 'MONTH',
  startDate: '2026-10-01',
  endDate: '2026-10-31',
);

/// The first sheet that holds anything: the empty default sheet of a new workbook is left out.
Sheet _sheet(LedgerExcelFile file) => Excel.decodeBytes(
  file.bytes,
).tables.values.firstWhere((s) => s.rows.isNotEmpty);

/// A cell as the user reads it; an empty cell is ''.
Object _cell(Data? data) => switch (data?.value) {
  null => '',
  DoubleCellValue(:final value) => value,
  IntCellValue(:final value) => value.toDouble(),
  final other => other.toString(),
};

/// The rows with a value in them, without the empty cells at the end of each.
List<List<Object>> _rows(LedgerExcelFile file) => [
  for (final row in _sheet(file).rows)
    if (row.any((c) => _cell(c) != ''))
      [
        for (final c in row) _cell(c),
      ].reversed.skipWhile((c) => c == '').toList().reversed.toList(),
];

void main() {
  final month = DateTime(2026, 10, 14);
  final now = DateTime(2026, 11, 1, 8);
  final loc = lookupAppLocalizations(const Locale('vi'));

  setUpAll(initializeDateFormatting);

  LedgerExcelFile build({
    List<TransactionModel> transactions = const [],
    List<BudgetModel> budgets = const [],
  }) => LedgerExcelBuilder.build(
    loc: loc,
    month: month,
    transactions: transactions,
    budgets: budgets,
    now: now,
  )!;

  test(
    'the totals leave out savings and the other months, the balance is income minus spending',
    () {
      final file = build(
        transactions: [
          _tx(45000, DateTime(2026, 10, 1, 9)),
          _tx(55000, DateTime(2026, 10, 20, 9), category: 'Cà phê'),
          _tx(
            1000000,
            DateTime(2026, 10, 5, 9),
            isExpense: false,
            category: 'Thu nhập',
          ),
          _tx(
            200000,
            DateTime(2026, 10, 6, 9),
            category: TransactionCategories.savings,
          ),
          _tx(99000, DateTime(2026, 9, 30, 9)),
          _tx(77000, DateTime(2026, 11, 1, 9), isExpense: false),
        ],
      );

      final rows = _rows(file);
      expect(rows[1], ['01/10/2026', 'Ăn uống', 45000.0]);
      expect(rows[3], ['05/10/2026', 'Thu nhập', '', 1000000.0]);
      expect(rows[4], ['06/10/2026', loc.categorySavings, 200000.0]);
      expect(rows.where((r) => r.first == loc.ledgerExcelTotal), [
        [loc.ledgerExcelTotal, '', 100000.0, 1000000.0],
      ]);
      expect(rows.where((r) => r.first == loc.ledgerBalance), [
        [loc.ledgerBalance, '', '', 900000.0],
      ]);
      // Header, four rows of the month, total and balance, the budget heading and its header: nothing of September or November.
      expect(rows, hasLength(1 + 4 + 2 + 1 + 1));
    },
  );

  test(
    'refunds and wallet transfers sit in the not-counted column, so the columns add up to the totals',
    () {
      final file = build(
        transactions: [
          _tx(100000, DateTime(2026, 10, 1, 9)),
          _tx(300000, DateTime(2026, 10, 2, 9), isExpense: false),
          _tx(
            50000,
            DateTime(2026, 10, 3, 9),
            isExpense: false,
            source: TransactionSource.goalRefund,
          ),
          _tx(
            20000,
            DateTime(2026, 10, 4, 9),
            source: TransactionSource.walletTransfer,
          ),
        ],
      );

      final rows = _rows(file);
      expect(rows[0], hasLength(5));
      expect(rows[0][4], loc.ledgerExcelNotCounted);
      final txRows = rows.sublist(1, 5);
      expect(rows[3], [
        '03/10/2026',
        loc.transactionSourceGoalRefund,
        '',
        '',
        50000.0,
      ]);
      expect(rows[4], [
        '04/10/2026',
        loc.transactionSourceWalletTransfer,
        '',
        '',
        20000.0,
      ]);
      double column(int i) => txRows.fold(
        0.0,
        (sum, r) => sum + (r.length > i && r[i] is double ? r[i] as double : 0),
      );
      final total = rows.firstWhere((r) => r.first == loc.ledgerExcelTotal);
      expect(total, [loc.ledgerExcelTotal, '', 100000.0, 300000.0]);
      expect(column(2), 100000.0);
      expect(column(3), 300000.0);
    },
  );

  test('a month without transactions has zero totals', () {
    final rows = _rows(build());
    expect(rows[1], [loc.ledgerExcelTotal, '', 0.0, 0.0]);
    expect(rows[2], [loc.ledgerBalance, '', '', 0.0]);
  });

  test('the budget rows hold the limit, what was spent and what is left', () {
    final file = build(
      transactions: [
        _tx(45000, DateTime(2026, 10, 1, 9)),
        _tx(30000, DateTime(2026, 10, 2, 9), category: 'Cà phê'),
      ],
      budgets: [
        _budget(500000, category: 'Ăn uống'),
        _budget(100000),
      ],
    );

    final rows = _rows(file);
    expect(rows[rows.length - 2], ['Ăn uống', 500000.0, 45000.0, 455000.0]);
    expect(rows.last, [loc.budgetAllCategories, 100000.0, 75000.0, 25000.0]);
  });

  test('a budget of another month gets no row', () {
    final other = BudgetModel(
      categoryName: 'Ăn uống',
      amount: 500000,
      periodType: 'MONTH',
      startDate: '2026-09-01',
      endDate: '2026-09-30',
    );
    final rows = _rows(build(budgets: [other]));
    expect(rows.last, [
      loc.transactionCategoryLabel,
      loc.ledgerExcelLimit,
      loc.ledgerExcelSpent,
      loc.ledgerExcelRemaining,
    ]);
  });

  test(
    'the texts of the share come from the month, the file is dated today',
    () {
      final file = build();
      expect(file.title, 'Chi tiêu tháng 10-2026');
      expect(file.shareText, 'Báo cáo chi tiêu tháng 10-2026');
      expect(file.fileName, 'chi_tieu_10-2026_01112026.xlsx');
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    group('in ${locale.languageCode}', () {
      final localized = lookupAppLocalizations(locale);

      for (var m = 1; m <= 12; m++) {
        test('month $m has a sheet name Excel accepts and a plain file name', () {
          final file = LedgerExcelBuilder.build(
            loc: localized,
            month: DateTime(2026, m, 15),
            transactions: const [],
            budgets: const [],
            now: DateTime(2026, 11, 1),
          )!;
          final sheetName = Excel.decodeBytes(file.bytes).tables.keys.last;
          final monthKey = '${m.toString().padLeft(2, '0')}-2026';

          expect(sheetName.length, lessThanOrEqualTo(31));
          expect(sheetName, contains(monthKey));
          // The word for "month" is already in the text of the sheet name: it must not come twice.
          expect(
            RegExp('tháng.*tháng', caseSensitive: false).hasMatch(sheetName),
            isFalse,
          );
          expect(RegExp(r'[\/*?:\[\]]').hasMatch(sheetName), isFalse);
          expect(file.fileName, matches(RegExp(r'^[a-z0-9_-]+\.xlsx$')));
          expect(file.fileName, contains('_${monthKey}_01112026'));
        });
      }
    });
  }
}
