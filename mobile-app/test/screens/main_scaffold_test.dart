import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show DatabaseException;

import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/di/injection_container.dart';
import 'package:finance_ai_app/main.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/repositories/settings_repository_impl.dart';
import 'package:finance_ai_app/screens/ledger/transaction_detail_page.dart';
import 'package:finance_ai_app/screens/dashboard/dashboard_page.dart';
import 'package:finance_ai_app/screens/main_scaffold.dart';
import 'package:finance_ai_app/screens/main_tabs.dart';
import 'package:finance_ai_app/screens/receipt_scanner/review_form_page.dart';
import 'package:finance_ai_app/screens/startup/startup_splash_screen.dart';
import 'package:finance_ai_app/services/budget_alert_tracker.dart';
import 'package:finance_ai_app/services/receipt_scan_queue.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/budget/budget_alert_presenter.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';
import 'package:finance_ai_app/widgets/receipt/scan_queue_banner.dart';

import '../helpers/fake_backend.dart';
import '../helpers/fake_local_store.dart';
import '../helpers/fake_scan_queue.dart';

/// The tabs in the order of the bottom bar.
const List<(String, IconData)> _tabs = [
  ('Trang chủ', Icons.home_rounded),
  ('Thống kê', Icons.bar_chart_rounded),
  ('AI', Icons.auto_awesome_rounded),
  ('Cá nhân', Icons.person_rounded),
];

/// The channel image_picker talks to when no platform plugin is registered, as in a widget test.
const MethodChannel _imagePickerChannel = MethodChannel(
  'plugins.flutter.io/image_picker',
);

/// The toast for a queue that could not be written to storage.
const String _storageFailedText =
    'Không cập nhật được hàng chờ hóa đơn trên máy. Vui lòng thử lại.';

/// A storage failure of the queue.
class _DiskFull implements DatabaseException {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Finder _inBottomBar(Finder finder) =>
    find.descendant(of: find.byType(BottomAppBar), matching: finder);

Finder _scanButtonIcon() => find.descendant(
  of: find.byType(FloatingActionButton),
  matching: find.byIcon(Icons.document_scanner_rounded),
);

/// The colour a text or an icon is painted with: both draw through a RichText.
Color? _paintedColor(WidgetTester tester, Finder finder) => tester
    .widget<RichText>(
      find.descendant(of: finder, matching: find.byType(RichText)).first,
    )
    .text
    .style
    ?.color;

Color? _materialColor(WidgetTester tester, Finder owner) => tester
    .widget<Material>(
      find.descendant(of: owner, matching: find.byType(Material)).first,
    )
    .color;

Color _bottomBarColor(WidgetTester tester) => tester
    .widget<PhysicalShape>(
      find.descendant(
        of: find.byType(BottomAppBar),
        matching: find.byType(PhysicalShape),
      ),
    )
    .color;

void main() {
  final backend = FakeBackend();
  final scanQueue = FakeScanQueue();

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    // The tabs also read the transactions waiting to be sent; the fake keeps the test away from a real database.
    AppRepository.instance.localStore = FakeLocalStore();
    // MainScaffold resumes the scan queue and its banner listens to it; the fake keeps the database out of the test.
    ReceiptScanQueue.instanceForTesting = scanQueue;
  });

  tearDown(() async {
    await sl.reset();
    Intl.defaultLocale = null;
  });

  /// Signed in, with [mode] saved as the theme: what main() finds on the device before runApp.
  Future<void> signInWithSavedTheme(ThemeMode mode) async {
    SharedPreferences.setMockInitialValues({
      SettingsRepositoryImpl.themeModeKey: mode.name,
      SettingsRepositoryImpl.languageKey: 'vi',
    });
    await configureDependencies();
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    await SessionService.setTokens('access-token', 'refresh-token');
    BudgetAlertTracker.instance.resetMemory();
    BudgetAlertPresenter.resetQueue();
    scanQueue.reset();

    backend.reset();
    backend.on('GET', '/api/categories', (_) => okResponse([]));
    backend.on(
      'GET',
      '/api/users/me',
      (_) => okResponse({'id': 1, 'email': 'an@example.com'}),
    );
    backend.on('GET', '/api/transactions/mine', (_) => okResponse([]));
    backend.on('GET', '/api/budgets', (_) => okResponse([]));
    backend.on('GET', '/api/savings', (_) => okResponse([]));
    // The home tab also asks for the number on its notification bell.
    backend.on('GET', '/api/notifications/unread-count', (_) => okResponse(0));
    backend.on(
      'POST',
      '/spade/analyze',
      (_) => jsonResponse(200, {'patterns': []}),
    );
    // A Future made here and awaited inside testWidgets never completes, so the test body gets its own instance.
    SharedPreferences.setMockInitialValues({});
  }

  /// Pumps the first frame only: the session is still being checked, so the startup loading screen shows.
  Future<void> startApp(WidgetTester tester) async {
    // Wide and tall, because the test font is much wider than a real one and the tabs would overflow at phone width.
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DonutPayApp());
  }

  Future<ThemeData> openMainScaffold(WidgetTester tester) async {
    await startApp(tester);
    await tester.pumpAndSettle();
    expect(find.byType(MainScaffold), findsOneWidget);
    return Theme.of(tester.element(find.byType(MainScaffold)));
  }

  void expectSelectedTab(
    WidgetTester tester,
    ColorScheme colors,
    int selected,
  ) {
    for (var i = 0; i < _tabs.length; i++) {
      final (label, icon) = _tabs[i];
      final expected = i == selected ? colors.primary : colors.onSurfaceVariant;
      expect(
        _paintedColor(tester, _inBottomBar(find.text(label))),
        expected,
        reason: label,
      );
      expect(
        _paintedColor(tester, _inBottomBar(find.byIcon(icon))),
        expected,
        reason: label,
      );
    }
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final brightness = mode == ThemeMode.dark
        ? Brightness.dark
        : Brightness.light;

    group('saved ${mode.name} theme', () {
      setUp(() => signInWithSavedTheme(mode));

      testWidgets('the startup splash screen is built under it', (
        tester,
      ) async {
        await startApp(tester);

        final splash = find.byType(StartupSplashScreen);
        expect(splash, findsOneWidget);
        expect(Theme.of(tester.element(splash)).brightness, brightness);

        await tester.pumpAndSettle();
        expect(find.byType(MainScaffold), findsOneWidget);
      });

      testWidgets(
        'the page, the bottom bar, the scan button, the tabs and the system bars follow it',
        (tester) async {
          final theme = await openMainScaffold(tester);
          final colors = theme.colorScheme;

          expect(theme.brightness, brightness);
          expect(
            _materialColor(tester, find.byType(MainScaffold)),
            theme.scaffoldBackgroundColor,
          );
          expect(_bottomBarColor(tester), colors.surface);
          expect(
            _materialColor(tester, find.byType(FloatingActionButton)),
            colors.primary,
          );
          expect(_paintedColor(tester, _scanButtonIcon()), colors.onPrimary);
          expectSelectedTab(tester, colors, 0);

          await tester.tap(_inBottomBar(find.text('Thống kê')));
          await tester.pumpAndSettle();
          expectSelectedTab(tester, colors, 1);

          // MainScaffold has no app bar, so the region at the root of the app sets both system bars.
          final rootRegion = find.ancestor(
            of: find.byType(Navigator),
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          );
          expect(
            tester
                .widget<AnnotatedRegion<SystemUiOverlayStyle>>(rootRegion)
                .value,
            AppTheme.overlayStyleFor(brightness),
          );
          expect(
            SystemChrome.latestStyle,
            AppTheme.overlayStyleFor(brightness),
          );
        },
      );

      testWidgets('the scan sheet follows it', (tester) async {
        await openMainScaffold(tester);
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        final sheet = find.byType(BottomSheet);
        final colors = Theme.of(tester.element(sheet)).colorScheme;
        final fills = tester
            .widgetList<Container>(
              find.descendant(of: sheet, matching: find.byType(Container)),
            )
            .map((container) => container.decoration)
            .whereType<BoxDecoration>()
            .map((decoration) => decoration.color);

        expect(_materialColor(tester, sheet), colors.surface);
        for (final text in [
          'Quét hóa đơn bằng AI',
          'Quét bằng camera',
          'Chọn từ thư viện',
        ]) {
          expect(
            _paintedColor(
              tester,
              find.descendant(of: sheet, matching: find.text(text)),
            ),
            colors.onSurface,
            reason: text,
          );
        }
        for (final icon in [
          Icons.document_scanner_rounded,
          Icons.photo_library_rounded,
        ]) {
          expect(
            _paintedColor(
              tester,
              find.descendant(of: sheet, matching: find.byIcon(icon)),
            ),
            colors.primary,
          );
        }
        expect(
          fills,
          containsAll([
            colors.onSurfaceVariant.withValues(alpha: 0.3),
            colors.primaryContainer,
          ]),
        );

        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);
      });
    });
  }

  group('home tab shortcuts', () {
    setUp(() => signInWithSavedTheme(ThemeMode.light));

    testWidgets(
      '"Lưu & quét tiếp" after a single scan opens the scan sheet again',
      (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_imagePickerChannel, (call) async {
              return call.method == 'pickImage'
                  ? 'assets/images/logo.png'
                  : null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(_imagePickerChannel, null),
        );
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
          (_) => jsonResponse(200, {'url': 'https://example.com/r.png'}),
        );
        backend.on(
          'POST',
          '/api/transactions/checkout',
          (_) => okResponse({'transactionId': 5, 'finalAmount': 45000}),
        );
        // Reading and uploading the photo is real file I/O, which the fake clock does not run.
        Future<void> settle(bool Function() done) async {
          for (var i = 0; i < 40 && !done(); i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump(const Duration(milliseconds: 100));
          }
          await tester.pumpAndSettle();
        }

        await openMainScaffold(tester);
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chọn từ thư viện'));
        await tester.pump();
        final saveAndScan = find.widgetWithText(
          OutlinedButton,
          'Lưu & quét tiếp',
        );
        await settle(() => saveAndScan.evaluate().isNotEmpty);
        expect(find.byType(ReviewFormPage), findsOneWidget);

        await tester.tap(saveAndScan);
        await tester.pump();
        await settle(() => find.text('Xong').evaluate().isNotEmpty);
        await tester.tap(find.text('Xong'));
        await tester.pump();
        await settle(() => find.byType(BottomSheet).evaluate().isNotEmpty);

        expect(find.byType(ReviewFormPage), findsNothing);
        expect(find.text('Chọn cách đưa hóa đơn vào'), findsOneWidget);
      },
    );

    testWidgets(
      'a recent transaction opens the Ledger tab and its detail page, as a transaction notification does',
      (tester) async {
        backend.on(
          'GET',
          '/api/transactions/mine',
          (_) => okResponse([
            {
              'id': 3,
              'title': 'Cà phê',
              'amount': 45000,
              'date': DateTime.now().toIso8601String(),
              'category': 'Ăn uống',
              'isExpense': true,
            },
          ]),
        );
        final colors = (await openMainScaffold(tester)).colorScheme;
        expect(find.text('Sửa giao dịch'), findsNothing);

        await tester.tap(find.text('Cà phê'));
        await tester.pumpAndSettle();

        expect(find.byType(TransactionDetailPage), findsOneWidget);
        expect(find.text('Sửa giao dịch'), findsOneWidget);
        await tester.tap(find.byKey(TransactionDetailPage.backKey));
        await tester.pumpAndSettle();
        expectSelectedTab(tester, colors, 1);
      },
    );

    testWidgets('"Quét hóa đơn" opens the scan sheet of the scan button', (
      tester,
    ) async {
      await openMainScaffold(tester);

      await tester.tap(find.byIcon(Icons.receipt_long_rounded));
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      for (final text in [
        'Quét hóa đơn bằng AI',
        'Quét bằng camera',
        'Chọn từ thư viện',
      ]) {
        expect(
          find.descendant(of: sheet, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
    });
    testWidgets('MainTabs.scanner opens the same scan sheet', (tester) async {
      await openMainScaffold(tester);

      MainTabs.scanner!();
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('Quét hóa đơn bằng AI')),
        findsOneWidget,
      );
    });
  });

  group('light mode', () {
    setUp(() => signInWithSavedTheme(ThemeMode.light));

    testWidgets('keeps the colours MainScaffold had before the migration', (
      tester,
    ) async {
      await startApp(tester);

      await tester.pumpAndSettle();
      expect(
        _materialColor(tester, find.byType(MainScaffold)),
        AppTheme.bgLight,
      );
      expect(_bottomBarColor(tester), Colors.white);
      expect(
        _materialColor(tester, find.byType(FloatingActionButton)),
        AppTheme.primary,
      );
      expect(_paintedColor(tester, _scanButtonIcon()), Colors.white);
      expect(
        _paintedColor(tester, _inBottomBar(find.text('Trang chủ'))),
        AppTheme.primary,
      );
      expect(
        _paintedColor(tester, _inBottomBar(find.text('Cá nhân'))),
        AppTheme.textGray,
      );
    });
  });

  group('batch receipt scan', () {
    setUp(() => signInWithSavedTheme(ThemeMode.light));

    testWidgets(
      'the scan sheet offers the single scans and "Quét nhiều" / "Chọn nhiều ảnh"',
      (tester) async {
        await openMainScaffold(tester);
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        final sheet = find.byType(BottomSheet);
        for (final text in [
          'Quét bằng camera',
          'Chọn từ thư viện',
          'Quét nhiều',
          'Chọn nhiều ảnh',
        ]) {
          expect(
            find.descendant(of: sheet, matching: find.text(text)),
            findsOneWidget,
            reason: text,
          );
        }
        for (final icon in [
          Icons.burst_mode_rounded,
          Icons.collections_rounded,
        ]) {
          expect(
            find.descendant(of: sheet, matching: find.byIcon(icon)),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets('the queue is resumed and the strip is not below the tabs', (
      tester,
    ) async {
      await openMainScaffold(tester);

      expect(scanQueue.resumeCalls, 1);
      // The strip lives in the home band now (T9 C2), once, and nowhere under the tab bar.
      expect(find.byType(ScanQueueBanner), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DashboardPage),
          matching: find.byType(ScanQueueBanner),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'queueing receipts from another tab brings the home tab to the front',
      (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_imagePickerChannel, (call) async {
              return call.method == 'pickMultiImage'
                  ? ['/tmp/a.jpg', '/tmp/b.jpg']
                  : null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(_imagePickerChannel, null),
        );
        final colors = (await openMainScaffold(tester)).colorScheme;
        await tester.tap(_inBottomBar(find.text('Thống kê')));
        await tester.pumpAndSettle();
        expectSelectedTab(tester, colors, 1);

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chọn nhiều ảnh'));
        await tester.pumpAndSettle();

        expect(scanQueue.enqueued, [
          ['/tmp/a.jpg', '/tmp/b.jpg'],
        ]);
        expectSelectedTab(tester, colors, 0);
      },
    );

    testWidgets('nothing queued keeps the tab that was open', (tester) async {
      scanQueue.acceptedOf = (_) => 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_imagePickerChannel, (call) async {
            return call.method == 'pickMultiImage' ? ['/tmp/a.jpg'] : null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_imagePickerChannel, null),
      );
      final colors = (await openMainScaffold(tester)).colorScheme;
      await tester.tap(_inBottomBar(find.text('Thống kê')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn nhiều ảnh'));
      await tester.pumpAndSettle();

      expectSelectedTab(tester, colors, 1);
    });

    /// Picks two photos from the gallery for the queue, which then fails with [error], from the Ledger tab.
    Future<ColorScheme> pickManyWhileQueueFails(
      WidgetTester tester,
      Object error,
    ) async {
      scanQueue.enqueueError = error;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_imagePickerChannel, (call) async {
            return call.method == 'pickMultiImage'
                ? ['/tmp/a.jpg', '/tmp/b.jpg']
                : null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_imagePickerChannel, null),
      );
      final colors = (await openMainScaffold(tester)).colorScheme;
      await tester.tap(_inBottomBar(find.text('Thống kê')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn nhiều ảnh'));
      await tester.pumpAndSettle();
      return colors;
    }

    /// Lets the toast that the failure showed run out, so no timer is left when the test ends.
    Future<void> letToastGo(WidgetTester tester) async {
      await tester.pump(
        AppToast.displayDuration + AppToast.transitionDuration * 2,
      );
      await tester.pumpAndSettle();
    }

    for (final (name, error) in <(String, Object)>[
      ('a database error', _DiskFull()),
      ('a file error', const FileSystemException('copy failed', '/tmp/a.jpg')),
    ]) {
      testWidgets(
        '$name while queueing shows the storage toast and keeps the tab that was open',
        (tester) async {
          final colors = await pickManyWhileQueueFails(tester, error);

          expect(scanQueue.enqueued, [
            ['/tmp/a.jpg', '/tmp/b.jpg'],
          ]);
          expect(find.text(_storageFailedText), findsOneWidget);
          expect(find.textContaining('Đã thêm'), findsNothing);
          expectSelectedTab(tester, colors, 1);
          await letToastGo(tester);
        },
      );
    }

    testWidgets('a pick that ends after the screen is gone queues nothing', (
      tester,
    ) async {
      final picked = Completer<List<String>>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_imagePickerChannel, (call) async {
            return call.method == 'pickMultiImage' ? picked.future : null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_imagePickerChannel, null),
      );
      await openMainScaffold(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn nhiều ảnh'));
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      picked.complete(['/tmp/a.jpg']);
      await tester.pumpAndSettle();

      expect(scanQueue.enqueued, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed gallery pick shows the gallery error dialog', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_imagePickerChannel, (call) async {
            if (call.method == 'pickMultiImage') {
              throw PlatformException(code: 'photo_access_denied');
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_imagePickerChannel, null),
      );
      await openMainScaffold(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn nhiều ảnh'));
      await tester.pumpAndSettle();

      expect(find.text('Không mở được thư viện ảnh'), findsOneWidget);
      expect(scanQueue.enqueued, isEmpty);
    });
  });

  group('tab bar', () {
    setUp(() => signInWithSavedTheme(ThemeMode.light));

    testWidgets('tab labels are 12 and one line', (tester) async {
      await openMainScaffold(tester);

      for (final (label, _) in _tabs) {
        final text = tester.widget<Text>(_inBottomBar(find.text(label)));
        expect(text.maxLines, 1, reason: label);
        expect(text.softWrap, isFalse, reason: label);
        final style = tester
            .widget<RichText>(
              find.descendant(
                of: _inBottomBar(find.text(label)),
                matching: find.byType(RichText),
              ),
            )
            .text
            .style;
        expect(style?.fontSize, AppTextSize.caption, reason: label);
      }
    });
  });
}
