import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/password_policy.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/social_auth_service.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/screens/main_scaffold.dart';
import 'package:finance_ai_app/widgets/auth/auth_form_layout.dart';
import 'package:finance_ai_app/widgets/auth/auth_social_buttons.dart';
import 'package:finance_ai_app/widgets/auth/auth_text_field.dart';
import 'package:finance_ai_app/widgets/common/primary_button.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  // On while the account is being created, so a second tap sends nothing.
  bool _isSubmitting = false;
  // On while a Google or Facebook sign-up is out.
  bool _isSocialLoading = false;

  bool get _isBusy => _isSubmitting || _isSocialLoading;
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  void _checkPassword(String password) {
    setState(() {
      _hasMinLength = PasswordPolicy.hasMinLength(password);
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool _isPasswordValid() =>
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasNumber &&
      _hasSpecialChar;

  Future<void> _handleRegister() async {
    if (_isBusy) return;
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final phone = _phoneController.text.trim();

    if (fullName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        phone.isEmpty) {
      await AppDialog.error(
        context,
        title: context.loc.authMissingInfoTitle,
        message: context.loc.registerMissingFields,
      );
      return;
    }

    final policyError = PasswordPolicy.validate(password, context.loc);
    if (!_isPasswordValid() || policyError != null) {
      await AppDialog.error(
        context,
        title: context.loc.registerWeakPasswordTitle,
        message: policyError ?? context.loc.registerWeakPasswordMessage,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await RemoteApiHelper.instance.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      if (!mounted) return;
      await AppDialog.success(
        context,
        title: context.loc.registerSuccessTitle,
        message: context.loc.registerSuccessMessage,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      UserFacingError.log('Register', e);
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: context.loc.registerFailedTitle,
        message: UserFacingError.messageOf(e, context.loc),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleSocial(
    Future<Map<String, dynamic>> Function() signIn,
  ) async {
    if (_isBusy) return;
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
        await SessionService.setTokens(token, refreshToken);
      }

      if (userId != null) {
        await SessionService.setCurrentUserId(userId);
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScaffold()),
        (route) => false,
      );
    } on SocialSignInCancelled {
      // The user closed the sign-in sheet: nothing to report.
    } catch (e) {
      UserFacingError.log('Social sign-up', e);
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: context.loc.registerFailedTitle,
        message: UserFacingError.messageOf(
          e,
          context.loc,
          fallback: context.loc.registerSocialFailed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSocialLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    return AuthFormLayout(
      title: loc.registerHeading,
      description: loc.registerDescription,
      footer: AuthFooterLink(
        question: loc.registerHaveAccount,
        action: loc.loginSubmit,
        onTap: () => Navigator.maybePop(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          AuthTextField(
            controller: _fullNameController,
            label: loc.registerFullNameLabel,
            hint: loc.registerFullNameHint,
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _emailController,
            label: loc.authEmailLabel,
            hint: loc.authEmailHint,
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _phoneController,
            label: loc.registerPhoneLabel,
            hint: loc.registerPhoneHint,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _passwordController,
            label: loc.authPasswordLabel,
            hint: loc.authPasswordHint,
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            textInputAction: TextInputAction.done,
            onChanged: _checkPassword,
          ),
          const SizedBox(height: 10),
          _PasswordRules(
            rules: [
              (
                loc.registerRuleMinLength(PasswordPolicy.minLength),
                _hasMinLength,
              ),
              (loc.registerRuleUppercase, _hasUppercase),
              (loc.registerRuleLowercase, _hasLowercase),
              (loc.registerRuleDigit, _hasNumber),
              (loc.registerRuleSpecial, _hasSpecialChar),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            text: _isSubmitting ? loc.authProcessing : loc.registerSubmit,
            onPressed: _isBusy ? null : _handleRegister,
          ),
          AuthSocialButtons(
            dividerText: loc.registerOrContinueWith,
            onGoogle: _isBusy
                ? null
                : () => _handleSocial(
                    SocialAuthService.instance.signInWithGoogle,
                  ),
            onFacebook: _isBusy
                ? null
                : () => _handleSocial(
                    SocialAuthService.instance.signInWithFacebook,
                  ),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              text: loc.registerTermsPrefix,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: AppTextSize.caption,
              ),
              children: [
                TextSpan(
                  text: loc.registerTerms,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: loc.registerTermsAnd),
                TextSpan(
                  text: loc.registerConditions,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The password rules in two columns, always shown (T9 auth mockup H). A met rule is ticked in the success colour; an
/// open one stays a ring in the secondary text colour.
class _PasswordRules extends StatelessWidget {
  const _PasswordRules({required this.rules});

  static const int _columns = 2;
  static const double _iconSize = 16;

  final List<(String, bool)> rules;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final success = context.colors.successColor;
    return Column(
      children: [
        for (var row = 0; row < rules.length; row += _columns)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = row; i < row + _columns; i++)
                  Expanded(
                    child: i < rules.length
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                rules[i].$2
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: rules[i].$2
                                    ? success
                                    : colors.onSurfaceVariant,
                                size: _iconSize,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  rules[i].$1,
                                  style: TextStyle(
                                    color: rules[i].$2
                                        ? success
                                        : colors.onSurfaceVariant,
                                    fontSize: AppTextSize.caption,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
