import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/models/wallet_model.dart';
import 'package:finance_ai_app/widgets/dialogs/profile_bottom_sheets.dart';

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
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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

Color? _dialogColor(WidgetTester tester) =>
    materialColor(tester, find.byType(AlertDialog));

/// The decoration a text field is drawn with, once the theme's inputDecorationTheme is applied.
InputDecoration _fieldDecoration(WidgetTester tester, Finder field) => tester
    .widget<InputDecorator>(
      find.descendant(of: field, matching: find.byType(InputDecorator)),
    )
    .decoration;

final List<TransactionModel> _transactions = [
  TransactionModel(
    id: '1',
    title: 'Cà phê',
    amount: 45000,
    date: DateTime(2026, 9, 20, 8, 30),
    category: 'Ăn uống',
    isExpense: true,
  ),
  TransactionModel(
    id: '2',
    title: 'Lương',
    amount: 10000000,
    date: DateTime(2026, 9, 1, 9, 0),
    category: 'Lương',
    isExpense: false,
  ),
];

const _wallet = WalletModel(id: 1, name: 'Ví chính', balance: 1500000);

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    group('${mode.name} theme', () {
      testWidgets(
        'notification settings: surface sheet, row titles and the save button follow the theme',
        (tester) async {
          final host = await _host(tester, mode);
          final colors = Theme.of(host).colorScheme;

          ProfileBottomSheets.showNotificationSettings(host);
          await tester.pumpAndSettle();

          expect(_sheetColor(tester), colors.surface);
          expect(
            paintedColor(tester, find.text('Cài đặt thông báo')),
            colors.onSurface,
          );
          expect(
            paintedColor(tester, find.text('Thông báo đẩy')),
            colors.onSurface,
          );
          final save = find.widgetWithText(ElevatedButton, 'Lưu');
          expect(materialColor(tester, save), colors.primary);
          expect(paintedColor(tester, find.text('Lưu')), colors.onPrimary);
        },
      );

      testWidgets('money sources: wallet name and balance follow the theme', (
        tester,
      ) async {
        final host = await _host(tester, mode);
        final colors = Theme.of(host).colorScheme;

        ProfileBottomSheets.showBankSources(host, const [_wallet]);
        await tester.pumpAndSettle();

        expect(_sheetColor(tester), colors.surface);
        expect(paintedColor(tester, find.text('Nguồn tiền')), colors.onSurface);
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

          ProfileBottomSheets.showBankSources(host, const []);
          await tester.pumpAndSettle();

          expect(
            paintedColor(tester, find.text('Chưa có ví nào.')),
            colors.onSurfaceVariant,
          );
        },
      );

      testWidgets(
        'activity log: titles, dates and the expense and income amounts follow the theme',
        (tester) async {
          final host = await _host(tester, mode);
          final theme = Theme.of(host);
          final colors = theme.colorScheme;

          ProfileBottomSheets.showActivityLog(host, _transactions);
          await tester.pumpAndSettle();

          expect(_sheetColor(tester), colors.surface);
          expect(
            paintedColor(tester, find.text('Lịch sử hoạt động (2)')),
            colors.onSurface,
          );
          expect(paintedColor(tester, find.text('Cà phê')), colors.onSurface);
          expect(
            paintedColor(tester, find.text('20/09/2026 08:30')),
            colors.onSurfaceVariant,
          );
          expect(
            paintedColor(tester, find.textContaining('45.000')),
            theme.extension<SemanticColors>()!.expenseColor,
          );
          expect(
            paintedColor(tester, find.textContaining('10.000.000')),
            colors.primary,
          );
          // The transaction icons keep the colours of the model, readable on both surfaces.
          final expenseIcon = paintedColor(
            tester,
            find.byIcon(Icons.money_off),
          )!;
          expect(expenseIcon, _transactions.first.color);
          expect(
            contrastRatio(expenseIcon, colors.surface),
            greaterThanOrEqualTo(3),
          );
        },
      );

      testWidgets(
        'security menu: primary-container tile, subtitle and chevron follow the theme',
        (tester) async {
          final host = await _host(tester, mode);
          final colors = Theme.of(host).colorScheme;

          ProfileBottomSheets.showSecurityMenu(host, _transactions);
          await tester.pumpAndSettle();

          expect(_sheetColor(tester), colors.surface);
          expect(
            paintedColor(tester, find.text('Bảo mật & Quyền riêng tư')),
            colors.onSurface,
          );
          expect(
            boxColor(tester, find.byIcon(Icons.history_rounded)),
            colors.primaryContainer,
          );
          expect(
            paintedColor(tester, find.byIcon(Icons.history_rounded)),
            colors.onPrimaryContainer,
          );
          expect(
            paintedColor(tester, find.text('Lịch sử hoạt động')),
            colors.onSurface,
          );
          expect(
            paintedColor(tester, find.text('Xem các giao dịch gần đây')),
            colors.onSurfaceVariant,
          );
          expect(
            paintedColor(tester, find.byIcon(Icons.chevron_right_rounded)),
            colors.onSurfaceVariant.withValues(alpha: 0.5),
          );
        },
      );

      testWidgets(
        'help: topics in the primary colour, text in the secondary one',
        (tester) async {
          final host = await _host(tester, mode);
          final colors = Theme.of(host).colorScheme;

          ProfileBottomSheets.showHelp(host);
          await tester.pumpAndSettle();

          expect(_sheetColor(tester), colors.surface);
          expect(
            paintedColor(tester, find.text('Hướng dẫn sử dụng')),
            colors.onSurface,
          );
          expect(
            paintedColor(tester, find.text('📊 Dashboard')),
            colors.primary,
          );
          expect(
            paintedColor(
              tester,
              find.text(
                'Xem tổng quan tài sản, thu chi tháng và biểu đồ dòng tiền.',
              ),
            ),
            colors.onSurfaceVariant,
          );
        },
      );

      testWidgets(
        'feedback dialog: surface dialog, secondary texts, themed field and the send button',
        (tester) async {
          final host = await _host(tester, mode);
          final colors = Theme.of(host).colorScheme;

          ProfileBottomSheets.showFeedback(host);
          await tester.pumpAndSettle();

          expect(_dialogColor(tester), colors.surface);
          expect(
            paintedColor(tester, find.text('Đánh giá ứng dụng ⭐')),
            colors.onSurface,
          );
          expect(
            paintedColor(
              tester,
              find.text(
                'Ý kiến của bạn sẽ giúp hệ thống ngày càng hoàn thiện hơn!',
              ),
            ),
            colors.onSurfaceVariant,
          );
          expect(
            paintedColor(tester, find.text('Nhập cảm nhận hoặc góp ý...')),
            colors.onSurfaceVariant,
          );
          expect(
            _fieldDecoration(tester, find.byType(TextField)).fillColor,
            colors.surface,
          );
          expect(
            paintedColor(tester, find.text('Để sau')),
            colors.onSurfaceVariant,
          );
          final send = find.widgetWithText(ElevatedButton, 'Gửi ngay');
          expect(materialColor(tester, send), colors.primary);
          expect(paintedColor(tester, find.text('Gửi ngay')), colors.onPrimary);
        },
      );
    });
  }

  testWidgets(
    'light mode keeps the colours the sheets and dialogs had before',
    (tester) async {
      final host = await _host(tester, ThemeMode.light);

      ProfileBottomSheets.showActivityLog(host, _transactions);
      await tester.pumpAndSettle();
      expect(_sheetColor(tester), AppTheme.navyLight);
      expect(paintedColor(tester, find.text('Cà phê')), AppTheme.textWhite);
      expect(
        paintedColor(tester, find.text('20/09/2026 08:30')),
        AppTheme.textGray,
      );
      expect(
        paintedColor(tester, find.textContaining('45.000')),
        AppTheme.dangerColor,
      );
      expect(
        paintedColor(tester, find.textContaining('10.000.000')),
        AppTheme.mintAccent,
      );
      Navigator.pop(host);
      await tester.pumpAndSettle();

      ProfileBottomSheets.showSecurityMenu(host, _transactions);
      await tester.pumpAndSettle();
      expect(
        paintedColor(tester, find.byIcon(Icons.history_rounded)),
        AppTheme.primaryDark,
        reason: 'content on the pale primary tile is the deep primary (T9)',
      );
      expect(
        boxColor(tester, find.byIcon(Icons.history_rounded)),
        AppTheme.mintLight,
        reason: 'the tile is now the primary container (was primary at 12%)',
      );
    },
  );

  // T10d: the PIN was stored and never checked, so the entry is gone with its dialog.
  testWidgets('security menu no longer offers to create or change a PIN', (
    tester,
  ) async {
    final host = await _host(tester, ThemeMode.light);

    ProfileBottomSheets.showSecurityMenu(host, _transactions);
    await tester.pumpAndSettle();

    expect(find.text('Lịch sử hoạt động'), findsOneWidget);
    expect(find.text('Tạo / Đổi mã PIN'), findsNothing);
    expect(find.byIcon(Icons.pin_rounded), findsNothing);
    expect(find.byType(ListTile), findsOneWidget);
  });
}
