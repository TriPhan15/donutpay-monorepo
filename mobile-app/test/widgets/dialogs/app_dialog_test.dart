import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';

import '../../helpers/theme_colors.dart';

/// Pumps an empty page under the app themes in [mode] and returns a context the dialogs can be opened from.
Future<BuildContext> _host(
  WidgetTester tester,
  ThemeMode mode, {
  Locale? locale,
}) async {
  late BuildContext host;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      locale: locale,
      localizationsDelegates: locale == null
          ? null
          : AppLocalizations.localizationsDelegates,
      supportedLocales: locale == null
          ? const [Locale('en', 'US')]
          : AppLocalizations.supportedLocales,
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

/// One kind of message dialog: how to open it, its icon, its default button and its accent in a theme.
typedef _Kind = ({
  String name,
  void Function(BuildContext context) open,
  IconData icon,
  String button,
  Color Function(ThemeData theme) accent,
});

final List<_Kind> _kinds = [
  (
    name: 'success',
    open: (context) =>
        AppDialog.success(context, title: 'Tiêu đề', message: 'Nội dung'),
    icon: Icons.check_circle_rounded,
    button: 'Xong',
    accent: (theme) => theme.extension<SemanticColors>()!.successColor,
  ),
  (
    name: 'error',
    open: (context) =>
        AppDialog.error(context, title: 'Tiêu đề', message: 'Nội dung'),
    icon: Icons.error_rounded,
    button: 'Đã hiểu',
    accent: (theme) => theme.colorScheme.error,
  ),
  (
    name: 'warning',
    open: (context) =>
        AppDialog.warning(context, title: 'Tiêu đề', message: 'Nội dung'),
    icon: Icons.warning_amber_rounded,
    button: 'Đã hiểu',
    accent: (theme) => theme.extension<SemanticColors>()!.warningColor,
  ),
  (
    name: 'info',
    open: (context) =>
        AppDialog.info(context, title: 'Tiêu đề', message: 'Nội dung'),
    icon: Icons.info_rounded,
    button: 'Đã hiểu',
    accent: (theme) => theme.colorScheme.primary,
  ),
];

Text _text(WidgetTester tester, String data) =>
    tester.widget<Text>(find.text(data));

/// The weight [data] is painted with: a button label takes it from the button's text style, not from its Text.
FontWeight? _paintedWeight(WidgetTester tester, String data) => tester
    .widget<RichText>(
      find
          .descendant(of: find.text(data), matching: find.byType(RichText))
          .first,
    )
    .text
    .style
    ?.fontWeight;

/// The label of the text button that shows [label] inside the open dialog.
Finder _textButton(String label) => find.widgetWithText(TextButton, label);

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      '${mode.name}: success, error, warning and info show a 72 ring, an 18 title, a centred message and one wide button',
      (tester) async {
        final host = await _host(tester, mode);
        final theme = Theme.of(host);
        final colors = theme.colorScheme;

        for (final kind in _kinds) {
          kind.open(host);
          await tester.pumpAndSettle();
          final accent = kind.accent(theme);

          expect(
            materialColor(tester, find.byType(Dialog)),
            colors.surface,
            reason: kind.name,
          );
          final title = _text(tester, 'Tiêu đề');
          expect(title.style!.fontSize, AppTextSize.pageTitle);
          expect(title.style!.fontWeight, FontWeight.w700);
          expect(paintedColor(tester, find.text('Tiêu đề')), colors.onSurface);
          final message = _text(tester, 'Nội dung');
          expect(message.textAlign, TextAlign.center);
          expect(message.style!.height, 1.55);
          expect(message.style!.fontSize, AppTextSize.body);
          expect(
            paintedColor(tester, find.text('Nội dung')),
            colors.onSurfaceVariant,
          );

          expect(paintedColor(tester, find.byIcon(kind.icon)), accent);
          final ring = find
              .ancestor(
                of: find.byIcon(kind.icon),
                matching: find.byType(Container),
              )
              .first;
          expect(tester.getSize(ring), const Size(72, 72), reason: kind.name);
          expect(
            boxColor(tester, find.byIcon(kind.icon)),
            accent.withValues(alpha: 0.12),
          );

          final buttons = find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(ElevatedButton),
          );
          expect(buttons, findsOneWidget, reason: kind.name);
          expect(find.text(kind.button), findsOneWidget, reason: kind.name);
          expect(materialColor(tester, buttons), accent);
          final label = paintedColor(tester, find.text(kind.button))!;
          expect(
            contrastRatio(label, accent),
            greaterThanOrEqualTo(mode == ThemeMode.light ? 3 : 4.5),
            reason: '${kind.name} button label',
          );
          // One wide button: as wide as the message column.
          expect(
            tester.getSize(buttons).width,
            tester
                .getSize(
                  find
                      .ancestor(
                        of: find.text('Tiêu đề'),
                        matching: find.byType(Column),
                      )
                      .first,
                )
                .width,
          );

          await tester.tap(buttons);
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
        }
      },
    );

    testWidgets(
      '${mode.name} confirm: no icon, a centred 14/1.55 message and two text buttons split by a divider',
      (tester) async {
        final host = await _host(tester, mode);
        final colors = Theme.of(host).colorScheme;

        final accepted = AppDialog.confirm(
          host,
          title: 'Xóa giao dịch?',
          message: 'Không thể hoàn tác.',
          confirmText: 'Xóa',
          danger: true,
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(of: find.byType(Dialog), matching: find.byType(Icon)),
          findsNothing,
        );
        final title = _text(tester, 'Xóa giao dịch?');
        expect(title.style!.fontSize, AppTextSize.title);
        expect(title.style!.fontWeight, FontWeight.w700);
        expect(title.textAlign, TextAlign.center);
        final message = _text(tester, 'Không thể hoàn tác.');
        expect(message.textAlign, TextAlign.center);
        expect(message.style!.height, 1.55);
        expect(message.style!.fontSize, AppTextSize.body);
        expect(
          paintedColor(tester, find.text('Không thể hoàn tác.')),
          colors.onSurfaceVariant,
        );

        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(TextButton),
          ),
          findsNWidgets(2),
        );
        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(ElevatedButton),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(VerticalDivider),
          ),
          findsOneWidget,
        );

        // A danger action is painted in the error colour, bold; Cancel in the primary colour.
        expect(paintedColor(tester, find.text('Hủy')), colors.primary);
        expect(paintedColor(tester, find.text('Xóa')), colors.error);
        expect(_paintedWeight(tester, 'Xóa'), FontWeight.w700);

        await tester.tap(_textButton('Xóa'));
        await tester.pumpAndSettle();
        expect(await accepted, isTrue);

        final declined = AppDialog.confirm(host, title: 'Đăng xuất?');
        await tester.pumpAndSettle();
        expect(paintedColor(tester, find.text('Đồng ý')), colors.primary);
        expect(_paintedWeight(tester, 'Đồng ý'), FontWeight.w700);
        await tester.tap(_textButton('Hủy'));
        await tester.pumpAndSettle();
        expect(await declined, isFalse);
        expect(find.byType(Dialog), findsNothing);
      },
    );
  }

  testWidgets('a confirm dialog cannot be dismissed by a tap outside', (
    tester,
  ) async {
    final host = await _host(tester, ThemeMode.light);
    AppDialog.confirm(host, title: 'Xóa?');
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('choose returns null when dismissed by a tap outside', (
    tester,
  ) async {
    final host = await _host(tester, ThemeMode.light);
    final answer = AppDialog.choose(
      host,
      title: 'Gửi lại?',
      confirmText: 'Gửi',
      cancelText: 'Để sau',
    );
    await tester.pumpAndSettle();
    expect(_textButton('Gửi'), findsOneWidget);
    expect(_textButton('Để sau'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(await answer, isNull);
  });

  testWidgets('default buttons speak English: Done and Got it', (tester) async {
    final host = await _host(
      tester,
      ThemeMode.light,
      locale: const Locale('en'),
    );

    AppDialog.success(host, title: 'Saved');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, 'Done'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    AppDialog.info(host, title: 'Note');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, 'Got it'), findsOneWidget);
  });
}
