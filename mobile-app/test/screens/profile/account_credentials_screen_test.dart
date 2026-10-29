import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/utils/password_policy.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/screens/profile/account_credentials_screen.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_settings_repository.dart';
import '../../helpers/theme_colors.dart';

const String _changePasswordPath = '/api/auth/change-password';
const String _oldPassword = 'OldPass123';
const String _newPassword = 'Matkhau@20';

final AppLocalizations _vi = lookupAppLocalizations(const Locale('vi'));

void main() {
  final backend = FakeBackend();

  setUpAll(() {
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend.reset();
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Intl.defaultLocale = null;
    AppToast.resetForTest();
  });

  /// Opens the page pushed over a plain page, so that Xong has somewhere to go back to.
  Future<void> openPage(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.vietnamese,
  }) async {
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      withAppSettings(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AccountCredentialsScreen(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        settings: FakeSettingsRepository(language: language),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> fillForm(
    WidgetTester tester, {
    String oldPassword = _oldPassword,
    String newPassword = _newPassword,
    String? confirmPassword,
  }) async {
    await tester.enterText(field(_vi.credentialsOldPassword), oldPassword);
    await tester.enterText(
      field(_vi.resetPasswordNewPasswordLabel),
      newPassword,
    );
    await tester.enterText(
      field(_vi.resetPasswordConfirmPasswordLabel),
      confirmPassword ?? newPassword,
    );
    await tester.pump();
  }

  Finder submitButton() => find.byType(FilledButton);

  bool submitEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(submitButton()).onPressed != null;

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.tap(submitButton());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  Finder ruleIcon(PasswordRule rule) => find.descendant(
    of: find.byKey(ValueKey('password-rule-${rule.name}')),
    matching: find.byType(Icon),
  );

  Finder matchTick() =>
      find.byKey(const ValueKey('change-password-confirm-match'));

  List<RequestOptions> changePasswordCalls() =>
      backend.requests.where((r) => r.path == _changePasswordPath).toList();

  group('the five rules', () {
    final missing = <PasswordRule, String>{
      PasswordRule.minLength: 'Mk@2',
      PasswordRule.uppercase: 'matkhau@20',
      PasswordRule.lowercase: 'MATKHAU@20',
      PasswordRule.digit: 'Matkhau@xx',
      PasswordRule.special: 'Matkhau20',
    };
    missing.forEach((rule, password) {
      testWidgets(
        '"$password" leaves only ${rule.name} open, in orange, and the button faded',
        (tester) async {
          await openPage(tester);
          await fillForm(tester, newPassword: password);
          final context = tester.element(find.byType(AccountCredentialsScreen));

          expect(
            tester.widget<Icon>(ruleIcon(rule)).icon,
            Icons.radio_button_unchecked,
          );
          expect(
            paintedColor(tester, ruleIcon(rule)),
            context.colors.warningColor,
          );
          for (final other in PasswordRule.values.where((r) => r != rule)) {
            expect(
              tester.widget<Icon>(ruleIcon(other)).icon,
              Icons.check_circle,
              reason: other.name,
            );
          }
          expect(submitEnabled(tester), isFalse);
        },
      );
    });

    testWidgets('the rules show before anything is typed', (tester) async {
      await openPage(tester);

      for (final rule in PasswordRule.values) {
        expect(find.text(rule.label(_vi)), findsOneWidget);
      }
      expect(submitEnabled(tester), isFalse);
    });
  });

  group('the confirmation and the button', () {
    testWidgets(
      'all rules and a matching confirmation light the button and show the tick',
      (tester) async {
        await openPage(tester);
        await fillForm(tester);

        expect(matchTick(), findsOneWidget);
        expect(submitEnabled(tester), isTrue);
      },
    );

    testWidgets(
      'changing the new password after a match removes the tick and fades the button',
      (tester) async {
        await openPage(tester);
        await fillForm(tester);

        await tester.enterText(
          field(_vi.resetPasswordNewPasswordLabel),
          'Matkhau@21',
        );
        await tester.pump();

        expect(matchTick(), findsNothing);
        expect(submitEnabled(tester), isFalse);
      },
    );

    testWidgets('an empty old password keeps the button faded', (tester) async {
      await openPage(tester);
      await fillForm(tester, oldPassword: '');

      expect(matchTick(), findsOneWidget);
      expect(submitEnabled(tester), isFalse);
    });
  });

  group('changing the password on the server', () {
    testWidgets(
      'sends the old and the new password, then shows the success view; Xong closes the page',
      (tester) async {
        // The change ends every session of the account; the answer carries the pair this device goes on with.
        backend.on(
          'PUT',
          _changePasswordPath,
          (_) => okResponse({
            'token': 'changed-access',
            'refreshToken': 'changed-refresh',
          }, message: 'Đổi mật khẩu thành công!'),
        );
        await openPage(tester);
        await fillForm(tester);

        await tapSubmit(tester);

        final calls = changePasswordCalls();
        expect(calls, hasLength(1));
        expect(calls.single.method, 'PUT');
        expect(calls.single.data, {
          'oldPassword': _oldPassword,
          'newPassword': _newPassword,
        });
        expect(
          find.byKey(const ValueKey('change-password-done')),
          findsOneWidget,
        );
        expect(find.text('Đổi mật khẩu thành công'), findsOneWidget);
        expect(
          find.text(
            'Mật khẩu mới đã được áp dụng. Các thiết bị khác cần đăng nhập lại.',
          ),
          findsOneWidget,
        );
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(SessionService.currentUserId, 1);
        expect(SessionService.currentToken, 'changed-access');
        expect(SessionService.currentRefreshToken, 'changed-refresh');

        await tester.tap(find.text('Xong'));
        await tester.pumpAndSettle();
        expect(find.byType(AccountCredentialsScreen), findsNothing);
        expect(find.text('open'), findsOneWidget);
      },
    );

    testWidgets(
      'a wrong old password is shown with the message of the server, and the form keeps what was typed',
      (tester) async {
        backend.on(
          'PUT',
          _changePasswordPath,
          (_) => jsonResponse(400, {
            'code': 400,
            'message': 'Mật khẩu cũ không chính xác',
          }),
        );
        await openPage(tester);
        await fillForm(tester, oldPassword: 'WrongPass1');

        await tapSubmit(tester);

        expect(find.text('Đổi mật khẩu thất bại'), findsOneWidget);
        expect(find.text('Mật khẩu cũ không chính xác'), findsOneWidget);

        await tester.tap(find.text('Đã hiểu'));
        await tester.pumpAndSettle();

        final oldField = tester.widget<TextField>(
          field(_vi.credentialsOldPassword),
        );
        expect(oldField.controller!.text, 'WrongPass1');
        expect(SessionService.currentUserId, 1);
      },
    );

    testWidgets(
      'in English a refusal shows the app text: the server message is Vietnamese only',
      (tester) async {
        final en = lookupAppLocalizations(const Locale('en'));
        backend.on(
          'PUT',
          _changePasswordPath,
          (_) => jsonResponse(400, {
            'code': 400,
            'message': 'Mật khẩu cũ không chính xác',
          }),
        );
        await openPage(tester, language: AppLanguage.english);
        await tester.enterText(field(en.credentialsOldPassword), 'WrongPass1');
        await tester.enterText(
          field(en.resetPasswordNewPasswordLabel),
          _newPassword,
        );
        await tester.enterText(
          field(en.resetPasswordConfirmPasswordLabel),
          _newPassword,
        );
        await tester.pump();
        await tapSubmit(tester);

        expect(find.text(en.credentialsChangePasswordFailed), findsOneWidget);
        expect(find.text(en.credentialsChangePasswordRejected), findsOneWidget);
        expect(find.text('Mật khẩu cũ không chính xác'), findsNothing);
      },
    );

    testWidgets(
      'without a connection it says so instead of showing the raw error',
      (tester) async {
        backend.on(
          'PUT',
          _changePasswordPath,
          (options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'no network',
          ),
        );
        await openPage(tester);
        await fillForm(tester);

        await tapSubmit(tester);

        expect(find.text('Đổi mật khẩu thất bại'), findsOneWidget);
        expect(
          find.text(
            'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a 403 (missing or invalid token) asks the user to sign in again',
      (tester) async {
        backend.on(
          'PUT',
          _changePasswordPath,
          (_) => jsonResponse(403, {'error': 'Forbidden'}),
        );
        await openPage(tester);
        await fillForm(tester);

        await tapSubmit(tester);

        expect(
          find.text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('without a session nothing is sent', (tester) async {
      await openPage(tester);
      await fillForm(tester);
      await SessionService.clearSession();

      await tapSubmit(tester);

      expect(
        find.text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
        findsOneWidget,
      );
      expect(changePasswordCalls(), isEmpty);
    });

    testWidgets('a double tap sends one request', (tester) async {
      final answer = Completer<ResponseBody>();
      backend.on('PUT', _changePasswordPath, (_) => answer.future);
      await openPage(tester);
      await fillForm(tester);

      await tester.tap(submitButton());
      await tester.tap(submitButton(), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));

      expect(changePasswordCalls(), hasLength(1));
      answer.complete(okResponse(null));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'an answer that arrives after the screen was left changes nothing and throws nothing',
      (tester) async {
        final answer = Completer<ResponseBody>();
        backend.on('PUT', _changePasswordPath, (_) => answer.future);
        await openPage(tester);
        await fillForm(tester);

        await tester.tap(submitButton());
        await tester.pump(const Duration(milliseconds: 100));
        expect(changePasswordCalls(), hasLength(1));

        await tester.pumpWidget(const SizedBox.shrink());
        answer.complete(okResponse(null));
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets(
    'a 73-character password that meets the rules is refused before anything is sent',
    (tester) async {
      final tooLong = 'Aa1@${'b' * 69}';
      await openPage(tester);
      await fillForm(tester, newPassword: tooLong);
      expect(submitEnabled(tester), isTrue);

      await tapSubmit(tester);

      expect(find.text(PasswordPolicy.validate(tooLong, _vi)!), findsOneWidget);
      expect(changePasswordCalls(), isEmpty);
    },
  );
}
