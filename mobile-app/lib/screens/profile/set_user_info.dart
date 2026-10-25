import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/widgets/common/custom_text_field.dart';
import 'package:finance_ai_app/widgets/common/primary_button.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';

/// Edits the profile on the server: the display name (username) and the phone, the two fields of core-backend's
/// UserUpdateDto a user may change. The server takes the user from the JWT and refuses any other id.
class SetUserInfoScreen extends StatefulWidget {
  final int userId;

  const SetUserInfoScreen({super.key, required this.userId});

  @override
  State<SetUserInfoScreen> createState() => _SetUserInfoScreenState();
}

class _SetUserInfoScreenState extends State<SetUserInfoScreen> {
  static final RegExp _phonePattern = RegExp(r'^0[0-9]{9}$');
  static const String _saveFailedTitle = 'Lưu thất bại';
  static const String _loadFailedMessage =
      'Không tải được thông tin cá nhân. Vui lòng thử lại.';

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final user = await AppRepository.instance.getCurrentUser(widget.userId);
      if (!mounted) return;
      _nameController.text = user?.fullName ?? '';
      _phoneController.text = user?.phone ?? '';
      setState(() => _isLoading = false);
    } catch (e) {
      UserFacingError.log('Profile form load', e);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _snack('Vui lòng nhập họ và tên.');
      return;
    }
    if (phone.isNotEmpty && !_phonePattern.hasMatch(phone)) {
      _snack('Số điện thoại không hợp lệ (10 số, bắt đầu bằng 0).');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await RemoteApiHelper.instance.updateUserProfile(
        userId: widget.userId,
        username: name,
        phone: phone.isEmpty ? null : phone,
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      await AppDialog.success(
        context,
        title: 'Thành công',
        message: 'Đã lưu thông tin cá nhân.',
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      UserFacingError.log('Profile save', e);
      if (!mounted) return;
      setState(() => _isSaving = false);
      await AppDialog.error(
        context,
        title: _saveFailedTitle,
        message: UserFacingError.messageOf(e),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('Thiết lập thông tin')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
          ? _LoadFailedView(message: _loadFailedMessage, onRetry: _loadUser)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.person_rounded, size: 92, color: colors.primary),
                  const SizedBox(height: 32),
                  CustomTextField(
                    controller: _nameController,
                    label: 'Họ và tên',
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _phoneController,
                    label: 'Số điện thoại',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 40),
                  PrimaryButton(
                    text: _isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
                    onPressed: _isSaving
                        ? null
                        : () {
                            _save();
                          },
                  ),
                ],
              ),
            ),
    );
  }
}

/// A fixed error text with a retry button, shown when the profile could not be read.
class _LoadFailedView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadFailedView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
