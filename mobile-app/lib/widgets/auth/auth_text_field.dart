import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';

/// A field of the sign-in flow (T9 auth mockup H): the label sits on the outline, an icon leads, the hint shows inside.
/// Fill, outline and radius come from the theme's inputDecorationTheme. A password field has its own show/hide button,
/// so toggling it rebuilds this field only.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.isPassword = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.validator,
    this.helperText,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final bool isPassword;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final String? helperText;
  final FocusNode? focusNode;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  // Room for the password rules under the field on a narrow phone.
  static const int _supportingTextMaxLines = 3;
  static const double _iconSize = 20;

  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = Theme.of(context).colorScheme;
    final isPassword = widget.isPassword;
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: isPassword && _obscure,
      enableSuggestions: !isPassword,
      // Names, addresses, phone numbers and passwords: nothing here is a word to correct.
      autocorrect: false,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(fontSize: AppTextSize.caption),
        hintText: widget.hint,
        helperText: widget.helperText,
        helperMaxLines: _supportingTextMaxLines,
        errorMaxLines: _supportingTextMaxLines,
        prefixIcon: Icon(
          widget.icon,
          color: colors.onSurfaceVariant,
          size: _iconSize,
        ),
        suffixIcon: isPassword
            ? IconButton(
                tooltip: _obscure ? loc.passwordShow : loc.passwordHide,
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: colors.onSurfaceVariant,
                  size: _iconSize,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    );
  }
}
