import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/screens/profile/widgets/profile_sheet_frame.dart';
import 'package:finance_ai_app/widgets/auth/auth_text_field.dart';

/// The small sheet of the account screen (T9 spec 3.8, mockup M4): one field and Lưu. [onSave] gets the text as typed
/// and answers whether it was saved; the sheet closes only then, so a refused value stays for the user to fix.
/// Resolves to true when it was saved.
Future<bool> showAccountFieldSheet(
  BuildContext context, {
  required String title,
  required String label,
  required IconData icon,
  required String initialValue,
  required TextInputType keyboardType,
  required Future<bool> Function(String value) onSave,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AccountFieldSheet(
      title: title,
      label: label,
      icon: icon,
      initialValue: initialValue,
      keyboardType: keyboardType,
      onSave: onSave,
    ),
  );
  return saved ?? false;
}

class _AccountFieldSheet extends StatefulWidget {
  const _AccountFieldSheet({
    required this.title,
    required this.label,
    required this.icon,
    required this.initialValue,
    required this.keyboardType,
    required this.onSave,
  });

  final String title;
  final String label;
  final IconData icon;
  final String initialValue;
  final TextInputType keyboardType;
  final Future<bool> Function(String value) onSave;

  @override
  State<_AccountFieldSheet> createState() => _AccountFieldSheetState();
}

class _AccountFieldSheetState extends State<_AccountFieldSheet> {
  static const double _buttonHeight = 52;
  static const double _spinnerSize = 18;

  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final saved = await widget.onSave(_controller.text);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ProfileSheetFrame(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          AuthTextField(
            controller: _controller,
            label: widget.label,
            icon: widget.icon,
            keyboardType: widget.keyboardType,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _buttonHeight,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? SizedBox(
                      width: _spinnerSize,
                      height: _spinnerSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : Text(
                      context.loc.commonSave,
                      style: const TextStyle(
                        fontSize: AppTextSize.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
