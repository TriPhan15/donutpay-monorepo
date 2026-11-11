import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/utils/app_date_format.dart';
import 'package:finance_ai_app/core/utils/file_name_part.dart';
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
  /// The month in the sheet name and the file name: digits and '-', whatever the language ("10-2026").
  static const String _monthFormat = 'MM-yyyy';

  /// Excel refuses a longer sheet name and reports the file as damaged.
  static const int maxSheetNameLength = 31;
  static const String _fileExtension = '.xlsx';
  static const String _nameSeparator = '_';

  /// Amounts are whole VND: thousands separators, no decimals.
  static final CellStyle amountStyle = CellStyle(
    numberFormat: NumFormat.standard_3,
  );

  /// Column widths in characters: date, category / label, and the amount columns (wide enough for "-9,999,999,999").
  static const double dateColumnWidth = 12;
  static const double categoryColumnWidth = 26;
  static const double amountColumnWidth = 18;
  static const List<double> columnWidths = [
    dateColumnWidth,
    categoryColumnWidth,
    amountColumnWidth,
    amountColumnWidth,
    amountColumnWidth,
  ];

  /// The report of the month of [month], drawn from [transactions] and [budgets], named after [userName] when it is
  /// known. Null when the workbook cannot be encoded.
  static LedgerExcelFile? build({
    required AppLocalizations loc,
    required DateTime month,
    required Iterable<TransactionModel> transactions,
    required Iterable<BudgetModel> budgets,
    String? userName,
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

    for (var i = 0; i < columnWidths.length; i++) {
      sheet.setColumnWidth(i, columnWidths[i]);
    }

    final bytes = excel.encode();
    if (bytes == null) return null;
    final namePart = FileNamePart.fromName(userName);
    final nameInFile = namePart.isEmpty ? '' : '$_nameSeparator$namePart';
    return LedgerExcelFile(
      bytes: bytes,
      fileName:
          '${loc.ledgerExcelFileName(nameInFile, monthName)}$_fileExtension',
      title: title,
      shareText: loc.ledgerExcelShareText(monthName),
    );
  }

  /// Appends [row] and gives its amount cells the thousands format, so a wide figure is not shown as "####".
  static void _appendStyledRow(Sheet sheet, List<CellValue> row) {
    sheet.appendRow(row);
    final rowIndex = sheet.maxRows - 1;
    for (var column = 0; column < row.length; column++) {
      if (row[column] is! DoubleCellValue) continue;
      sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: column,
                  rowIndex: rowIndex,
                ),
              )
              .cellStyle =
          amountStyle;
    }
  }

  /// A real empty row: `appendRow([])` does nothing in excel 4.x, so the row holds one empty text cell.
  static void _appendBlankRow(Sheet sheet) =>
      sheet.appendRow([TextCellValue('')]);

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
      TextCellValue(loc.ledgerExcelNotCounted),
    ]);
    for (final tx in transactions) {
      final amount = DoubleCellValue(tx.amount);
      final none = TextCellValue('');
      // Same rule as LedgerStats.totals, so each column adds up to its total.
      final counted = tx.countsAsSpending || tx.countsAsIncome;
      _appendStyledRow(sheet, [
        TextCellValue(AppDateFormat.date.format(tx.date)),
        TextCellValue(
          counted
              ? TransactionCategories.displayName(loc, tx.category)
              : tx.source.label(loc) ??
                    TransactionCategories.displayName(loc, tx.category),
        ),
        counted && tx.isExpense ? amount : none,
        counted && !tx.isExpense ? amount : none,
        counted ? none : amount,
      ]);
    }
  }

  static void _appendTotals(
    Sheet sheet,
    AppLocalizations loc,
    DayTotals totals,
  ) {
    _appendBlankRow(sheet);
    _appendStyledRow(sheet, [
      TextCellValue(loc.ledgerExcelTotal),
      TextCellValue(''),
      DoubleCellValue(totals.expense),
      DoubleCellValue(totals.income),
    ]);
    _appendStyledRow(sheet, [
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
    _appendBlankRow(sheet);
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
      _appendStyledRow(sheet, [
        TextCellValue(progress.budget.categoryLabel(loc)),
        DoubleCellValue(progress.limit),
        DoubleCellValue(progress.spent),
        DoubleCellValue(progress.remaining),
      ]);
    }
  }
}
