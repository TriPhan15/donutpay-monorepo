import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/budget_progress.dart';
import 'package:finance_ai_app/models/ledger_stats.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

/// The Excel report of one month: the file's bytes and the texts that go with it.
class LedgerExcelFile {
  final List<int> bytes;
  final String fileName;

  /// The name of the sheet, which is also the subject of the share.
  final String title;
  final String shareText;

  const LedgerExcelFile({
    required this.bytes,
    required this.fileName,
    required this.title,
    required this.shareText,
  });
}

/// Builds the Excel report of the statistics tab: the transactions of one month, their totals and the budgets.
abstract final class LedgerExcelBuilder {
  static const String _dateFormat = 'dd/MM/yyyy';

  /// The month in the sheet name and the file name: digits and '-', whatever the language ("10-2026").
  static const String _monthFormat = 'MM-yyyy';

  /// Excel refuses a longer sheet name and reports the file as damaged.
  static const int maxSheetNameLength = 31;
  static const String _fileDateFormat = 'ddMMyyyy';
  static const String _fileExtension = '.xlsx';

  /// The report of the month of [month], drawn from [transactions] and [budgets] and named after [now]. Null when the
  /// workbook cannot be encoded.
  static LedgerExcelFile? build({
    required AppLocalizations loc,
    required DateTime month,
    required Iterable<TransactionModel> transactions,
    required Iterable<BudgetModel> budgets,
    required DateTime now,
  }) {
    final monthName = DateFormat(_monthFormat).format(month);
    final title = loc.ledgerExcelSheet(monthName);
    final excel = Excel.createExcel();
    final sheet = excel[_sheetName(title)];

    final inMonth = transactions
        .where(
          (tx) => tx.date.year == month.year && tx.date.month == month.month,
        )
        .toList();
    _appendTransactions(sheet, loc, inMonth);
    _appendTotals(sheet, loc, LedgerStats.totals(inMonth));
    _appendBudgets(sheet, loc, monthName, month, budgets, transactions);

    final bytes = excel.encode();
    if (bytes == null) return null;
    final date = DateFormat(_fileDateFormat).format(now);
    return LedgerExcelFile(
      bytes: bytes,
      fileName: '${loc.ledgerExcelFileName(monthName, date)}$_fileExtension',
      title: title,
      shareText: loc.ledgerExcelShareText(monthName),
    );
  }

  static String _sheetName(String title) => title.length <= maxSheetNameLength
      ? title
      : title.substring(0, maxSheetNameLength);

  static void _appendTransactions(
    Sheet sheet,
    AppLocalizations loc,
    List<TransactionModel> transactions,
  ) {
    sheet.appendRow([
      TextCellValue(loc.ledgerExcelDate),
      TextCellValue(loc.transactionCategoryLabel),
      TextCellValue(loc.transactionExpenseMoney),
      TextCellValue(loc.transactionIncomeMoney),
    ]);
    for (final tx in transactions) {
      final amount = DoubleCellValue(tx.amount);
      final none = TextCellValue('');
      sheet.appendRow([
        TextCellValue(DateFormat(_dateFormat).format(tx.date)),
        TextCellValue(TransactionCategories.displayName(loc, tx.category)),
        tx.isExpense ? amount : none,
        tx.isExpense ? none : amount,
      ]);
    }
  }

  static void _appendTotals(
    Sheet sheet,
    AppLocalizations loc,
    DayTotals totals,
  ) {
    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue(loc.ledgerExcelTotal),
      TextCellValue(''),
      DoubleCellValue(totals.expense),
      DoubleCellValue(totals.income),
    ]);
    sheet.appendRow([
      TextCellValue(loc.ledgerBalance),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totals.income - totals.expense),
    ]);
  }

  static void _appendBudgets(
    Sheet sheet,
    AppLocalizations loc,
    String monthName,
    DateTime month,
    Iterable<BudgetModel> budgets,
    Iterable<TransactionModel> transactions,
  ) {
    sheet.appendRow([]);
    sheet.appendRow([TextCellValue(loc.ledgerExcelBudgetHeader(monthName))]);
    sheet.appendRow([
      TextCellValue(loc.transactionCategoryLabel),
      TextCellValue(loc.ledgerExcelLimit),
      TextCellValue(loc.ledgerExcelSpent),
      TextCellValue(loc.ledgerExcelRemaining),
    ]);
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    for (final progress in BudgetProgress.overlapping(
      monthStart,
      monthEnd,
      budgets,
      transactions,
    )) {
      sheet.appendRow([
        TextCellValue(progress.budget.categoryLabel(loc)),
        DoubleCellValue(progress.limit),
        DoubleCellValue(progress.spent),
        DoubleCellValue(progress.remaining),
      ]);
    }
  }
}
