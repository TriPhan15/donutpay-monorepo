import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/models/user_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/profile/account_credentials_screen.dart';
import 'package:finance_ai_app/screens/profile/widgets/account_field_sheet.dart';
import 'package:finance_ai_app/screens/profile/widgets/profile_group.dart';
import 'package:finance_ai_app/screens/profile/widgets/profile_header_band.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

/// "Thông tin tài khoản" (T9 spec 3.8, mockup M1): the band with the letter avatar, the name and the email; the personal
/// information (name and phone open a one-field sheet, the email is locked) and the security group.
///
/// Saving goes through PUT /api/users/{id} with one of the two fields of core-backend's UserUpdateDto a user may change,
/// the display name (username) or the phone; the server takes the user from the JWT and refuses any other id.
class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  static final RegExp _phonePattern = RegExp(r'^0[0-9]{9}$');
  static const double _avatarSize = 52;

  bool _isLoading = true;
  bool _loadFailed = false;
  bool _sheetOpen = false;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = SessionService.currentUserId;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _user = null;
      });
      return;
    }
    // A reload with the account on screen (after a save) keeps it there: no spinner, and a failure is only a toast.
    final refreshing = _user != null;
    if (!refreshing) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }
    try {
      final user = await AppRepository.instance.getCurrentUser(userId);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = false;
        _user = user;
      });
    } catch (e) {
      UserFacingError.log('Account info load', e);
      if (!mounted) return;
      if (refreshing) {
        final loc = context.loc;
        AppToast.error(
          context,
          UserFacingError.messageOf(e, loc),
          actionLabel: loc.commonRetry,
          onAction: _load,
        );
        return;
      }
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  static String _maskPhone(String phone) {
    if (phone.length <= 4) return phone;
    return '${'*' * (phone.length - 4)}${phone.substring(phone.length - 4)}';
  }

  /// Sends the one field the user edited, [name] or [phone], and nothing else: the server keeps a field it does not
  /// receive, so a display name made from the email is never written back as the username. Answers whether the sheet
  /// may close; an unchanged value closes it without a request.
  Future<bool> _save(UserModel user, {String? name, String? phone}) async {
    final loc = context.loc;
    final newName = name?.trim();
    final newPhone = phone?.trim();
    if (newName != null) {
      if (newName.isEmpty) {
        AppToast.error(context, loc.setUserInfoNameRequired);
        return false;
      }
      if (newName == user.fullName) return true;
    }
    if (newPhone != null) {
      // The server ignores a blank phone, so clearing it cannot be saved.
      if (newPhone.isEmpty) {
        AppToast.error(context, loc.accountPhoneRequired);
        return false;
      }
      if (!_phonePattern.hasMatch(newPhone)) {
        AppToast.error(context, loc.setUserInfoPhoneInvalid);
        return false;
      }
      if (newPhone == user.phone) return true;
    }
    final userId = user.id ?? SessionService.currentUserId;
    if (userId == null) {
      AppToast.error(context, loc.accountInfoSignInAgain);
      return false;
    }

    try {
      await RemoteApiHelper.instance.updateUserProfile(
        userId: userId,
        username: newName,
        phone: newPhone,
      );
    } catch (e) {
      UserFacingError.log('Profile save', e);
      if (!mounted) return false;
      // Not awaited: the sheet stops its spinner as soon as this answers, while the dialog stays over it.
      unawaited(
        AppDialog.error(
          context,
          title: context.loc.commonSaveFailed,
          message: UserFacingError.messageOf(e, context.loc),
        ),
      );
      return false;
    }
    if (!mounted) return true;
    AppToast.success(context, context.loc.setUserInfoSaved);
    _load();
    return true;
  }

  /// Opens one sheet at a time: two quick taps on a row would otherwise stack two.
  Future<void> _openSheet({
    required String title,
    required String label,
    required IconData icon,
    required String initialValue,
    required TextInputType keyboardType,
    required Future<bool> Function(String value) onSave,
  }) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    try {
      await showAccountFieldSheet(
        context,
        title: title,
        label: label,
        icon: icon,
        initialValue: initialValue,
        keyboardType: keyboardType,
        onSave: onSave,
      );
    } finally {
      _sheetOpen = false;
    }
  }

  void _editName(UserModel user) {
    final loc = context.loc;
    _openSheet(
      title: loc.accountEditNameTitle,
      label: loc.registerFullNameLabel,
      icon: Icons.person_outline_rounded,
      initialValue: user.fullName,
      keyboardType: TextInputType.name,
      onSave: (value) => _save(user, name: value),
    );
  }

  void _editPhone(UserModel user) {
    final loc = context.loc;
    _openSheet(
      title: loc.accountEditPhoneTitle,
      label: loc.registerPhoneLabel,
      icon: Icons.phone_outlined,
      initialValue: user.phone ?? '',
      keyboardType: TextInputType.phone,
      onSave: (value) => _save(user, phone: value),
    );
  }

  void _openChangePassword() {
    if (SessionService.currentUserId == null) {
      AppToast.error(context, context.loc.accountInfoSignInAgain);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountCredentialsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final user = _user;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageBand(
            title: loc.accountInfoTitle,
            bottom: user == null ? null : _BandProfile(user: user),
          ),
          Expanded(child: _body(user)),
        ],
      ),
    );
  }

  Widget _body(UserModel? user) {
    if (_isLoading) {
      return const Center(child: AppStateView.loading());
    }
    if (_loadFailed) {
      return Center(
        child: AppStateView.error(
          title: context.loc.setUserInfoLoadFailed,
          onRetry: _load,
        ),
      );
    }
    if (user == null) {
      return Center(
        child: AppStateView.empty(
          icon: Icons.person_off_outlined,
          title: context.loc.accountInfoSignInAgain,
        ),
      );
    }
    final phone = user.phone ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        _InfoGroup(
          title: context.loc.userInfoTitle,
          rows: [
            _InfoRow(
              key: const ValueKey('account-row-name'),
              label: context.loc.registerFullNameLabel,
              value: user.fullName,
              onTap: () => _editName(user),
            ),
            _InfoRow(
              key: const ValueKey('account-row-email'),
              label: context.loc.authEmailLabel,
              value: user.email,
              lockedLabel: context.loc.accountEmailLocked,
            ),
            _InfoRow(
              key: const ValueKey('account-row-phone'),
              label: context.loc.registerPhoneLabel,
              value: phone.isEmpty
                  ? context.loc.userInfoNotSet
                  : _maskPhone(phone),
              onTap: () => _editPhone(user),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ProfileGroup(
          title: context.loc.accountSecurityTitle,
          rows: [
            ProfileRow(
              key: const ValueKey('account-change-password'),
              icon: Icons.lock_outline_rounded,
              label: context.loc.credentialsChangePassword,
              onTap: _openChangePassword,
            ),
          ],
        ),
      ],
    );
  }
}

/// The letter avatar, the name and the email inside the band.
class _BandProfile extends StatelessWidget {
  const _BandProfile({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    const size = _AccountInfoScreenState._avatarSize;
    return Row(
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: BandColors.tint,
            shape: BoxShape.circle,
          ),
          child: Text(
            ProfileHeaderBand.initialsOf(user.fullName),
            style: const TextStyle(
              color: BandColors.primary,
              fontSize: AppTextSize.pageTitle,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BandColors.primary,
                  fontSize: AppTextSize.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (user.email.isNotEmpty)
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BandColors.secondary,
                    fontSize: AppTextSize.secondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A row of the personal information: the label on the left, the value in grey on the right, then a chevron, or a lock
/// when the value cannot be changed ([onTap] null).
class _InfoRow {
  const _InfoRow({
    required this.key,
    required this.label,
    required this.value,
    this.onTap,
    this.lockedLabel,
  });

  final Key key;
  final String label;
  final String value;
  final VoidCallback? onTap;

  /// Spoken label of the lock of a row that cannot be changed.
  final String? lockedLabel;
}

/// The card of the personal information, drawn like a [ProfileGroup] but with label / value rows and no icon box.
class _InfoGroup extends StatelessWidget {
  const _InfoGroup({required this.title, required this.rows});

  static const double _radius = 16;

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: AppTextSize.caption,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        // A Material, not a coloured Container: ListTile paints its ink on the nearest Material.
        Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(_radius),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    color: colors.outlineVariant,
                  ),
                _tile(colors, rows[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(ColorScheme colors, _InfoRow row) {
    final locked = row.onTap == null;
    return ListTile(
      key: row.key,
      onTap: row.onTap,
      title: Row(
        children: [
          Text(
            row.label,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: AppTextSize.body,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: AppTextSize.body,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
            color: colors.onSurfaceVariant,
            size: locked ? 16 : 20,
            semanticLabel: locked ? row.lockedLabel : null,
          ),
        ],
      ),
    );
  }
}
