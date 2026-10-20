import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/models/wallet_model.dart';
import 'package:finance_ai_app/widgets/dialogs/dashboard_bottom_sheets.dart';

import '../../helpers/theme_colors.dart';

/// Pumps an empty page under the app themes in [mode] and returns a context the sheets can be opened from.
Future<BuildContext> _host(WidgetTester tester, ThemeMode mode) async {
  // Tall, so that a scrollable sheet builds every row.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  late BuildContext host;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            host = context;
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  return host;
}

Color? _sheetColor(WidgetTester tester) =>
    materialColor(tester, find.byType(BottomSheet));

const _wallet = WalletModel(id: 1, name: 'Ví chính', balance: 1500000);

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    group('${mode.name} theme', () {
      testWidgets('money sources: texts and balance follow the theme', (
        tester,
      ) async {
        final host = await _host(tester, mode);
        final colors = Theme.of(host).colorScheme;

        DashboardBottomSheets.showBankSources(host, const [_wallet]);
        await tester.pumpAndSettle();

        expect(_sheetColor(tester), colors.surface);
        expect(paintedColor(tester, find.text('Nguồn tiền')), colors.onSurface);
        expect(
          paintedColor(tester, find.text('Các ví đã liên kết với tài khoản')),
          colors.onSurfaceVariant,
        );
        expect(paintedColor(tester, find.text('Ví chính')), colors.onSurface);
        expect(
          paintedColor(tester, find.textContaining('1.500.000')),
          colors.primary,
        );
      });

      testWidgets(
        'money sources without a wallet say so in the secondary colour',
        (tester) async {
          final host = await _host(tester, mode);
          final colors = Theme.of(host).colorScheme;

          DashboardBottomSheets.showBankSources(host, const []);
          await tester.pumpAndSettle();

          expect(
            paintedColor(tester, find.text('Chưa có ví nào.')),
            colors.onSurfaceVariant,
          );
        },
      );

      testWidgets(
        'all features: primary-container tiles, labels and descriptions follow the theme',
        (tester) async {
          final host = await _host(tester, mode);
          final colors = Theme.of(host).colorScheme;

          DashboardBottomSheets.showAllFeatures(
            host,
            onSavings: () {},
            onBankSources: () {},
            onLinkedServices: () {},
          );
          await tester.pumpAndSettle();

          expect(_sheetColor(tester), colors.surface);
          expect(
            paintedColor(tester, find.text('Tất cả tính năng')),
            colors.onSurface,
          );
          for (final icon in [
            Icons.savings_rounded,
            Icons.account_balance_wallet_rounded,
            Icons.link_rounded,
          ]) {
            expect(
              boxColor(tester, find.byIcon(icon)),
              colors.primaryContainer,
            );
            expect(
              paintedColor(tester, find.byIcon(icon)),
              colors.onPrimaryContainer,
            );
          }
          expect(
            paintedColor(tester, find.text('Sổ tiết kiệm')),
            colors.onSurface,
          );
          expect(
            paintedColor(tester, find.text('Quản lý mục tiêu tiết kiệm')),
            colors.onSurfaceVariant,
          );
        },
      );
    });
  }

  testWidgets('light mode keeps the colours the sheets had before', (
    tester,
  ) async {
    final host = await _host(tester, ThemeMode.light);

    DashboardBottomSheets.showBankSources(host, const [_wallet]);
    await tester.pumpAndSettle();
    expect(_sheetColor(tester), AppTheme.navyLight);
    expect(
      paintedColor(tester, find.textContaining('1.500.000')),
      AppTheme.mintAccent,
    );
    Navigator.pop(host);
    await tester.pumpAndSettle();

    DashboardBottomSheets.showAllFeatures(
      host,
      onSavings: () {},
      onBankSources: () {},
      onLinkedServices: () {},
    );
    await tester.pumpAndSettle();
    expect(
      paintedColor(tester, find.byIcon(Icons.savings_rounded)),
      AppTheme.primary,
    );
    expect(
      boxColor(tester, find.byIcon(Icons.savings_rounded)),
      AppTheme.mintLight,
      reason: 'the tile is now the primary container (was primary at 12%)',
    );
  });
}
