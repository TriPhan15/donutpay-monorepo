import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/screens/auth/register_page.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/auth/auth_form_layout.dart';
import 'package:finance_ai_app/widgets/common/primary_button.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/theme_colors.dart';

const String _registerPath = '/api/auth/register';
const String _createAccount = 'Tạo tài khoản';
const String _processing = 'Đang xử lý...';
const String _successTitle = 'Đăng ký thành công';
const String _done = 'Xong';

/// Opens the register screen on top of itself, as the login screen does, so that it has a page to go back to.
class _Opener extends StatelessWidget {
  const _Opener();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
          child: const Text('open'),
        ),
      ),
    );
  }
}

void main() {
  final backend = FakeBackend();

  setUpAll(() {
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    // SharedPreferences shares one Future, which must be created inside the test body (see budget_display_test.dart).
    SharedPreferences.setMockInitialValues({});
    backend.reset();
  });

  tearDown(() => Intl.defaultLocale = null);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(withAppSettings(const _Opener()));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder submitButton() => find.descendant(
    of: find.byType(PrimaryButton),
    matching: find.byType(ElevatedButton),
  );

  Future<void> fillIn(WidgetTester tester) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Nguyễn Minh Anh');
    await tester.enterText(fields.at(1), 'an@example.com');
    await tester.enterText(fields.at(2), '0901234567');
    await tester.enterText(fields.at(3), 'Abcdefg1!');
    await tester.pump();
  }

  testWidgets(
    'the title sits on the gradient and the five password rules show before the password is touched',
    (tester) async {
      await open(tester);

      final title = find.descendant(
        of: find.byType(AuthFormLayout),
        matching: find.text(_createAccount),
      );
      expect(title, findsNWidgets(2), reason: 'the title and the button');
      expect(paintedColor(tester, title.first), BandColors.primary);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(5));
    },
  );

  testWidgets('a strong password meets all five rules', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField).at(3), 'Abcdefg1!');
    await tester.pump();

    final success = tester
        .element(find.byType(RegisterScreen))
        .colors
        .successColor;
    expect(find.byIcon(Icons.check_circle), findsNWidgets(5));
    for (final icon in tester.widgetList<Icon>(
      find.byIcon(Icons.check_circle),
    )) {
      expect(icon.color, success);
    }
  });

  testWidgets(
    'while the account is being created the button is off and more taps send nothing',
    (tester) async {
      final answer = Completer<ResponseBody>();
      backend.on('POST', _registerPath, (_) => answer.future);
      await open(tester);
      await fillIn(tester);

      // Two taps in the same frame: the second one comes before the button is rebuilt as disabled.
      await tester.tap(submitButton());
      await tester.tap(submitButton());
      await tester.pump(const Duration(milliseconds: 100));

      expect(backend.requests, hasLength(1));
      expect(tester.widget<ElevatedButton>(submitButton()).onPressed, isNull);
      expect(find.text(_processing), findsOneWidget);

      answer.complete(okResponse(null));
      await tester.pumpAndSettle();

      expect(find.text(_successTitle), findsOneWidget);
      expect(backend.requests, hasLength(1));
    },
  );

  testWidgets(
    'after the account is created, "Done" goes back to the previous page',
    (tester) async {
      backend.on('POST', _registerPath, (_) => okResponse(null));
      await open(tester);
      await fillIn(tester);

      await tester.tap(submitButton());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_done));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    },
  );

  testWidgets('the white "Sign in" link goes back to the previous page', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.byType(AuthFooterLink));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets(
    'while the account is being created the Google and Facebook buttons are off too',
    (tester) async {
      final answer = Completer<ResponseBody>();
      backend.on('POST', _registerPath, (_) => answer.future);
      await open(tester);
      await fillIn(tester);

      await tester.tap(submitButton());
      await tester.pump(const Duration(milliseconds: 100));

      for (final name in ['Google', 'Facebook']) {
        final button = tester.widget<InkWell>(
          find
              .ancestor(of: find.text(name), matching: find.byType(InkWell))
              .first,
        );
        expect(button.onTap, isNull, reason: name);
      }

      answer.complete(okResponse(null));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('two quick taps on an empty form open one dialog', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(submitButton());
    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(find.text('Thiếu thông tin'), findsOneWidget);
  });

  testWidgets(
    'Back waits while the account is being created, so the outcome is still shown',
    (tester) async {
      final answer = Completer<ResponseBody>();
      backend.on('POST', _registerPath, (_) => answer.future);
      await open(tester);
      await fillIn(tester);

      await tester.tap(submitButton());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(AuthFormLayout.backKey));
      // Longer than any page transition.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.byType(RegisterScreen), findsOneWidget);

      answer.complete(okResponse({'id': 1}));
      await tester.pumpAndSettle();
      expect(find.text(_successTitle), findsOneWidget);
      await tester.tap(find.text(_done));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsNothing);
    },
  );
}
