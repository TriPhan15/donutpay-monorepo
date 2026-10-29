import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/screens/auth/forgot_password_page.dart';
import 'package:finance_ai_app/screens/auth/login_page.dart';
import 'package:finance_ai_app/screens/auth/register_page.dart';
import 'package:finance_ai_app/screens/auth/reset_password_page.dart';
import 'package:finance_ai_app/widgets/auth/auth_form_layout.dart';
import 'package:finance_ai_app/widgets/auth/auth_social_buttons.dart';
import 'package:finance_ai_app/widgets/auth/otp_input.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_settings_repository.dart';
import '../../helpers/theme_colors.dart';

/// Pumps [screen] as the app shows it, in [mode], and returns the theme it was built with.
Future<ThemeData> _show(
  WidgetTester tester,
  Widget screen,
  ThemeMode mode,
) async {
  // Tall and wide, because the test font is much wider than a real one.
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    withAppSettings(screen, settings: FakeSettingsRepository(themeMode: mode)),
  );
  await tester.pumpAndSettle();
  return Theme.of(tester.element(find.byWidget(screen)));
}

/// The gradient fills the page and the form lies on a surface card, with the soft shadow only in light mode.
void _expectAuthPage(WidgetTester tester, ThemeData theme) {
  final gradients = tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .map((decoration) => decoration.gradient)
      .whereType<LinearGradient>();
  expect(gradients.first, theme.semanticColors.headerGradient);
  final card =
      tester.widget<Container>(find.byKey(AuthFormLayout.cardKey)).decoration!
          as BoxDecoration;
  expect(card.color, theme.colorScheme.surface);
  expect(card.boxShadow, AppTheme.softShadowFor(theme.colorScheme));
}

/// The white "Question? Action" line under the card.
void _expectFooter(WidgetTester tester, String question, String action) {
  final footer =
      tester
              .widget<RichText>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is RichText &&
                      widget.text.toPlainText() == '$question$action',
                ),
              )
              .text
          as TextSpan;
  final spans = <TextSpan>[];
  footer.visitChildren((span) {
    if (span is TextSpan && span.text != null) spans.add(span);
    return true;
  });
  expect(
    spans.firstWhere((span) => span.text == question).style?.color,
    BandColors.secondary,
  );
  expect(
    spans.firstWhere((span) => span.text == action).style?.color,
    BandColors.primary,
  );
}

/// The Google and Facebook buttons: surface buttons whose brand icon stays at 3:1 or more on them.
void _expectSocialButtons(WidgetTester tester, ColorScheme colors) {
  for (final name in [AuthSocialButtons.google, AuthSocialButtons.facebook]) {
    expect(_buttonMaterial(tester, find.text(name)), colors.surface);
    expect(paintedColor(tester, find.text(name)), colors.onSurface);
  }
  for (final icon in [Icons.g_mobiledata_rounded, Icons.facebook]) {
    expect(
      contrastRatio(paintedColor(tester, find.byIcon(icon))!, colors.surface),
      greaterThanOrEqualTo(3),
      reason: 'the brand colour of $icon on its button',
    );
  }
}

/// The colour of the [Material] that draws the button around [label].
Color? _buttonMaterial(WidgetTester tester, Finder label) => tester
    .widget<Material>(
      find.ancestor(of: label, matching: find.byType(Material)).first,
    )
    .color;

void main() {
  // The language cubit of withAppSettings sets the default locale of intl.
  tearDown(() => Intl.defaultLocale = null);

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    group('${mode.name} theme', () {
      testWidgets(
        'LoginScreen: gradient page, brand head, card, fields, buttons and the white sign-up link',
        (tester) async {
          final theme = await _show(tester, const LoginScreen(), mode);
          final colors = theme.colorScheme;

          _expectAuthPage(tester, theme);
          expect(find.byKey(AuthFormLayout.backKey), findsNothing);
          expect(
            paintedColor(tester, find.text('LedgerMind')),
            BandColors.primary,
          );
          expect(
            paintedColor(tester, find.text('Quản lý tài chính thông minh')),
            BandColors.secondary,
          );
          expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
          expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
          await tester.enterText(
            find.byType(TextField).first,
            'an@example.com',
          );
          await tester.pump();
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText).first)
                .style
                .color,
            colors.onSurface,
          );
          expect(
            paintedColor(tester, find.text('Ghi nhớ đăng nhập')),
            colors.onSurfaceVariant,
          );
          expect(
            paintedColor(tester, find.text('Quên mật khẩu?')),
            colors.primary,
          );
          expect(
            materialColor(tester, find.byType(ElevatedButton)),
            colors.primary,
          );
          expect(
            paintedColor(tester, find.text('Đăng nhập')),
            colors.onPrimary,
          );
          expect(
            paintedColor(tester, find.text('Hoặc đăng nhập với')),
            colors.onSurfaceVariant,
          );
          _expectSocialButtons(tester, colors);
          _expectFooter(tester, 'Chưa có tài khoản? ', 'Đăng ký ngay');
        },
      );

      testWidgets(
        'RegisterScreen: gradient page, white title, card, rules, terms, social buttons and the sign-in link',
        (tester) async {
          final theme = await _show(tester, const RegisterScreen(), mode);
          final colors = theme.colorScheme;
          final semantic = theme.semanticColors;

          _expectAuthPage(tester, theme);
          expect(
            paintedColor(tester, find.text('Tạo tài khoản').first),
            BandColors.primary,
            reason: 'the title on the gradient',
          );
          expect(
            paintedColor(
              tester,
              find.text('Điền thông tin để bắt đầu quản lý tài chính.'),
            ),
            BandColors.secondary,
          );
          final terms =
              tester
                      .widget<Text>(
                        find.text(
                          'Bằng việc đăng ký, bạn đồng ý với Điều khoản và Điều kiện sử dụng',
                        ),
                      )
                      .textSpan!
                  as TextSpan;
          expect(terms.style?.color, colors.onSurfaceVariant);
          for (final link in terms.children!.whereType<TextSpan>().where(
            (span) => span.text != ' và ',
          )) {
            expect(link.style?.color, colors.primary, reason: link.text);
          }
          expect(
            _buttonMaterial(
              tester,
              find.descendant(
                of: find.byType(ElevatedButton),
                matching: find.text('Tạo tài khoản'),
              ),
            ),
            colors.primary,
          );
          _expectSocialButtons(tester, colors);
          _expectFooter(tester, 'Đã có tài khoản? ', 'Đăng nhập');

          // The rules show before the password is touched; "Abc" meets upper and lower case only.
          expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(5));
          await tester.enterText(find.byType(TextField).at(3), 'Abc');
          await tester.pumpAndSettle();

          expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
          for (final icon in tester.widgetList<Icon>(
            find.byIcon(Icons.check_circle),
          )) {
            expect(icon.color, semantic.successColor);
          }
          for (final icon in tester.widgetList<Icon>(
            find.byIcon(Icons.radio_button_unchecked),
          )) {
            expect(icon.color, colors.onSurfaceVariant);
          }
          expect(
            paintedColor(tester, find.text('Chữ viết hoa (A-Z)')),
            semantic.successColor,
          );
          expect(
            paintedColor(tester, find.text('Chữ số (0-9)')),
            colors.onSurfaceVariant,
          );
        },
      );

      testWidgets(
        'ForgotPasswordScreen: gradient page, white title and description, card, field, error and the sign-in link',
        (tester) async {
          final theme = await _show(tester, const ForgotPasswordScreen(), mode);
          final colors = theme.colorScheme;

          _expectAuthPage(tester, theme);
          expect(
            paintedColor(tester, find.text('Quên mật khẩu')),
            BandColors.primary,
          );
          expect(
            paintedColor(
              tester,
              find.text(
                'Nhập email tài khoản của bạn. Chúng tôi sẽ gửi mã OTP để bạn đặt mật khẩu mới.',
              ),
            ),
            BandColors.secondary,
          );
          expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
          expect(
            materialColor(tester, find.byType(ElevatedButton)),
            colors.primary,
          );
          expect(
            paintedColor(tester, find.text('Gửi mã OTP')),
            colors.onPrimary,
          );
          _expectFooter(tester, 'Nhớ ra rồi? ', 'Đăng nhập');

          // Sending with no email shows the error under the field in the error colour.
          await tester.tap(find.byType(ElevatedButton));
          await tester.pumpAndSettle();
          expect(
            paintedColor(tester, find.text('Vui lòng nhập email.')),
            colors.error,
          );
        },
      );

      testWidgets(
        'ResetPasswordScreen: gradient page, white title, OTP boxes, rules, eye buttons, resend and reset buttons',
        (tester) async {
          final theme = await _show(
            tester,
            const ResetPasswordScreen(email: 'an@example.com'),
            mode,
          );
          final colors = theme.colorScheme;

          _expectAuthPage(tester, theme);
          expect(
            paintedColor(tester, find.text('Đặt lại mật khẩu').first),
            BandColors.primary,
            reason: 'the title on the gradient',
          );
          expect(
            paintedColor(
              tester,
              find.text(
                'Nhập mã OTP đã được gửi tới a***@example.com, sau đó đặt mật khẩu mới.',
              ),
            ),
            BandColors.secondary,
          );
          for (var i = 0; i < ResetPasswordScreen.otpLength; i++) {
            final box =
                tester
                        .widget<Container>(
                          find.descendant(
                            of: find.byKey(OtpInput.boxKey(i)),
                            matching: find.byType(Container),
                          ),
                        )
                        .decoration!
                    as BoxDecoration;
            expect(box.color, colors.surface);
            expect((box.border! as Border).top.color, colors.outlineVariant);
          }
          expect(
            paintedColor(
              tester,
              find.text(
                'Từ 8 đến 72 ký tự, gồm ít nhất một chữ cái và một chữ số.',
              ),
            ),
            colors.onSurfaceVariant,
            reason: 'the password rules under the field',
          );
          for (final eye in tester.widgetList<Icon>(
            find.byIcon(Icons.visibility_off_outlined),
          )) {
            expect(eye.color, colors.onSurfaceVariant);
          }
          expect(
            materialColor(tester, find.byType(ElevatedButton)),
            colors.primary,
          );
          expect(
            paintedColor(
              tester,
              find.descendant(
                of: find.byType(ElevatedButton),
                matching: find.text('Đặt lại mật khẩu'),
              ),
            ),
            colors.onPrimary,
          );
          // Once the countdown is over, "resend" takes the primary colour of the theme; the Material of a button fades
          // its label colour, so the fade has to end before the colour is read.
          await tester.pump(ResetPasswordScreen.resendCooldown);
          await tester.pumpAndSettle();
          expect(
            paintedColor(tester, find.text('Gửi lại mã OTP')),
            colors.primary,
          );
        },
      );
    });
  }
}
