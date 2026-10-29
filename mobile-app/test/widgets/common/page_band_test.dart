import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/widgets/common/page_band.dart';

import '../../helpers/app_settings_scope.dart';

void main() {
  Future<void> pumpPushed(WidgetTester tester, Widget band) async {
    await tester.pumpWidget(
      withAppSettings(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => Scaffold(body: band)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the title with a back button by default', (tester) async {
    await pumpPushed(tester, const PageBand(title: 'Chi tiết giao dịch'));

    expect(find.text('Chi tiết giao dịch'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('the close action shows a cross', (tester) async {
    await pumpPushed(
      tester,
      const PageBand(title: 'Thêm giao dịch', action: PageBandAction.close),
    );

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('without onAction the button closes the page', (tester) async {
    await pumpPushed(tester, const PageBand(title: 'Thêm giao dịch'));

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Thêm giao dịch'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('onAction replaces closing the page', (tester) async {
    var taps = 0;
    const buttonKey = ValueKey('band-button');
    await pumpPushed(
      tester,
      PageBand(
        title: 'Sửa giao dịch',
        buttonKey: buttonKey,
        onAction: () => taps++,
      ),
    );

    await tester.tap(find.byKey(buttonKey));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(find.text('Sửa giao dịch'), findsOneWidget);
  });
}
