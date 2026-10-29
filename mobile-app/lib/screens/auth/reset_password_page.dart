import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/utils/email_format.dart';
import 'package:finance_ai_app/core/utils/password_policy.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/screens/auth/login_page.dart';
import 'package:finance_ai_app/screens/auth/password_recovery_errors.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/widgets/auth/auth_form_layout.dart';
import 'package:finance_ai_app/widgets/auth/auth_text_field.dart';
import 'package:finance_ai_app/widgets/auth/otp_input.dart';
import 'package:finance_ai_app/widgets/common/primary_button.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

/// Second step of the password recovery: the OTP emailed to [email] and the new password. On success the user is sent
/// to the login screen to sign in with it: nothing is signed in here, the server hands out no tokens for a reset.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  /// The address the OTP went to, exactly as the server got it: the reset and every resend use it unchanged.
  final String email;

  /// Digits of an OTP; core-backend draws it with AuthService.OTP_LENGTH, change both together.
  static const int otpLength = 6;

  /// How long resending stays off after an OTP went out; the server itself sets no limit.
  static const Duration resendCooldown = Duration(seconds: 60);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static const Duration _countdownStep = Duration(seconds: 1);
  static final RegExp _otpPattern = RegExp(
    '^[0-9]{${ResetPasswordScreen.otpLength}}\$',
  );

  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  // Seconds before the OTP may be sent again. Only the resend button listens, so the countdown rebuilds nothing else.
  final _resendSecondsLeft = ValueNotifier<int>(0);
  Timer? _resendCountdown;

  bool _isResetting = false;
  bool _isResending = false;
  // Errors show once the user has tried to reset, then follow what they type.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  // One request at a time: a resend replaces the OTP on the server, so it must not cross a reset that uses it.
  bool get _isBusy => _isResetting || _isResending;

  @override
  void initState() {
    super.initState();
    // The previous screen has just sent an OTP.
    _startResendCooldown();
  }

  @override
  void dispose() {
    _resendCountdown?.cancel();
    _resendSecondsLeft.dispose();
    // The OTP and the passwords typed here go with the screen.
    for (final controller in [
      _otpController,
      _passwordController,
      _confirmationController,
    ]) {
      controller
        ..clear()
        ..dispose();
    }
    super.dispose();
  }

  void _startResendCooldown() {
    _resendCountdown?.cancel();
    _resendSecondsLeft.value = ResetPasswordScreen.resendCooldown.inSeconds;
    _resendCountdown = Timer.periodic(_countdownStep, (timer) {
      final left = _resendSecondsLeft.value - 1;
      _resendSecondsLeft.value = left;
      if (left <= 0) timer.cancel();
    });
  }

  String? _validateOtp(String otp) {
    if (otp.isEmpty) return context.loc.resetPasswordOtpRequired;
    if (!_otpPattern.hasMatch(otp)) {
      return context.loc.resetPasswordOtpInvalid(ResetPasswordScreen.otpLength);
    }
    return null;
  }

  /// PasswordPolicy decides, with the rules of core-backend's @StrongPassword; the error repeats those rules.
  String? _validateNewPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return context.loc.resetPasswordPasswordRequired;
    if (PasswordPolicy.validate(password, context.loc) != null) {
      return _passwordRules(context.loc);
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    final confirmation = value ?? '';
    if (confirmation.isEmpty) return context.loc.resetPasswordConfirmRequired;
    if (confirmation != _passwordController.text) {
      return context.loc.resetPasswordMismatch;
    }
    return null;
  }

  static String _passwordRules(AppLocalizations loc) =>
      loc.resetPasswordPasswordPolicy(
        PasswordPolicy.minLength,
        PasswordPolicy.maxLength,
      );

  Future<void> _resetPassword() async {
    if (_isBusy) return;
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    final loc = context.loc;
    FocusScope.of(context).unfocus();
    setState(() => _isResetting = true);
    try {
      await RemoteApiHelper.instance.resetPassword(
        email: widget.email,
        otp: _otpController.text,
        newPassword: _passwordController.text,
      );
    } catch (e) {
      PasswordRecoveryErrors.log(PasswordRecoveryRequest.resetPassword, e);
      if (!mounted) return;
      setState(() => _isResetting = false);
      await AppDialog.error(
        context,
        title: loc.resetPasswordFailed,
        message: PasswordRecoveryErrors.messageOf(
          PasswordRecoveryRequest.resetPassword,
          e,
          loc,
        ),
        buttonText: loc.dialogGotIt,
      );
      return;
    }
    if (!mounted) return;
    // The buttons stay off until the screen goes. No session is opened: the user signs in with the new password.
    await AppDialog.success(
      context,
      title: loc.resetPasswordSuccessTitle,
      message: loc.resetPasswordSuccessMessage,
      buttonText: loc.resetPasswordBackToLogin,
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _resendOtp() async {
    if (_isBusy || _resendSecondsLeft.value > 0) return;
    final loc = context.loc;
    setState(() => _isResending = true);
    try {
      await RemoteApiHelper.instance.forgotPassword(email: widget.email);
    } catch (e) {
      PasswordRecoveryErrors.log(PasswordRecoveryRequest.sendOtp, e);
      if (!mounted) return;
      // No OTP went out: what the user typed stays, and they may try again at once.
      setState(() => _isResending = false);
      await AppDialog.error(
        context,
        title: loc.forgotPasswordSendFailed,
        message: PasswordRecoveryErrors.messageOf(
          PasswordRecoveryRequest.sendOtp,
          e,
          loc,
        ),
        buttonText: loc.dialogGotIt,
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isResending = false);
    _startResendCooldown();
    AppToast.success(context, loc.resetPasswordOtpResent);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return PopScope(
      // Leaving while the reset is out would hide its outcome, and the password may already have changed.
      canPop: !_isResetting,
      child: AuthFormLayout(
        title: loc.resetPasswordTitle,
        description: loc.resetPasswordDescription(
          EmailFormat.mask(widget.email),
        ),
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidateMode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OtpInput(
                controller: _otpController,
                length: ResetPasswordScreen.otpLength,
                semanticsLabel: loc.resetPasswordOtpLabel,
                validator: _validateOtp,
              ),
              const SizedBox(height: 20),
              AuthTextField(
                controller: _passwordController,
                label: loc.resetPasswordNewPasswordLabel,
                hint: loc.resetPasswordNewPasswordHint,
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                helperText: _passwordRules(loc),
                validator: _validateNewPassword,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _confirmationController,
                label: loc.resetPasswordConfirmPasswordLabel,
                hint: loc.resetPasswordConfirmPasswordHint,
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                validator: _validateConfirmation,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _resetPassword(),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                text: _isResetting
                    ? loc.resetPasswordSubmitting
                    : loc.resetPasswordSubmit,
                onPressed: _isBusy ? null : _resetPassword,
              ),
              const SizedBox(height: 4),
              Center(
                child: _ResendOtpButton(
                  secondsLeft: _resendSecondsLeft,
                  isSending: _isResending,
                  onPressed: _isBusy ? null : _resendOtp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Resend code": counts down while [secondsLeft] runs, says that it is sending while [isSending], and is off when
/// [onPressed] is null. It listens to [secondsLeft] itself, so a tick repaints this button and nothing around it.
class _ResendOtpButton extends StatelessWidget {
  const _ResendOtpButton({
    required this.secondsLeft,
    required this.isSending,
    required this.onPressed,
  });

  final ValueListenable<int> secondsLeft;
  final bool isSending;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return ValueListenableBuilder<int>(
      valueListenable: secondsLeft,
      builder: (context, seconds, _) {
        final waiting = seconds > 0;
        final String label;
        if (isSending) {
          label = loc.passwordRecoverySending;
        } else if (waiting) {
          label = loc.resetPasswordResendIn(seconds);
        } else {
          label = loc.resetPasswordResendOtp;
        }
        return TextButton(
          onPressed: waiting ? null : onPressed,
          child: Text(label),
        );
      },
    );
  }
}
