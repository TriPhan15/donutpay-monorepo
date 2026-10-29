import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/screens/receipt_scanner/widgets/needs_check_field.dart';
import 'package:finance_ai_app/screens/receipt_scanner/widgets/receipt_photo_header.dart';
import 'package:finance_ai_app/screens/receipt_scanner/widgets/receipt_step_band.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_settings_repository.dart';

final Finder _dashedOutline = find.byWidgetPredicate(
  (widget) =>
      widget is CustomPaint && widget.foregroundPainter is DashedOutlinePainter,
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    AppLanguage language = AppLanguage.vietnamese,
    Size? size,
    double textScale = 1,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size ?? const Size(800, 600),
          textScaler: TextScaler.linear(textScale),
        ),
        child: withAppSettings(
          Scaffold(body: child),
          settings: FakeSettingsRepository(language: language),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('ReceiptStepBand', () {
    testWidgets('shows the three steps and toggles the comparison', (
      tester,
    ) async {
      var toggles = 0;
      await pump(
        tester,
        ReceiptStepBand(compareOn: false, onToggleCompare: () => toggles++),
      );

      expect(find.text('Xác nhận hóa đơn'), findsOneWidget);
      expect(find.text('Ảnh'), findsOneWidget);
      expect(find.text('Kiểm tra'), findsOneWidget);
      expect(find.text('Lưu'), findsOneWidget);

      await tester.tap(find.byKey(ReceiptStepBand.compareKey));
      expect(toggles, 1);
    });

    testWidgets('fits 320 px in English at text scale 1.3', (tester) async {
      await pump(
        tester,
        ReceiptStepBand(compareOn: true, onToggleCompare: () {}),
        language: AppLanguage.english,
        size: const Size(320, 640),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('NeedsCheckField', () {
    testWidgets('an unsure field is outlined in dashes with its hint', (
      tester,
    ) async {
      await pump(
        tester,
        const NeedsCheckField(
          label: 'Tổng tiền',
          needsCheck: true,
          hint: 'Chưa chắc tổng tiền, hãy so với ảnh.',
          child: SizedBox(height: 48),
        ),
      );

      expect(find.text('Cần kiểm tra'), findsOneWidget);
      expect(find.text('Chưa chắc tổng tiền, hãy so với ảnh.'), findsOneWidget);
      expect(_dashedOutline, findsOneWidget);
    });

    testWidgets('a sure field has no mark, no hint and no dashes', (
      tester,
    ) async {
      await pump(
        tester,
        const NeedsCheckField(
          label: 'Tổng tiền',
          hint: 'Chưa chắc tổng tiền, hãy so với ảnh.',
          child: SizedBox(height: 48),
        ),
      );

      expect(find.text('Cần kiểm tra'), findsNothing);
      expect(find.text('Chưa chắc tổng tiền, hãy so với ảnh.'), findsNothing);
      expect(_dashedOutline, findsNothing);
    });
  });

  group('ReceiptPhotoHeader', () {
    testWidgets('a photo that cannot be read shows an icon instead', (
      tester,
    ) async {
      await pump(
        tester,
        ReceiptPhotoHeader(imagePath: '/no/such/photo.jpg', onOpen: () {}),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('a tap opens the photo', (tester) async {
      var opens = 0;
      await pump(
        tester,
        ReceiptPhotoHeader(
          imagePath: '/no/such/photo.jpg',
          onOpen: () => opens++,
        ),
      );

      await tester.tap(find.text('Phóng to'));
      expect(opens, 1);
    });
  });

  group('FormSubmitBar with a secondary button', () {
    testWidgets('each button reports its own tap', (tester) async {
      var main = 0;
      var secondary = 0;
      await pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: FormSubmitBar(
            label: 'Lưu',
            onPressed: () => main++,
            secondaryLabel: 'Lưu & quét tiếp',
            onSecondary: () => secondary++,
          ),
        ),
      );

      await tester.tap(find.text('Lưu & quét tiếp'));
      await tester.tap(find.text('Lưu'));
      expect(secondary, 1);
      expect(main, 1);
    });

    testWidgets('without onPressed both are faded and inert', (tester) async {
      var secondary = 0;
      await pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: FormSubmitBar(
            label: 'Lưu',
            secondaryLabel: 'Lưu & quét tiếp',
            onSecondary: () => secondary++,
          ),
        ),
      );

      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('Lưu & quét tiếp'),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, FormSubmitBar.disabledOpacity);
      await tester.tap(find.text('Lưu & quét tiếp'), warnIfMissed: false);
      expect(secondary, 0);
    });

    testWidgets('fits 320 px in English at text scale 1.3', (tester) async {
      await pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: FormSubmitBar(
            label: 'Save',
            onPressed: () {},
            secondaryLabel: 'Save & scan next',
            onSecondary: () {},
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
