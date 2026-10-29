import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/screens/startup/startup_splash_screen.dart';
import 'package:finance_ai_app/widgets/auth/auth_form_layout.dart';
import 'package:finance_ai_app/widgets/auth/auth_social_buttons.dart';
import 'package:finance_ai_app/widgets/auth/auth_text_field.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_settings_repository.dart';
import '../../helpers/theme_colors.dart';

/// Shows [page] pushed over a plain page, so that it has somewhere to go back to.
Future<void> _pushed(
  WidgetTester tester,
  Widget page, {
  ThemeMode mode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    withAppSettings(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => page),
            ),
            child: const Text('open'),
          ),
        ),
      ),
      settings: FakeSettingsRepository(themeMode: mode),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The gradient that fills the whole auth page.
LinearGradient? _pageGradient(WidgetTester tester) {
  final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
  for (final box in boxes) {
    final decoration = box.decoration;
    if (decoration is BoxDecoration && decoration.gradient != null) {
      return decoration.gradient as LinearGradient;
    }
  }
  return null;
}

void main() {
  tearDown(() => Intl.defaultLocale = null);

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      '${mode.name}: the form layout fills the page with the gradient and puts the form on a card',
      (tester) async {
        await _pushed(
          tester,
          const AuthFormLayout(
            title: 'Quên mật khẩu',
            description: 'Nhập email',
            child: Text('form'),
          ),
          mode: mode,
        );

        final context = tester.element(find.text('form'));
        final colors = Theme.of(context).colorScheme;
        expect(_pageGradient(tester), context.colors.headerGradient);
        expect(
          paintedColor(tester, find.text('Quên mật khẩu')),
          BandColors.primary,
        );
        expect(
          paintedColor(tester, find.text('Nhập email')),
          BandColors.secondary,
        );
        final card =
            tester
                    .widget<Container>(find.byKey(AuthFormLayout.cardKey))
                    .decoration!
                as BoxDecoration;
        expect(card.color, colors.surface);
        expect(card.boxShadow, AppTheme.softShadowFor(colors));
        expect(find.byType(Image), findsNothing);
      },
    );
  }

  testWidgets('the back button closes the page', (tester) async {
    await _pushed(
      tester,
      const AuthFormLayout(title: 'T', description: 'D', child: Text('form')),
    );

    await tester.tap(find.byKey(AuthFormLayout.backKey));
    await tester.pumpAndSettle();

    expect(find.text('form'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets(
    'the brand layout shows logo C and the app name, without a back button',
    (tester) async {
      await tester.pumpWidget(
        withAppSettings(
          const AuthFormLayout.brand(
            tagline: 'Câu giới thiệu',
            child: Text('form'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        StartupSplashScreen.logoAsset,
      );
      expect(find.text(StartupSplashScreen.appName), findsOneWidget);
      expect(
        paintedColor(tester, find.text('Câu giới thiệu')),
        BandColors.secondary,
      );
      expect(find.byKey(AuthFormLayout.backKey), findsNothing);
    },
  );

  testWidgets('the footer link calls back when tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      withAppSettings(
        AuthFormLayout.brand(
          tagline: 't',
          footer: AuthFooterLink(
            question: 'Chưa có tài khoản? ',
            action: 'Đăng ký ngay',
            onTap: () => taps++,
          ),
          child: const Text('form'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AuthFooterLink));
    expect(taps, 1);
  });

  testWidgets(
    'the footer link draws its splash above the gradient, on its own transparent Material',
    (tester) async {
      await tester.pumpWidget(
        withAppSettings(
          AuthFormLayout.brand(
            tagline: 't',
            footer: AuthFooterLink(
              question: 'Chưa có tài khoản? ',
              action: 'Đăng ký ngay',
              onTap: () {},
            ),
            child: const Text('form'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final material = tester.widget<Material>(
        find
            .ancestor(of: find.byType(InkWell), matching: find.byType(Material))
            .first,
      );
      expect(
        find.descendant(
          of: find.byType(AuthFooterLink),
          matching: find.byWidget(material),
        ),
        findsOneWidget,
        reason: 'the nearest Material lies under the gradient otherwise',
      );
      expect(material.type, MaterialType.transparency);
    },
  );

  testWidgets('a password field hides its text until the eye is tapped', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'secret');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      withAppSettings(
        Scaffold(
          body: AuthTextField(
            controller: controller,
            label: 'Mật khẩu',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    EditableText editable() =>
        tester.widget<EditableText>(find.byType(EditableText));
    expect(editable().obscureText, isTrue);
    expect(find.byTooltip('Hiện mật khẩu'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();

    expect(editable().obscureText, isFalse);
    expect(find.byTooltip('Ẩn mật khẩu'), findsOneWidget);
  });

  testWidgets(
    'the social buttons call their own callback, and do nothing when off',
    (tester) async {
      final taps = <String>[];
      Widget buttons({required bool on}) => withAppSettings(
        Scaffold(
          body: AuthSocialButtons(
            dividerText: 'Hoặc đăng nhập với',
            onGoogle: on ? () => taps.add('google') : null,
            onFacebook: on ? () => taps.add('facebook') : null,
          ),
        ),
      );
      await tester.pumpWidget(buttons(on: true));
      await tester.pumpAndSettle();

      expect(find.text('Hoặc đăng nhập với'), findsOneWidget);
      await tester.tap(find.text('Google'));
      await tester.tap(find.text('Facebook'));
      expect(taps, ['google', 'facebook']);

      await tester.pumpWidget(buttons(on: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google'));
      expect(taps, ['google', 'facebook']);
    },
  );

  testWidgets('a tall form scrolls on a 320 px phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pushed(
      tester,
      const AuthFormLayout(
        title: 'Đặt lại mật khẩu',
        description: 'Nhập mã OTP đã được gửi tới a***@example.com',
        footer: AuthFooterLink(
          question: 'Nhớ ra rồi? ',
          action: 'Đăng nhập',
          onTap: _noop,
        ),
        child: SizedBox(height: 1000, child: Text('form')),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byType(AuthFooterLink),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(AuthFooterLink).hitTestable(), findsOneWidget);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      '${mode.name}: the system navigation bar continues the bottom of the gradient',
      (tester) async {
        await _pushed(
          tester,
          const AuthFormLayout(
            title: 'T',
            description: 'D',
            child: Text('form'),
          ),
          mode: mode,
        );

        final gradient = tester
            .element(find.text('form'))
            .colors
            .headerGradient;
        final style = tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find
                  .byWidgetPredicate(
                    (widget) =>
                        widget is AnnotatedRegion<SystemUiOverlayStyle> &&
                        find
                            .descendant(
                              of: find.byWidget(widget),
                              matching: find.byKey(AuthFormLayout.cardKey),
                            )
                            .evaluate()
                            .isNotEmpty,
                  )
                  .first,
            )
            .value;
        expect(style.statusBarIconBrightness, Brightness.light);
        expect(style.systemNavigationBarColor, gradient.colors.last);
      },
    );
  }

  testWidgets('no auth field autocorrects what is typed', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      withAppSettings(
        Scaffold(
          body: AuthTextField(
            controller: controller,
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).autocorrect,
      isFalse,
    );
  });
}

void _noop() {}
