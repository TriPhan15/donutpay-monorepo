import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/screens/main_scaffold.dart';
import 'package:finance_ai_app/widgets/common/primary_button.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/services/social_auth_service.dart';
import 'package:finance_ai_app/widgets/auth/auth_form_layout.dart';
import 'package:finance_ai_app/widgets/auth/auth_social_buttons.dart';
import 'package:finance_ai_app/widgets/auth/auth_text_field.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/screens/auth/forgot_password_page.dart';

import 'register_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  /// The page a successful sign-in opens, in place of every route. Only tests replace it, so that a sign-in can be
  /// checked without the whole app behind it.
  @visibleForTesting
  static WidgetBuilder home = (_) => const MainScaffold();

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Checked by default, as the app always kept the session; unchecked, the session ends when the app is closed.
  bool _rememberMe = true;
  bool _isLoginLoading = false;
  bool _isSocialLoading = false;

  @override
  void initState() {
    super.initState();
    _fillRememberedEmail();
  }

  /// The email of the last sign-in made with "remember me", after a sign-out or a restart. Never over what the user has
  /// already started to type.
  Future<void> _fillRememberedEmail() async {
    final email = await SessionService.rememberedEmail();
    if (!mounted || email == null || _emailController.text.isNotEmpty) return;
    _emailController.text = email;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(
    BuildContext context, {
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedPassword = password;

    if (normalizedEmail.isEmpty || normalizedPassword.isEmpty) {
      await AppDialog.error(
        context,
        title: context.loc.authMissingInfoTitle,
        message: context.loc.loginMissingCredentials,
      );
      return;
    }
    if (_isLoginLoading || _isSocialLoading) return;
    setState(() => _isLoginLoading = true);
    try {
      final result = await RemoteApiHelper.instance.login(
        normalizedEmail,
        normalizedPassword,
      );
      final data = (result['data'] as Map?) ?? result;

      final token = (data['token'] ?? result['token'])?.toString() ?? '';
      final refreshToken =
          (data['refreshToken'] ?? result['refreshToken'])?.toString() ?? '';

      final user = data['user'] as Map?;
      final userId =
          (user?['id'] ?? data['userId'] ?? result['userId'] ?? result['id'])
              as int?;

      if (token.isNotEmpty && refreshToken.isNotEmpty) {
        await SessionService.setTokens(
          token,
          refreshToken,
          remember: _rememberMe,
        );
      }

      if (userId == null) {
        if (!context.mounted) return;
        await AppDialog.error(
          context,
          title: context.loc.loginFailedTitle,
          message: context.loc.loginInvalidResponse,
        );
        return;
      }
      await SessionService.setCurrentUserId(userId);
      await SessionService.rememberEmail(_rememberMe ? normalizedEmail : null);
      // Tells the password manager of the system that the sign-in worked, so it offers to save the email and password.
      TextInput.finishAutofillContext();

      AppRepository.instance
          .getHomeSummary(userId)
          .catchError((_) => <String, dynamic>{});

      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: LoginScreen.home),
        (route) => false,
      );
    } catch (e) {
      UserFacingError.log('Login', e);
      if (!context.mounted) return;
      await AppDialog.error(
        context,
        title: context.loc.loginFailedTitle,
        message: UserFacingError.messageOf(
          e,
          context.loc,
          unauthorizedMessage: context.loc.loginWrongCredentials,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoginLoading = false);
    }
  }

  /// The one way into the password recovery. The recovery screens never sign in: whatever happens there, the user
  /// comes back here, or to a new login screen, and signs in with the new password.
  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  Future<void> _handleSocial(
    Future<Map<String, dynamic>> Function() signIn,
  ) async {
    if (_isSocialLoading || _isLoginLoading) return;
    setState(() => _isSocialLoading = true);
    try {
      final res = await signIn();
      final data = (res['data'] as Map?) ?? res;
      final token = (data['token'] ?? res['token'])?.toString() ?? '';
      final refreshToken =
          (data['refreshToken'] ?? res['refreshToken'])?.toString() ?? '';

      final user = data['user'] as Map?;
      final userId = (user?['id'] ?? data['userId'] ?? res['userId']) as int?;

      if (token.isNotEmpty && refreshToken.isNotEmpty) {
        await SessionService.setTokens(
          token,
          refreshToken,
          remember: _rememberMe,
        );
      }

      if (userId != null) {
        await SessionService.setCurrentUserId(userId);

        AppRepository.instance
            .getHomeSummary(userId)
            .catchError((_) => <String, dynamic>{});
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: LoginScreen.home),
        (route) => false,
      );
    } on SocialSignInCancelled {
      // The user closed the sign-in sheet: nothing to report.
    } catch (e) {
      UserFacingError.log('Social login', e);
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: context.loc.loginFailedTitle,
        message: UserFacingError.messageOf(
          e,
          context.loc,
          fallback: context.loc.loginSocialFailed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSocialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final busy = _isLoginLoading || _isSocialLoading;
    return AuthFormLayout.brand(
      tagline: loc.loginTagline,
      footer: AuthFooterLink(
        question: loc.loginNoAccount,
        action: loc.loginSignUpNow,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          // One autofill group, so the password manager of the system fills in and saves both fields together.
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _emailController,
                  label: loc.authEmailLabel,
                  hint: loc.authEmailHint,
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _passwordController,
                  label: loc.authPasswordLabel,
                  hint: loc.authPasswordHint,
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                // Checked, the box takes the primary colour of the theme.
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.loginRememberMe,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: AppTextSize.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: GestureDetector(
                  onTap: _openForgotPassword,
                  child: Text(
                    loc.loginForgotPassword,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: AppTextSize.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            text: _isLoginLoading ? loc.authProcessing : loc.loginSubmit,
            onPressed: busy
                ? null
                : () {
                    _handleLogin(
                      context,
                      email: _emailController.text,
                      password: _passwordController.text,
                    );
                  },
          ),
          AuthSocialButtons(
            dividerText: loc.loginOrContinueWith,
            onGoogle: busy
                ? null
                : () => _handleSocial(
                    SocialAuthService.instance.signInWithGoogle,
                  ),
            onFacebook: busy
                ? null
                : () => _handleSocial(
                    SocialAuthService.instance.signInWithFacebook,
                  ),
          ),
        ],
      ),
    );
  }
}
