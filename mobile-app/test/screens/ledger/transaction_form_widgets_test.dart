import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/constants/input_limits.dart';
import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/screens/ledger/widgets/category_shortcut_grid.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/screens/ledger/widgets/transaction_form_fields.dart';
import 'package:finance_ai_app/screens/ledger/widgets/transaction_form_tabs.dart';
import 'package:finance_ai_app/widgets/transactions/category_picker_sheet.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_settings_repository.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    AppLanguage language = AppLanguage.vietnamese,
  }) async {
    await tester.pumpWidget(
      withAppSettings(
        Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
        settings: FakeSettingsRepository(language: language),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CategoryShortcutGrid', () {
    testWidgets('three shortcuts and the "Khác" tile, each reports its tap', (
      tester,
    ) async {
      String? picked;
      var more = 0;
      await pump(
        tester,
        CategoryShortcutGrid(
          shortcuts: const ['Ăn uống', 'Mua sắm', 'Di chuyển'],
          selected: 'Ăn uống',
          onSelected: (category) => picked = category,
          onMore: () => more++,
        ),
      );

      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.text('Mua sắm'), findsOneWidget);
      expect(find.text('Di chuyển'), findsOneWidget);
      expect(find.text('Khác'), findsOneWidget);

      await tester.tap(find.text('Mua sắm'));
      expect(picked, 'Mua sắm');
      await tester.tap(find.byKey(CategoryShortcutGrid.moreKey));
      expect(more, 1);
    });

    testWidgets('a selection outside the shortcuts takes the fourth tile', (
      tester,
    ) async {
      var more = 0;
      await pump(
        tester,
        CategoryShortcutGrid(
          shortcuts: const ['Ăn uống', 'Mua sắm', 'Di chuyển'],
          selected: 'Sức khỏe',
          onSelected: (_) {},
          onMore: () => more++,
        ),
      );

      expect(find.text('Khác'), findsNothing);
      expect(find.text('Sức khỏe'), findsOneWidget);
      await tester.tap(find.text('Sức khỏe'));
      expect(more, 1);
    });

    testWidgets('without shortcuts only the "Khác" tile is left', (
      tester,
    ) async {
      await pump(
        tester,
        CategoryShortcutGrid(
          shortcuts: const [],
          selected: null,
          onSelected: (_) {},
          onMore: () {},
        ),
      );

      expect(find.byKey(CategoryShortcutGrid.moreKey), findsOneWidget);
      expect(find.text('Khác'), findsOneWidget);
    });

    testWidgets('all tiles have the height of the tallest one', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // In a scroll view, as on the form: the tiles get no height from outside.
      await pump(
        tester,
        SingleChildScrollView(
          child: CategoryShortcutGrid(
            shortcuts: const ['Ăn uống', 'Internet & Điện thoại', 'Mua sắm'],
            selected: 'Ăn uống',
            onSelected: (_) {},
            onMore: () {},
          ),
        ),
      );

      double height(Finder label) => tester
          .getSize(find.ancestor(of: label, matching: find.byType(InkWell)))
          .height;
      final tall = height(find.text('Internet & Điện thoại'));
      expect(height(find.text('Khác')), tall);
      expect(height(find.text('Ăn uống')), tall);
    });

    testWidgets(
      'long English names at 320 px and text scale 1.3 do not overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: withAppSettings(
              Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CategoryShortcutGrid(
                    shortcuts: const [
                      'Siêu thị & Chợ',
                      'Internet & Điện thoại',
                      'Gia đình & Con cái',
                    ],
                    selected: 'Siêu thị & Chợ',
                    onSelected: (_) {},
                    onMore: () {},
                  ),
                ),
              ),
              settings: FakeSettingsRepository(language: AppLanguage.english),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('More'), findsOneWidget);
      },
    );
  });

  group('showCategoryPickerSheet', () {
    testWidgets('returns the tapped category and ticks the selected one', (
      tester,
    ) async {
      String? result;
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showCategoryPickerSheet(
                context,
                categories: const ['Ăn uống', 'Mua sắm', 'Sức khỏe'],
                selected: 'Ăn uống',
                isExpense: true,
              );
            },
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Chọn danh mục chi'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.tap(find.text('Sức khỏe'));
      await tester.pumpAndSettle();
      expect(result, 'Sức khỏe');
    });
  });

  group('NoteField', () {
    testWidgets(
      'a note longer than core-backend takes is cut at 255 characters',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await pump(tester, NoteField(controller: controller));

        await tester.enterText(find.byType(TextField), 'a' * 300);
        await tester.pump();

        expect(InputLimits.noteMaxLength, 255);
        expect(controller.text, 'a' * InputLimits.noteMaxLength);
      },
    );

    testWidgets('a note within the limit is kept as typed', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pump(tester, NoteField(controller: controller));

      await tester.enterText(find.byType(TextField), 'b' * 255);
      await tester.pump();

      expect(controller.text, 'b' * 255);
    });
  });

  group('tabs', () {
    testWidgets('TransactionTypeTabs reports the income tab', (tester) async {
      bool? isExpense;
      await pump(
        tester,
        TransactionTypeTabs(
          isExpense: true,
          onChanged: (value) => isExpense = value,
        ),
      );

      expect(find.text('Chi tiêu'), findsOneWidget);
      await tester.tap(find.text('Thu nhập'));
      expect(isExpense, isFalse);
    });

    testWidgets('EntryModeTabs calls onScan from the scan tab only', (
      tester,
    ) async {
      var scans = 0;
      await pump(tester, EntryModeTabs(onScan: () => scans++));

      await tester.tap(find.text('Nhập tay'));
      expect(scans, 0);
      await tester.tap(find.text('Quét hóa đơn'));
      expect(scans, 1);
    });
  });

  group('FormSubmitBar', () {
    testWidgets('without onPressed it is faded and does nothing', (
      tester,
    ) async {
      await pump(tester, const FormSubmitBar(label: 'Thêm giao dịch chi'));

      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('Thêm giao dịch chi'),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, FormSubmitBar.disabledOpacity);
      await tester.tap(find.text('Thêm giao dịch chi'));
    });

    testWidgets('with onPressed it is fully shown and reports the tap', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        FormSubmitBar(label: 'Thêm giao dịch chi', onPressed: () => taps++),
      );

      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('Thêm giao dịch chi'),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 1);
      await tester.tap(find.text('Thêm giao dịch chi'));
      expect(taps, 1);
    });

    testWidgets('busy shows a spinner and ignores taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        withAppSettings(
          Scaffold(
            body: FormSubmitBar(
              label: 'Lưu thay đổi',
              busy: true,
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Lưu thay đổi'));
      expect(taps, 0);
    });
  });
}
