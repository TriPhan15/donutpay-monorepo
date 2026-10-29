import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/screens/receipt_scanner/review_form_page.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_settings_repository.dart';
import '../../helpers/theme_colors.dart';

/// A real file of the project, so that the scan can read it: it stands for the photo of the receipt.
const String _photo = 'assets/images/logo.png';

void main() {
  final backend = FakeBackend();

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    // SharedPreferences shares one Future that must be created inside the test body (see budget_display_test.dart).
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});
    TransactionCategories.expenseSelectable.clear();
    TransactionCategories.incomeSelectable.clear();

    backend.reset();
    backend.on(
      'POST',
      '/donut/scan',
      (_) => jsonResponse(200, {
        'seller': {
          'seller_name': 'Highlands',
          'timestamp': '20/09/2026 08:30',
          'total_cost_number': 45000,
        },
      }),
    );
    backend.on(
      'POST',
      '/api/upload',
      (_) => jsonResponse(200, {'url': 'https://example.com/receipt.png'}),
    );
    backend.on(
      'GET',
      '/api/categories',
      (_) => okResponse([
        {'id': 10, 'name': 'Ăn uống', 'type': 'EXPENSE'},
        {'id': 11, 'name': 'Di chuyển', 'type': 'EXPENSE'},
      ]),
    );
  });

  tearDown(() {
    // The language cubit of withAppSettings sets the default locale of intl.
    Intl.defaultLocale = null;
  });

  Future<void> start(WidgetTester tester, Widget screen, ThemeMode mode) {
    tester.view.physicalSize = const Size(600, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      withAppSettings(
        screen,
        settings: FakeSettingsRepository(themeMode: mode),
      ),
    );
  }

  /// The review form once the scan has answered. Reading the photo is real file I/O, which the fake clock of the test
  /// does not run: it gets real time first, then the pumps run the request and the rebuild.
  Future<ThemeData> openForm(WidgetTester tester, ThemeMode mode) async {
    await start(tester, const ReviewFormPage(imagePath: _photo), mode);
    for (var i = 0; i < 20 && find.text('Highlands').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.text('Highlands'), findsOneWidget);
    return Theme.of(tester.element(find.byType(ReviewFormPage)));
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    group('${mode.name} theme', () {
      testWidgets('ReviewFormPage: the analysing state follows the theme', (
        tester,
      ) async {
        await start(tester, const ReviewFormPage(imagePath: _photo), mode);
        await tester.pump();
        final theme = Theme.of(tester.element(find.byType(ReviewFormPage)));

        expect(
          materialColor(tester, find.byType(Scaffold)),
          theme.scaffoldBackgroundColor,
        );
        expect(
          tester
              .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator),
              )
              .color,
          isNull,
          reason: 'the spinner takes the primary colour of the theme',
        );
        expect(
          paintedColor(tester, find.text('Đang phân tích hóa đơn...')),
          theme.colorScheme.onSurface,
        );
        expect(
          paintedColor(tester, find.text('Vui lòng đợi trong giây lát')),
          theme.colorScheme.onSurfaceVariant,
        );
      });

      testWidgets(
        'ReviewFormPage: band, photo, fields, category and buttons follow the theme',
        (tester) async {
          backend.on(
            'POST',
            '/donut/scan',
            (_) => jsonResponse(200, {
              'seller': {
                'seller_name': 'Highlands',
                'timestamp': '20/09/2026 08:30',
                'total_cost_number': 45000,
              },
              'normalized': {
                'seller': {
                  'raw': 'Highlands',
                  'value': 'Highlands',
                  'valid': false,
                },
                'timestamp': {
                  'raw': '',
                  'value': '',
                  'iso': '2026-09-20T08:30:00',
                  'valid': true,
                },
                'total_cost': {'raw': '45000', 'value': 45000, 'valid': true},
              },
            }),
          );
          final theme = await openForm(tester, mode);
          final colors = theme.colorScheme;
          final semantic = theme.extension<SemanticColors>()!;

          final band = tester.widget<Container>(
            find
                .descendant(
                  of: find.byType(PageBand),
                  matching: find.byType(Container),
                )
                .first,
          );
          expect(
            (band.decoration as BoxDecoration).gradient,
            semantic.headerGradient,
          );

          // The photo of the receipt keeps its own colours: nothing filters or tints it.
          expect(find.byType(ColorFiltered), findsNothing);
          final photo = tester.widget<Image>(find.byType(Image));
          expect(photo.color, isNull);
          expect(photo.colorBlendMode, isNull);

          // The store field: fill, label, prefix icon, text and cursor from the theme.
          final store = find.byKey(ReviewFormPage.storeFieldKey);
          final decoration = tester
              .widget<InputDecorator>(
                find.descendant(
                  of: store,
                  matching: find.byType(InputDecorator),
                ),
              )
              .decoration;
          expect(decoration.fillColor, colors.surface);
          expect(
            paintedColor(tester, find.text('Tên cửa hàng')),
            colors.onSurfaceVariant,
          );
          final editable = tester.widget<EditableText>(
            find.descendant(of: store, matching: find.byType(EditableText)),
          );
          expect(editable.style.color, colors.onSurface);
          expect(editable.cursorColor, colors.primary);

          // The doubted store name: "Cần kiểm tra" and its hint in the warning colour.
          expect(
            paintedColor(tester, find.text('Cần kiểm tra')),
            semantic.warningColor,
          );
          expect(
            paintedColor(
              tester,
              find.text('Chưa chắc tên cửa hàng, hãy sửa nếu sai.'),
            ),
            semantic.warningColor,
          );

          // The guessed category is the selected tile.
          expect(paintedColor(tester, find.text('Ăn uống')), colors.primary);

          expect(
            materialColor(tester, find.widgetWithText(FilledButton, 'Lưu')),
            colors.primary,
          );
          expect(
            paintedColor(
              tester,
              find.descendant(
                of: find.byType(FilledButton),
                matching: find.text('Lưu'),
              ),
            ),
            colors.onPrimary,
          );
          expect(
            paintedColor(tester, find.text('Lưu & quét tiếp')),
            colors.primary,
          );
        },
      );

      testWidgets('ReviewFormPage: the category sheet follows the theme', (
        tester,
      ) async {
        final colors = (await openForm(tester, mode)).colorScheme;

        await tester.tap(find.text('Khác'));
        await tester.pumpAndSettle();

        final sheet = find.byType(BottomSheet);
        expect(materialColor(tester, sheet), colors.surface);
        expect(
          paintedColor(tester, find.text('Chọn danh mục chi')),
          colors.onSurface,
        );
        final chosen = find.widgetWithText(ListTile, 'Ăn uống');
        expect(
          paintedColor(
            tester,
            find.descendant(of: chosen, matching: find.text('Ăn uống')),
          ),
          colors.onSurface,
        );
        expect(
          paintedColor(
            tester,
            find.descendant(
              of: chosen,
              matching: find.byIcon(Icons.check_rounded),
            ),
          ),
          colors.primary,
        );
        expect(
          paintedColor(
            tester,
            find.descendant(of: sheet, matching: find.text('Di chuyển')),
          ),
          colors.onSurfaceVariant,
        );
      });
    });
  }
}
