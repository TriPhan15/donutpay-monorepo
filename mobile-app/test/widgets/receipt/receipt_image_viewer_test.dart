import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_image_viewer.dart';

const String _localPhoto = '/tmp/does-not-exist/receipt.jpg';
const String _savedPhoto = 'https://res.cloudinary.com/demo/r1.jpg';

void main() {
  setUp(AppToast.resetForTest);

  Future<void> pump(WidgetTester tester, Widget page) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: page,
    ),
  );

  testWidgets('the viewer is black with Ảnh hóa đơn and one share button', (
    tester,
  ) async {
    await pump(tester, const ReceiptImageViewerPage(imagePath: _localPhoto));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.black);
    expect(find.text('Ảnh hóa đơn'), findsOneWidget);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.actions, hasLength(1));
    expect(find.byTooltip('Chia sẻ'), findsOneWidget);
  });

  testWidgets('pinch zoom stops at 5x', (tester) async {
    await pump(tester, const ReceiptImageViewerPage(imagePath: _localPhoto));

    expect(
      tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).maxScale,
      5,
    );
  });

  testWidgets('share on a local photo hands that file to the share sheet', (
    tester,
  ) async {
    final shared = <String>[];
    await pump(
      tester,
      ReceiptImageViewerPage(
        imagePath: _localPhoto,
        shareFile: (path) async => shared.add(path),
      ),
    );

    await tester.tap(find.byTooltip('Chia sẻ'));
    await tester.pumpAndSettle();

    expect(shared, [_localPhoto]);
  });

  testWidgets('share on a saved receipt downloads it first', (tester) async {
    final shared = <String>[];
    final downloads = <String>[];
    await pump(
      tester,
      ReceiptImageViewerPage.network(
        imageUrl: _savedPhoto,
        download: (url) async {
          downloads.add(url);
          return '/tmp/receipt_copy.jpg';
        },
        shareFile: (path) async => shared.add(path),
      ),
    );

    await tester.tap(find.byTooltip('Chia sẻ'));
    await tester.pumpAndSettle();

    expect(downloads, [_savedPhoto]);
    expect(shared, ['/tmp/receipt_copy.jpg']);
  });

  testWidgets('a failed download shows a toast and no share sheet', (
    tester,
  ) async {
    final shared = <String>[];
    await pump(
      tester,
      ReceiptImageViewerPage.network(
        imageUrl: _savedPhoto,
        download: (_) async => null,
        shareFile: (path) async => shared.add(path),
      ),
    );

    await tester.tap(find.byTooltip('Chia sẻ'));
    await tester.pumpAndSettle();

    expect(shared, isEmpty);
    expect(find.text('Không chia sẻ được ảnh'), findsOneWidget);
    await tester.pump(AppToast.displayDuration);
    await tester.pumpAndSettle();
  });
}
