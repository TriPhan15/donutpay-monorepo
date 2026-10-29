import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';

import '../../helpers/theme_colors.dart';

void main() {
  Future<ColorScheme> pump(
    WidgetTester tester,
    Widget child, {
    ThemeMode mode = ThemeMode.light,
    Locale locale = const Locale('vi'),
  }) async {
    late ColorScheme colors;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              colors = Theme.of(context).colorScheme;
              return child;
            },
          ),
        ),
      ),
    );
    return colors;
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mode.name}: loading is a small grey spinner', (
      tester,
    ) async {
      final colors = await pump(
        tester,
        const AppStateView.loading(),
        mode: mode,
      );

      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.strokeWidth, 2.5);
      expect(spinner.color, colors.onSurfaceVariant);
      expect(
        tester.getSize(find.byType(CircularProgressIndicator)),
        const Size.square(AppStateView.spinnerSize),
      );
    });

    testWidgets(
      '${mode.name}: empty shows a grey icon, a 16 title, a 13 message and a primary text button',
      (tester) async {
        var taps = 0;
        final colors = await pump(
          tester,
          AppStateView.empty(
            icon: Icons.receipt_long_rounded,
            title: 'Chưa có giao dịch',
            message: 'Giao dịch bạn ghi sẽ hiện ở đây.',
            actionLabel: 'Thêm giao dịch',
            onAction: () => taps++,
          ),
          mode: mode,
        );

        final icon = tester.widget<Icon>(
          find.byIcon(Icons.receipt_long_rounded),
        );
        expect(icon.size, AppStateView.iconSize);
        expect(icon.color, colors.onSurfaceVariant);
        final title = tester.widget<Text>(find.text('Chưa có giao dịch'));
        expect(title.style!.fontSize, AppTextSize.title);
        expect(title.style!.fontWeight, FontWeight.w700);
        final message = tester.widget<Text>(
          find.text('Giao dịch bạn ghi sẽ hiện ở đây.'),
        );
        expect(message.style!.fontSize, AppTextSize.secondary);
        expect(message.style!.color, colors.onSurfaceVariant);
        expect(message.textAlign, TextAlign.center);
        expect(
          find.widgetWithText(TextButton, 'Thêm giao dịch'),
          findsOneWidget,
        );
        expect(
          paintedColor(tester, find.text('Thêm giao dịch')),
          colors.primary,
        );

        await tester.tap(find.text('Thêm giao dịch'));
        expect(taps, 1);
      },
    );
  }

  testWidgets('empty without an action has no button', (tester) async {
    await pump(
      tester,
      const AppStateView.empty(icon: Icons.inbox_rounded, title: 'Trống'),
    );

    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('error offers Thử lại', (tester) async {
    var retries = 0;
    await pump(
      tester,
      AppStateView.error(
        title: 'Không tải được',
        message: 'Kiểm tra mạng rồi thử lại.',
        onRetry: () => retries++,
      ),
    );

    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Thử lại'));
    expect(retries, 1);
  });

  testWidgets('error speaks English', (tester) async {
    await pump(
      tester,
      AppStateView.error(title: 'Could not load', onRetry: () {}),
      locale: const Locale('en'),
    );

    expect(find.widgetWithText(TextButton, 'Try again'), findsOneWidget);
  });

  testWidgets('works inside a ListView', (tester) async {
    await pump(
      tester,
      ListView(
        children: const [
          AppStateView.empty(icon: Icons.inbox_rounded, title: 'Trống'),
          AppStateView.loading(),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Trống'), findsOneWidget);
  });
}
