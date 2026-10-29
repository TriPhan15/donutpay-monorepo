import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/screens/receipt_scanner/pending_receipts_screen.dart';
import 'package:finance_ai_app/services/receipt_scan_queue.dart';
import 'package:finance_ai_app/widgets/receipt/scan_queue_banner.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_scan_queue.dart';
import '../../helpers/fake_settings_repository.dart';

void main() {
  final scanQueue = FakeScanQueue();

  setUpAll(() => ReceiptScanQueue.instanceForTesting = scanQueue);
  setUp(scanQueue.reset);

  Finder inBanner(Finder finder) =>
      find.descendant(of: find.byType(ScanQueueBanner), matching: finder);

  Future<void> showBanner(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
    double width = 400,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        settings: FakeSettingsRepository(themeMode: mode),
        MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: ScanQueueBanner(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color? textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(inBanner(find.text(text))).style?.color;

  ThemeData themeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(ScanQueueBanner)));

  testWidgets('takes no room while the queue is empty', (tester) async {
    await showBanner(tester);

    expect(tester.getSize(find.byType(ScanQueueBanner)), Size.zero);
    expect(inBanner(find.byType(InkWell)), findsNothing);
    expect(inBanner(find.byType(LinearProgressIndicator)), findsNothing);
  });

  testWidgets(
    'shows the receipt being read, then how many wait, and opens the pending list',
    (tester) async {
      await showBanner(tester);

      scanQueue.progressNotifier.value = const ScanQueueProgress(total: 3);
      await tester.pump();
      expect(inBanner(find.text('Đang đọc hóa đơn 1/3')), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              inBanner(find.byType(LinearProgressIndicator)),
            )
            .value,
        0,
      );

      scanQueue.progressNotifier.value = const ScanQueueProgress(
        done: 1,
        total: 3,
        ready: 1,
      );
      await tester.pump();
      expect(inBanner(find.text('Đang đọc hóa đơn 2/3')), findsOneWidget);

      scanQueue.progressNotifier.value = const ScanQueueProgress(ready: 2);
      await tester.pump();
      expect(inBanner(find.text('2 hóa đơn chờ xác nhận')), findsOneWidget);
      expect(inBanner(find.byType(LinearProgressIndicator)), findsNothing);

      await tester.tap(inBanner(find.text('2 hóa đơn chờ xác nhận')));
      await tester.pumpAndSettle();
      expect(find.byType(PendingReceiptsScreen), findsOneWidget);
    },
  );

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      '${mode.name}: one line on a solid surface, 40 high, with a 3 px bar at its bottom while reading',
      (tester) async {
        await showBanner(tester, mode: mode);
        scanQueue.progressNotifier.value = const ScanQueueProgress(
          done: 1,
          total: 3,
        );
        await tester.pump();

        final label = tester.widget<Text>(
          inBanner(find.text('Đang đọc hóa đơn 2/3')),
        );
        expect(label.maxLines, 1);
        expect(label.overflow, TextOverflow.ellipsis);
        expect(
          tester.widget<Material>(inBanner(find.byType(Material)).first).color,
          themeOf(tester).colorScheme.surface,
        );

        final strip = tester.getRect(inBanner(find.byType(Material)).first);
        expect(strip.height, 40);
        final bar = inBanner(find.byType(LinearProgressIndicator));
        expect(tester.widget<LinearProgressIndicator>(bar).minHeight, 3);
        expect(tester.getRect(bar).bottom, strip.bottom);
        expect(tester.getRect(bar).height, 3);
      },
    );

    testWidgets(
      '${mode.name}: reading is primary-dark, waiting is green, only failed is red',
      (tester) async {
        await showBanner(tester, mode: mode);
        final theme = themeOf(tester);
        final scheme = theme.colorScheme;

        scanQueue.progressNotifier.value = const ScanQueueProgress(total: 2);
        await tester.pump();
        expect(
          textColor(tester, 'Đang đọc hóa đơn 1/2'),
          mode == ThemeMode.light ? scheme.onPrimaryContainer : scheme.primary,
        );

        scanQueue.progressNotifier.value = const ScanQueueProgress(ready: 1);
        await tester.pump();
        expect(
          textColor(tester, '1 hóa đơn chờ xác nhận'),
          theme.semanticColors.successColor,
        );

        scanQueue.progressNotifier.value = const ScanQueueProgress(failed: 1);
        await tester.pump();
        expect(textColor(tester, '1 hóa đơn đọc lỗi'), scheme.error);
      },
    );
  }

  testWidgets('a long label at 320 px and text scale 1.3 does not overflow', (
    tester,
  ) async {
    await showBanner(tester, width: 320, textScale: 1.3);
    scanQueue.progressNotifier.value = const ScanQueueProgress(
      done: 8,
      total: 10,
      ready: 8,
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(inBanner(find.text('Đang đọc hóa đơn 9/10')), findsOneWidget);
  });
}
