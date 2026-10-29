import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/models/transaction_filter.dart';
import 'package:finance_ai_app/screens/ledger/widgets/transaction_filter_sheet.dart';
import 'package:finance_ai_app/widgets/common/pill_segmented.dart';

import '../../helpers/app_settings_scope.dart';

void main() {
  /// Opens the sheet from a button and returns a getter for what it closed with.
  Future<TransactionFilter? Function()> open(
    WidgetTester tester, {
    TransactionFilter initial = TransactionFilter.none,
    int Function(TransactionFilter)? countFor,
  }) async {
    TransactionFilter? result;
    var closed = false;
    await tester.pumpWidget(
      withAppSettings(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showTransactionFilterSheet(
                    context,
                    initial: initial,
                    countFor: countFor ?? (_) => 24,
                  );
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () {
      expect(closed, isTrue, reason: 'the sheet is still open');
      return result;
    };
  }

  testWidgets(
    'opens on the current filter: three toggles stacked, no group titles',
    (tester) async {
      await open(
        tester,
        initial: const TransactionFilter(
          type: TransactionTypeFilter.income,
          sort: TransactionSort.largest,
        ),
      );
      expect(find.text('Lọc'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      final toggles = find.byWidgetPredicate((w) => w is PillSegmented);
      expect(toggles, findsNWidgets(3));
      final tops = [
        for (var i = 0; i < 3; i++) tester.getTopLeft(toggles.at(i)).dy,
      ];
      expect(tops[0] < tops[1] && tops[1] < tops[2], isTrue);
      expect(
        tester
            .widget<PillSegmented<TransactionTypeFilter>>(toggles.at(0))
            .selected,
        TransactionTypeFilter.income,
      );
      expect(
        tester.widget<PillSegmented<TransactionSort>>(toggles.at(2)).selected,
        TransactionSort.largest,
      );
      expect(find.text('Loại giao dịch'), findsNothing);
    },
  );

  testWidgets('each change updates the count on the button', (tester) async {
    await open(
      tester,
      countFor: (f) => f.type == TransactionTypeFilter.expense ? 21 : 24,
    );
    expect(find.text('Xem 24 giao dịch'), findsOneWidget);
    await tester.tap(find.text('Chi'));
    await tester.pumpAndSettle();
    expect(find.text('Xem 21 giao dịch'), findsOneWidget);
  });

  testWidgets(
    'Đặt lại returns the draft to all / any / newest and keeps the sheet open',
    (tester) async {
      await open(
        tester,
        initial: const TransactionFilter(
          type: TransactionTypeFilter.expense,
          range: AmountRange.over500k,
          sort: TransactionSort.oldest,
        ),
        countFor: (f) => f.isActive ? 3 : 24,
      );
      expect(find.text('Xem 3 giao dịch'), findsOneWidget);
      await tester.tap(find.text('Đặt lại'));
      await tester.pumpAndSettle();
      expect(find.text('Xem 24 giao dịch'), findsOneWidget);
      final toggles = find.byWidgetPredicate((w) => w is PillSegmented);
      expect(
        tester.widget<PillSegmented<TransactionSort>>(toggles.at(2)).selected,
        TransactionSort.newest,
      );
    },
  );

  testWidgets('Xem n giao dịch closes with the draft', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('>500k'));
    await tester.tap(find.text('Lớn nhất'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem 24 giao dịch'));
    await tester.pumpAndSettle();
    expect(
      result(),
      const TransactionFilter(
        range: AmountRange.over500k,
        sort: TransactionSort.largest,
      ),
    );
  });

  testWidgets(
    'a draft matching nothing still shows "Xem 0 giao dịch" and can be applied',
    (tester) async {
      final result = await open(
        tester,
        countFor: (f) => f.type == TransactionTypeFilter.income ? 0 : 5,
      );
      await tester.tap(find.text('Thu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem 0 giao dịch'));
      await tester.pumpAndSettle();
      expect(result()?.type, TransactionTypeFilter.income);
    },
  );

  testWidgets('closing with ✕ returns null', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Thu'));
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(result(), isNull);
  });
}
