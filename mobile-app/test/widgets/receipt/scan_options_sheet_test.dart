import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/widgets/receipt/scan_options_sheet.dart';

import '../../helpers/app_settings_scope.dart';

void main() {
  ScanOption? picked;
  var closed = false;

  Future<void> openSheet(WidgetTester tester) async {
    picked = null;
    closed = false;
    await tester.pumpWidget(
      withAppSettings(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                picked = await showScanOptionsSheet(context);
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('four options, each with a line that explains it', (
    tester,
  ) async {
    await openSheet(tester);

    for (final text in [
      'Quét hóa đơn bằng AI',
      'Chọn cách đưa hóa đơn vào',
      'Quét bằng camera',
      'Một hóa đơn, kiểm tra và lưu ngay',
      'Chọn từ thư viện',
      'Một ảnh có sẵn trong máy',
      'Quét nhiều',
      'Chụp liên tục, AI đọc dần ở nền',
      'Chọn nhiều ảnh',
      'Nhiều ảnh cùng lúc, xác nhận sau',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('a tapped option closes the sheet and is returned', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Quét nhiều'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(picked, ScanOption.cameraMany);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('each option returns its own value', (tester) async {
    final expected = {
      'Quét bằng camera': ScanOption.cameraOne,
      'Chọn từ thư viện': ScanOption.galleryOne,
      'Chọn nhiều ảnh': ScanOption.galleryMany,
    };
    for (final entry in expected.entries) {
      await openSheet(tester);
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(picked, entry.value, reason: entry.key);
    }
  });

  testWidgets('a tap outside closes it without a choice', (tester) async {
    await openSheet(tester);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(picked, isNull);
  });
}
