import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/models/receipt_status.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_filter.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/screens/ledger/widgets/day_grouped_list.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_status_badge.dart';
import 'package:finance_ai_app/widgets/sync/sync_status_badge.dart';
import 'package:finance_ai_app/widgets/transactions/transaction_row.dart';

import '../../helpers/app_settings_scope.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  String dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  TransactionModel tx(
    String title,
    double amount,
    DateTime date, {
    bool isExpense = true,
    ReceiptStatus? receipt,
    SyncStatus sync = SyncStatus.synced,
  }) => TransactionModel(
    id: title.hashCode.toString(),
    title: title,
    amount: amount,
    date: date,
    category: isExpense ? 'Ăn uống' : 'Lương',
    isExpense: isExpense,
    receiptStatus: receipt,
    syncStatus: sync,
  );

  final rows = [
    tx('Highlands', 55000, today.add(const Duration(hours: 8))),
    tx('Grab', 42000, today.add(const Duration(hours: 7))),
    tx(
      'Lương',
      18500000,
      yesterday.add(const Duration(hours: 9)),
      isExpense: false,
    ),
  ];

  setUpAll(() => initializeDateFormatting('vi_VN'));

  Future<BuildContext> pump(
    WidgetTester tester,
    List<TransactionModel> txs, {
    TransactionSort sort = TransactionSort.newest,
    bool single = false,
    ValueChanged<TransactionModel>? onOpen,
  }) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: DayGroupedList(
              transactions: txs,
              sort: sort,
              onOpen: onOpen ?? (_) {},
              title: 'Giao dịch',
              singleDaySummary: single,
              empty: const Text('trống'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.element(find.byType(DayGroupedList));
  }

  testWidgets(
    'newest groups by day with "Hôm nay, 20/10" and the day totals on the right',
    (tester) async {
      final context = await pump(tester, rows);
      expect(find.text('Hôm nay, ${dm(today)}'), findsOneWidget);
      expect(find.text('Hôm qua, ${dm(yesterday)}'), findsOneWidget);
      expect(find.text('Chi 97.000 đ'), findsOneWidget);
      expect(find.text('Thu 0 đ'), findsNothing);
      final income = tester.widget<Text>(find.text('Thu 18.500.000 đ'));
      expect(income.style?.color, context.colors.successColor);
      final today0 = tester.getTopLeft(find.text('Hôm nay, ${dm(today)}')).dy;
      final highlands = tester.getTopLeft(find.text('Highlands')).dy;
      final yesterday0 = tester
          .getTopLeft(find.text('Hôm qua, ${dm(yesterday)}'))
          .dy;
      expect(today0 < highlands && highlands < yesterday0, isTrue);
      final row = tester.widget<TransactionRow>(
        find.byType(TransactionRow).first,
      );
      expect(row.timeOnly, isTrue);
    },
  );

  testWidgets('largest is one flat block with the date in the second line', (
    tester,
  ) async {
    await pump(tester, rows, sort: TransactionSort.largest);
    expect(find.text('Hôm nay, ${dm(today)}'), findsNothing);
    final row = tester.widget<TransactionRow>(
      find.byType(TransactionRow).first,
    );
    expect(row.timeOnly, isFalse);
  });

  testWidgets('the calendar mode shows one Tổng thu | Tổng chi row', (
    tester,
  ) async {
    await pump(tester, rows, single: true);
    expect(find.text('Tổng thu 18.500.000 đ'), findsOneWidget);
    expect(find.text('Tổng chi 97.000 đ'), findsOneWidget);
    expect(find.text('Hôm nay, ${dm(today)}'), findsNothing);
  });

  testWidgets(
    'rows share one surface card split by outlineVariant dividers and keep receipt and sync badges',
    (tester) async {
      final context = await pump(tester, [
        tx('A', 1000, today, receipt: ReceiptStatus.success),
        tx('B', 2000, today, sync: SyncStatus.error),
      ], single: true);
      final colors = Theme.of(context).colorScheme;
      final dividers = tester
          .widgetList<Divider>(find.byType(Divider))
          .toList();
      expect(dividers, isNotEmpty);
      expect(dividers.every((d) => d.color == colors.outlineVariant), isTrue);
      expect(find.byType(ReceiptStatusBadge), findsOneWidget);
      expect(find.byType(SyncStatusBadge), findsOneWidget);
    },
  );

  testWidgets('tapping a row opens it, even one not sent yet', (tester) async {
    TransactionModel? opened;
    final unsent = TransactionModel(
      title: 'Chưa gửi',
      amount: 1000,
      date: today,
      category: 'Ăn uống',
      isExpense: true,
      syncStatus: SyncStatus.error,
    );
    await pump(tester, [unsent], onOpen: (t) => opened = t);
    await tester.tap(find.text('Chưa gửi'));
    expect(opened, same(unsent));
  });

  testWidgets('an empty list shows the empty widget in the card', (
    tester,
  ) async {
    await pump(tester, const []);
    expect(find.text('trống'), findsOneWidget);
  });
}
