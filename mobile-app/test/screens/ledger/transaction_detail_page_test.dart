import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/models/receipt_status.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ledger/edit_transaction_page.dart';
import 'package:finance_ai_app/screens/ledger/transaction_detail_page.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_image_viewer.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_status_badge.dart';
import 'package:finance_ai_app/widgets/sync/sync_status_badge.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';
import '../../helpers/fake_settings_repository.dart';

const String _savingsManaged =
    'Khoản góp tiết kiệm được quản lý ở mục Tiết kiệm.';

TransactionModel _tx({
  String? id = '5',
  String title = 'Highlands Coffee',
  double amount = 55000,
  bool isExpense = true,
  String category = 'Ăn uống',
  ReceiptStatus? receiptStatus,
  SyncStatus syncStatus = SyncStatus.synced,
  String? imageUrl,
  String? clientId,
}) => TransactionModel(
  id: id,
  title: title,
  amount: amount,
  date: DateTime(2026, 10, 20, 8, 15),
  category: category,
  isExpense: isExpense,
  receiptStatus: receiptStatus,
  syncStatus: syncStatus,
  imageUrl: imageUrl,
  clientId: clientId,
);

void main() {
  final backend = FakeBackend();

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    AppRepository.instance.localStore = FakeLocalStore();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});
    backend.reset();
  });

  Future<ColorScheme> pump(
    WidgetTester tester,
    TransactionModel tx, {
    ThemeMode mode = ThemeMode.light,
    Size size = const Size(600, 1600),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: TransactionDetailPage(transaction: tx),
        ),
        settings: FakeSettingsRepository(themeMode: mode),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    return Theme.of(
      tester.element(find.byType(TransactionDetailPage)),
    ).colorScheme;
  }

  Color? textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  testWidgets('thin band with a round back button and the page title', (
    tester,
  ) async {
    await pump(tester, _tx());
    expect(find.text('Chi tiết giao dịch'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Chi tiết giao dịch'));
    expect(title.style?.fontSize, AppTextSize.pageTitle);
    expect(title.style?.color, Colors.white);
    expect(find.byKey(TransactionDetailPage.backKey), findsOneWidget);
    final band = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(TransactionDetailPage.bandKey),
            matching: find.byType(Container),
          )
          .first,
    );
    final context = tester.element(find.byType(TransactionDetailPage));
    expect(
      (band.decoration as BoxDecoration).gradient,
      Theme.of(context).semanticColors.headerGradient,
    );
  });

  testWidgets('the back button closes the page', (tester) async {
    await tester.pumpWidget(
      withAppSettings(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransactionDetailPage(transaction: _tx()),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TransactionDetailPage.backKey));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDetailPage), findsNothing);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'the head card shows the category tile, the title and the amount at 24 (${mode.name})',
      (tester) async {
        final colors = await pump(tester, _tx(), mode: mode);
        final amount = tester.widget<Text>(find.text('-55.000 đ'));
        expect(amount.style?.fontSize, AppTextSize.amount);
        expect(amount.style?.color, colors.onSurface);
        expect(
          tester.widget<Text>(find.text('Highlands Coffee')).style?.fontSize,
          AppTextSize.title,
        );
      },
    );
  }

  testWidgets('income is green with a plus', (tester) async {
    await pump(
      tester,
      _tx(
        title: 'Lương',
        amount: 18500000,
        isExpense: false,
        category: 'Lương',
      ),
    );
    final context = tester.element(find.byType(TransactionDetailPage));
    expect(
      textColor(tester, '+18.500.000 đ'),
      Theme.of(context).semanticColors.successColor,
    );
  });

  testWidgets(
    'rows: category and time always, receipt only with a receipt, sync only while unsent',
    (tester) async {
      await pump(tester, _tx());
      expect(find.text('Danh mục'), findsOneWidget);
      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.text('Thời gian'), findsOneWidget);
      expect(find.text('20/10/2026 08:15'), findsOneWidget);
      expect(find.text('Hóa đơn'), findsNothing);
      expect(find.text('Đồng bộ'), findsNothing);

      await pump(tester, _tx(receiptStatus: ReceiptStatus.success, id: '6'));
      expect(find.text('Hóa đơn'), findsOneWidget);
      expect(find.byType(ReceiptStatusBadge), findsOneWidget);
    },
  );

  testWidgets('the receipt photo spans the width and opens the viewer', (
    tester,
  ) async {
    await pump(tester, _tx(imageUrl: 'https://example.com/r.jpg'));
    final photo = find.byKey(TransactionDetailPage.photoKey);
    expect(photo, findsOneWidget);
    // Page width 600 minus the 16 px gutters.
    expect(tester.getSize(photo).width, 568);
    await tester.tap(photo);
    await tester.pumpAndSettle();
    expect(find.byType(ReceiptImageViewerPage), findsOneWidget);
  });

  testWidgets(
    'bottom: Sửa giao dịch is filled primary, Xóa is light red and asks first',
    (tester) async {
      final colors = await pump(tester, _tx());
      expect(
        find.widgetWithText(FilledButton, 'Sửa giao dịch'),
        findsOneWidget,
      );
      final delete = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Xóa'),
      );
      expect(delete.style?.backgroundColor?.resolve({}), colors.errorContainer);
      expect(delete.style?.foregroundColor?.resolve({}), colors.error);

      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa giao dịch?'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(backend.calls.where((c) => c.startsWith('DELETE')), isEmpty);
      expect(find.byType(TransactionDetailPage), findsOneWidget);
    },
  );

  testWidgets(
    'an unsent row offers Gửi lại in its sync row and delete from the device, no edit',
    (tester) async {
      await pump(
        tester,
        _tx(id: null, syncStatus: SyncStatus.error, clientId: 'c-1'),
      );
      expect(find.text('Đồng bộ'), findsOneWidget);
      expect(find.byType(SyncStatusBadge), findsOneWidget);
      expect(find.text('Gửi lại'), findsOneWidget);
      expect(find.text('Sửa giao dịch'), findsNothing);
      expect(find.text('Xóa'), findsOneWidget);
    },
  );

  testWidgets('a row being sent offers no delete', (tester) async {
    await pump(
      tester,
      _tx(id: null, syncStatus: SyncStatus.pending, clientId: 'c-2'),
    );
    expect(find.text('Xóa'), findsNothing);
  });

  testWidgets(
    'a savings row managed by a goal shows the note instead of the buttons',
    (tester) async {
      backend.on(
        'GET',
        '/api/savings',
        (_) => okResponse([
          {
            'id': 1,
            'name': 'Du lịch',
            'targetAmount': 1000000,
            'currentAmount': 0,
          },
        ]),
      );
      await pump(tester, _tx(category: 'Tiết kiệm', title: 'Góp'));
      expect(find.text(_savingsManaged), findsOneWidget);
      expect(find.text('Sửa giao dịch'), findsNothing);
      expect(find.text('Xóa'), findsNothing);
    },
  );

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'fits 320 px at text scale 1.3 with a long title (${mode.name})',
      (tester) async {
        await pump(
          tester,
          _tx(
            title: 'Siêu thị Co.opmart Phan Văn Trị, Gò Vấp, TP. Hồ Chí Minh',
            receiptStatus: ReceiptStatus.success,
            amount: 123456789,
          ),
          mode: mode,
          size: const Size(320, 900),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('two quick taps on Xóa open one confirm dialog', (tester) async {
    await pump(tester, _tx());
    await tester.tap(find.text('Xóa'));
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa giao dịch?'), findsOneWidget);
  });

  testWidgets('two quick taps on Sửa giao dịch open one edit form', (
    tester,
  ) async {
    backend.on('GET', '/api/categories', (_) => okResponse([]));
    await pump(tester, _tx());
    await tester.tap(find.text('Sửa giao dịch'));
    await tester.tap(find.text('Sửa giao dịch'));
    await tester.pumpAndSettle();
    expect(find.byType(EditTransactionPage), findsOneWidget);
  });
}
