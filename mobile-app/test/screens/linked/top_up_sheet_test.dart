import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/models/payment_order.dart';
import 'package:finance_ai_app/models/top_up_amount.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/screens/linked/top_up_sheet.dart';
import 'package:finance_ai_app/screens/linked/widgets/top_up_quick_amounts.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_settings_repository.dart';
import '../../helpers/theme_colors.dart';

void main() {
  tearDown(() => Intl.defaultLocale = null);

  /// Opens the sheet for ZaloPay from a button; [result] holds what it popped once it closes.
  Future<({ThemeData theme, List<double?> result})> open(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final result = <double?>[];
    late ThemeData theme;
    await tester.pumpWidget(
      withAppSettings(
        Scaffold(
          body: Builder(
            builder: (context) {
              theme = Theme.of(context);
              return TextButton(
                onPressed: () async => result.add(
                  await showTopUpSheet(context, PaymentWallet.of('ZALOPAY')),
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
        settings: FakeSettingsRepository(themeMode: mode),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (theme: theme, result: result);
  }

  Finder field() => find.descendant(
    of: find.byKey(TopUpSheet.amountKey),
    matching: find.byType(TextField),
  );

  FilledButton submit(WidgetTester tester) => tester.widget<FilledButton>(
    find.descendant(
      of: find.byType(FormSubmitBar),
      matching: find.byType(FilledButton),
    ),
  );

  testWidgets('shows the wallet card, four chips, the hint and the button', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Đồng bộ tiền'), findsOneWidget);
    expect(find.text('Từ ZaloPay'), findsOneWidget);
    expect(find.text('Vào ngân sách chi tiêu'), findsOneWidget);
    for (final amount in TopUpAmount.quickAmounts) {
      expect(find.byKey(TopUpQuickAmounts.chipKey(amount)), findsOneWidget);
    }
    expect(
      find.textContaining('Bạn sẽ được chuyển sang cổng ZaloPay'),
      findsOneWidget,
    );
    expect(find.text('Tiếp tục thanh toán'), findsOneWidget);
    expect(submit(tester).onPressed, isNull, reason: 'nothing typed yet');
  });

  testWidgets('a chip fills the field, is selected and is sent as is', (
    tester,
  ) async {
    final opened = await open(tester);
    final colors = opened.theme.colorScheme;

    await tester.tap(find.byKey(TopUpQuickAmounts.chipKey(200000)));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(field()).controller!.text, '200.000');
    expect(
      materialColor(tester, find.byKey(TopUpQuickAmounts.chipKey(200000))),
      colors.primaryContainer,
    );
    expect(
      materialColor(tester, find.byKey(TopUpQuickAmounts.chipKey(50000))),
      colors.surface,
    );

    await tester.tap(find.byKey(TopUpSheet.submitKey));
    await tester.pumpAndSettle();
    expect(opened.result, [200000]);
    expect(find.byType(TopUpSheet), findsNothing);
  });

  testWidgets('under 1.000 ₫ the hint turns red and the button stays off', (
    tester,
  ) async {
    final opened = await open(tester);
    final colors = opened.theme.colorScheme;

    await tester.enterText(field(), '999');
    await tester.pumpAndSettle();

    expect(submit(tester).onPressed, isNull);
    expect(paintedColor(tester, find.byKey(TopUpSheet.hintKey)), colors.error);

    await tester.enterText(field(), '1000');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(field()).controller!.text, '1.000');
    expect(submit(tester).onPressed, isNotNull);
    expect(
      paintedColor(tester, find.byKey(TopUpSheet.hintKey)),
      colors.onSurfaceVariant,
    );

    await tester.tap(find.byKey(TopUpSheet.submitKey));
    await tester.pumpAndSettle();
    expect(opened.result, [1000]);
  });

  testWidgets(
    'above 1.000.000.000 ₫ the sheet says so and the button stays off; the limit itself is accepted',
    (tester) async {
      final opened = await open(tester);
      final colors = opened.theme.colorScheme;

      expect(find.byKey(TopUpSheet.maxHintKey), findsNothing);

      await tester.enterText(field(), '1000000001');
      await tester.pumpAndSettle();

      expect(submit(tester).onPressed, isNull);
      expect(find.byKey(TopUpSheet.maxHintKey), findsOneWidget);
      expect(
        find.text('Tối đa 1.000.000.000 đ mỗi lần đồng bộ.'),
        findsOneWidget,
      );
      expect(
        paintedColor(tester, find.byKey(TopUpSheet.maxHintKey)),
        colors.error,
      );

      await tester.enterText(field(), '1000000000');
      await tester.pumpAndSettle();

      expect(submit(tester).onPressed, isNotNull);
      expect(find.byKey(TopUpSheet.maxHintKey), findsNothing);

      await tester.tap(find.byKey(TopUpSheet.submitKey));
      await tester.pumpAndSettle();
      expect(opened.result, [1000000000]);
    },
  );

  testWidgets('the button stays above the gesture bar', (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPadding);
    await open(tester);

    final button = tester.getRect(find.byType(FilledButton));
    expect(button.bottom, lessThanOrEqualTo(1000 - 34));
  });

  testWidgets('closing the sheet sends nothing', (tester) async {
    final opened = await open(tester);

    await tester.tap(find.byKey(TopUpSheet.closeKey));
    await tester.pumpAndSettle();

    expect(opened.result, [null]);
  });

  testWidgets('in dark mode the sheet takes the dark colours', (tester) async {
    final opened = await open(tester, mode: ThemeMode.dark);
    final colors = opened.theme.colorScheme;

    expect(colors.brightness, Brightness.dark);
    expect(
      paintedColor(tester, find.byKey(TopUpSheet.hintKey)),
      colors.onSurfaceVariant,
    );
    expect(paintedColor(tester, find.text('Từ ZaloPay')), colors.onSurface);
    expect(boxColor(tester, find.text('Từ ZaloPay')), colors.surfaceContainer);
  });
}
