import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/receipt_scanner/review_form_page.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';

/// A real file of the project, so that the scan and the upload can read it: it stands for the photo of the receipt.
const String _photo = 'assets/images/logo.png';
const String _scan = '/donut/scan';
const String _upload = '/api/upload';
const String _checkout = '/api/transactions/checkout';
const String _photoUrl = 'https://example.com/receipt.png';
const String _save = 'Xác nhận & Lưu CSDL';
const String _dateFallbackHint =
    'Không đọc được ngày trên hóa đơn, đang dùng thời điểm hiện tại. Chạm để chọn lại.';

/// What ai-service answers for a receipt of Highlands.
ResponseBody _scanned({
  Object total = 45000,
  String timestamp = '20/09/2026 08:30',
}) => jsonResponse(200, {
  'seller': {
    'seller_name': 'Highlands',
    'timestamp': timestamp,
    'total_cost_number': total,
  },
});

void main() {
  final backend = FakeBackend();
  late FakeLocalStore store;

  setUpAll(() async {
    // The themes load Poppins through google_fonts once, and that fetch fails in a test (there is no network). Started
    // here, in a zone that ignores the failure, it cannot fail the first test that gives real time to I/O (runAsync).
    runZonedGuarded(() => [AppTheme.lightTheme, AppTheme.darkTheme], (_, _) {});
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
    store = FakeLocalStore();
    AppRepository.instance.localStore = store;

    backend.reset();
    backend.on('POST', _scan, (_) => _scanned());
    backend.on('POST', _upload, (_) => jsonResponse(200, {'url': _photoUrl}));
    backend.on(
      'POST',
      _checkout,
      (_) => okResponse({'transactionId': 5, 'finalAmount': 50000}),
    );
  });

  tearDown(() {
    // The language cubit of withAppSettings sets the default locale of intl.
    Intl.defaultLocale = null;
  });

  List<Map<String, dynamic>> sentBodies() => [
    for (final request in backend.requests)
      if (request.path == _checkout)
        Map<String, dynamic>.from(request.data as Map),
  ];

  int uploads() => backend.calls.where((c) => c == 'POST $_upload').length;

  /// Reading the photo is real file I/O, which the fake clock of the test does not run: it gets real time until
  /// [done] holds, and the pumps run the requests and the rebuilds.
  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 40 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  /// Opens the review form from a page of its own, like MainScaffold does; [result] gets what the form closes with.
  Future<List<bool?>> openForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final result = <bool?>[];
    await tester.pumpWidget(
      withAppSettings(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result.add(
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReviewFormPage(imagePath: _photo),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await settle(tester, () => find.text(_save).evaluate().isNotEmpty);
    expect(find.text(_save), findsOneWidget);
    return result;
  }

  Finder field(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text(_save));
    await tester.pump();
    await settle(tester, () => find.byType(Dialog).evaluate().isNotEmpty);
  }

  testWidgets(
    'the total from the AI can be corrected, and the photo is uploaded only when saving',
    (tester) async {
      final result = await openForm(tester);

      expect(
        find.descendant(
          of: field('Tổng tiền (đ)'),
          matching: find.text('45000'),
        ),
        findsOneWidget,
      );
      expect(
        uploads(),
        0,
        reason: 'nothing is uploaded while the form is only open',
      );
      expect(find.text(_dateFallbackHint), findsNothing);

      await tester.enterText(field('Tổng tiền (đ)'), '50000');
      await tester.pump();
      expect(
        find.text(
          NumberFormat.currency(
            locale: 'vi_VN',
            symbol: 'đ',
            decimalDigits: 0,
          ).format(50000),
        ),
        findsNWidgets(2),
        reason: 'the totals card follows the amount field',
      );

      await tapSave(tester);
      expect(find.text('Thành công'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(uploads(), 1);
      final body = sentBodies().single;
      expect(body['amount'], 50000);
      expect(body['clientId'], isNotNull);
      expect(body['imageUrl'], _photoUrl);
      expect(
        body['transactionDate'],
        DateTime(2026, 9, 20, 8, 30).toIso8601String(),
      );
      expect(body['note'], 'Highlands');
      expect(
        jsonDecode(body['rawReceiptData'] as String)['seller']['seller_name'],
        'Highlands',
      );
      expect(store.rows.single.syncStatus, SyncStatus.synced);
      expect(result, [true]);
    },
  );

  testWidgets(
    'a total the AI could not read leaves the field empty, and saving without one is refused',
    (tester) async {
      backend.on('POST', _scan, (_) => _scanned(total: 0));
      final result = await openForm(tester);

      await tapSave(tester);

      expect(find.text('Số tiền không hợp lệ'), findsOneWidget);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      expect(sentBodies(), isEmpty);
      expect(uploads(), 0);
      expect(
        result,
        isEmpty,
        reason: 'the form stays open to type the total in',
      );
    },
  );

  testWidgets(
    'a receipt date that cannot be read falls back to now, with a warning under the field',
    (tester) async {
      backend.on('POST', _scan, (_) => _scanned(timestamp: 'ngày 20 tháng 9'));
      final before = DateTime.now().subtract(const Duration(minutes: 1));
      await openForm(tester);

      expect(find.text(_dateFallbackHint), findsOneWidget);

      await tapSave(tester);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final sent = DateTime.parse(
        sentBodies().single['transactionDate'] as String,
      );
      expect(sent.isAfter(before), isTrue);
    },
  );

  testWidgets('the date field opens a date picker instead of the keyboard', (
    tester,
  ) async {
    await openForm(tester);

    final date = tester.widget<EditableText>(
      find.descendant(
        of: field('Ngày giao dịch'),
        matching: find.byType(EditableText),
      ),
    );
    expect(date.readOnly, isTrue);

    await tester.tap(field('Ngày giao dịch'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets(
    'a failed upload asks first: "Để sau" sends nothing, "Lưu không kèm ảnh" saves without the photo',
    (tester) async {
      backend.on(
        'POST',
        _upload,
        (_) => jsonResponse(500, {'message': 'Cloudinary'}),
      );
      final result = await openForm(tester);

      await tapSave(tester);
      expect(find.text('Không tải được ảnh hóa đơn'), findsOneWidget);
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      expect(sentBodies(), isEmpty);
      expect(result, isEmpty);

      await tapSave(tester);
      expect(uploads(), 2, reason: 'the second save tries the upload again');
      await tester.tap(find.text('Lưu không kèm ảnh'));
      await tester.pump();
      await settle(tester, () => find.text('Thành công').evaluate().isNotEmpty);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(sentBodies().single.containsKey('imageUrl'), isFalse);
      expect(result, [true]);
    },
  );

  testWidgets(
    'without network the transaction waits on the device with its receipt, instead of failing',
    (tester) async {
      backend.on(
        'POST',
        _checkout,
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'no network',
        ),
      );
      final result = await openForm(tester);

      await tapSave(tester);

      expect(find.text('Chưa gửi được lên máy chủ'), findsOneWidget);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      final waiting = store.rows.single;
      expect(waiting.syncStatus, SyncStatus.error);
      expect(waiting.imageUrl, _photoUrl);
      expect(waiting.rawReceiptData, isNotNull);
      expect(result, [true]);
    },
  );

  testWidgets(
    'a refusal of the server shows its reason and keeps the form open',
    (tester) async {
      backend.on(
        'POST',
        _checkout,
        (_) => jsonResponse(400, {
          'code': 400,
          'message': 'Danh mục không tồn tại',
        }),
      );
      final result = await openForm(tester);

      await tapSave(tester);

      expect(find.text('Lưu thất bại'), findsOneWidget);
      expect(find.text('Danh mục không tồn tại'), findsOneWidget);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      expect(store.rows, isEmpty);
      expect(result, isEmpty);
    },
  );
}
