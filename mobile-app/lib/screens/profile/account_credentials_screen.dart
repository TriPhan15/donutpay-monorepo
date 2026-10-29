import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/password_policy.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/auth/auth_text_field.dart';
import 'package:finance_ai_app/widgets/auth/password_rule_list.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

/// "Đổi mật khẩu" (T9 spec 3.8, mockups R9 + R5 + R10): three fields with an eye button, the five rules always shown
/// under the new password (met in green, open in orange), a green outline and tick on the confirmation once it matches,
/// and the button faded until both hold. A change that succeeds swaps the form for a large tick and Xong.
class AccountCredentialsScreen extends StatefulWidget {
  const AccountCredentialsScreen({super.key});

  @override
  State<AccountCredentialsScreen> createState() =>
      _AccountCredentialsScreenState();
}

class _AccountCredentialsScreenState extends State<AccountCredentialsScreen> {
  static const double _cardRadius = 20;
  static const double _matchBorderWidth = 1.5;
  static const double _tickSlot = 30;

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _busy = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _currentController,
      _newController,
      _confirmController,
    ]) {
      controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _confirmMatches =>
      _confirmController.text.isNotEmpty &&
      _confirmController.text == _newController.text;

  bool get _ready =>
      _currentController.text.isNotEmpty &&
      PasswordPolicy.meetsAllRules(_newController.text) &&
      _confirmMatches;

  Future<void> _submit() async {
    if (_busy) return;
    final loc = context.loc;
    final currentPassword = _currentController.text;
    final newPassword = _newController.text;
    final confirmPassword = _confirmController.text;

    if (currentPassword.isEmpty) {
      AppToast.error(context, loc.credentialsOldPasswordRequired);
      return;
    }
    if (newPassword.isEmpty) {
      AppToast.error(context, loc.resetPasswordPasswordRequired);
      return;
    }
    if (confirmPassword.isEmpty) {
      AppToast.error(context, loc.resetPasswordConfirmRequired);
      return;
    }
    // The server never sends the password, so only the server can tell that the old one is wrong.
    final policyError = PasswordPolicy.validate(newPassword, loc);
    if (policyError != null) {
      AppToast.error(context, policyError);
      return;
    }
    if (newPassword != confirmPassword) {
      AppToast.error(context, loc.credentialsPasswordMismatch);
      return;
    }

    setState(() => _busy = true);
    final changed = await _changePasswordOnServer(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = changed;
    });
  }

  /// PUT /api/auth/change-password. The server checks the old password; on failure the form stays with what the user
  /// typed. The token that made the call is revoked by the server, RemoteApiHelper stores the pair the answer carries.
  Future<bool> _changePasswordOnServer({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (SessionService.currentUserId == null) {
      setState(() => _busy = false);
      await AppDialog.error(
        context,
        title: context.loc.credentialsChangePasswordFailed,
        message: context.loc.errorSessionExpired,
      );
      return false;
    }

    try {
      await RemoteApiHelper.instance.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } catch (e) {
      UserFacingError.log('Change password', e);
      if (!mounted) return false;
      // The spinner stops before the dialog opens: the page is waiting for the user, not for the server.
      setState(() => _busy = false);
      await AppDialog.error(
        context,
        title: context.loc.credentialsChangePasswordFailed,
        message: _messageOf(e, context.loc),
      );
      return false;
    }
    return true;
  }

  /// 401 and 403 mean the token is gone, whatever the server wrote; anything else follows [UserFacingError.messageOf].
  static String _messageOf(Object error, AppLocalizations loc) {
    final status = error is DioException ? error.response?.statusCode : null;
    if (status == HttpStatus.unauthorized || status == HttpStatus.forbidden) {
      return loc.errorSessionExpired;
    }
    return UserFacingError.messageOf(
      error,
      loc,
      rejectedMessage: loc.credentialsChangePasswordRejected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageBand(title: loc.credentialsChangePassword),
          Expanded(child: _done ? const _DoneView() : _form(context)),
          FormSubmitBar(
            label: _done ? loc.dialogDone : loc.credentialsChangePassword,
            onPressed: _done
                ? () => Navigator.pop(context)
                : (_ready ? _submit : null),
            busy: _busy,
          ),
        ],
      ),
    );
  }

  Widget _form(BuildContext context) {
    final loc = context.loc;
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(_cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _currentController,
                  label: loc.credentialsOldPassword,
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _newController,
                  label: loc.resetPasswordNewPasswordLabel,
                  icon: Icons.lock_reset_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                PasswordRuleList(
                  password: _newController.text,
                  pendingColor: context.colors.warningColor,
                ),
                const SizedBox(height: 12),
                _confirmField(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The confirmation field; once it matches the new password its outline turns green and a tick shows beside it.
  Widget _confirmField(BuildContext context) {
    final loc = context.loc;
    final field = AuthTextField(
      controller: _confirmController,
      label: loc.resetPasswordConfirmPasswordLabel,
      icon: Icons.lock_outline_rounded,
      isPassword: true,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) {
        if (_ready) _submit();
      },
    );
    // The same tree whether it matches or not, so the field keeps its focus and its eye state while the user types.
    final matches = _confirmMatches;
    final success = context.colors.successColor;
    final theme = Theme.of(context);
    final base = theme.inputDecorationTheme;
    final side = BorderSide(color: success, width: _matchBorderWidth);
    InputBorder green(InputBorder? border) =>
        (border ?? const OutlineInputBorder()).copyWith(borderSide: side);
    return Row(
      children: [
        Expanded(
          child: Theme(
            data: matches
                ? theme.copyWith(
                    inputDecorationTheme: base.copyWith(
                      enabledBorder: green(base.enabledBorder),
                      focusedBorder: green(base.focusedBorder),
                    ),
                  )
                : theme,
            child: field,
          ),
        ),
        SizedBox(
          width: _tickSlot,
          child: matches
              ? Icon(
                  Icons.check_circle_rounded,
                  key: const ValueKey('change-password-confirm-match'),
                  color: success,
                  size: 22,
                  semanticLabel: loc.changePasswordMatches,
                )
              : null,
        ),
      ],
    );
  }
}

/// What replaces the form once the password has changed: a large tick, the title and what it means for other devices.
class _DoneView extends StatelessWidget {
  const _DoneView();

  static const double _circleSize = 80;
  static const double _iconSize = 40;
  static const double _tint = 0.14;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = Theme.of(context).colorScheme;
    final success = context.colors.successColor;
    return SingleChildScrollView(
      key: const ValueKey('change-password-done'),
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Column(
        children: [
          Container(
            width: _circleSize,
            height: _circleSize,
            decoration: BoxDecoration(
              color: success.withValues(alpha: _tint),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: success, size: _iconSize),
          ),
          const SizedBox(height: 16),
          Text(
            loc.credentialsChangePasswordSuccessTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: AppTextSize.pageTitle,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loc.changePasswordDoneMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: AppTextSize.body,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
