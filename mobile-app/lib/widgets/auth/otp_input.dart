import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finance_ai_app/core/theme/app_typography.dart';

/// A one-time code as [length] separate boxes (T9 spec 3.2). The boxes are drawn over one hidden field, so paste, SMS
/// autofill (AutofillHints.oneTimeCode) and the keyboard work as on any field. It is a form field: [validator] gets
/// the digits typed, and its error shows under the boxes.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controller,
    required this.length,
    required this.semanticsLabel,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  static const double boxHeight = 52;
  static const double boxMaxWidth = 48;
  static const double gap = 8;

  static Key boxKey(int index) => ValueKey('otp-box-$index');

  final TextEditingController controller;
  final int length;
  final String semanticsLabel;
  final String? Function(String otp)? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  static const double _radius = 12;
  static const double _borderWidth = 1.5;
  static const double _ringWidth = 3;

  final _focusNode = FocusNode();
  final _fieldKey = GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(OtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    // Tells the form field, so that an autovalidating form follows what is typed.
    _fieldKey.currentState?.didChange(widget.controller.text);
    setState(() {});
  }

  void _onFocus() => setState(() {});

  /// Any box opens the keyboard on the hidden field, with the caret after the last digit.
  void _focus() {
    final text = widget.controller.text;
    widget.controller.selection = TextSelection.collapsed(offset: text.length);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FormField<String>(
      key: _fieldKey,
      initialValue: widget.controller.text,
      validator: (_) => widget.validator?.call(widget.controller.text),
      builder: (field) {
        final digits = widget.controller.text;
        final active = math.min(digits.length, widget.length - 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: OtpInput.boxHeight,
              child: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final fit =
                          (constraints.maxWidth -
                              OtpInput.gap * (widget.length - 1)) /
                          widget.length;
                      final width = math.min(OtpInput.boxMaxWidth, fit);
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < widget.length; i++) ...[
                            if (i > 0) const SizedBox(width: OtpInput.gap),
                            _OtpBox(
                              key: OtpInput.boxKey(i),
                              width: width,
                              digit: i < digits.length ? digits[i] : null,
                              border: field.hasError
                                  ? colors.error
                                  : (_focusNode.hasFocus && i == active
                                        ? colors.primary
                                        : colors.outlineVariant),
                              ring: _focusNode.hasFocus && i == active
                                  ? colors.primaryContainer
                                  : null,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  // The field takes every tap on the boxes; its text and caret are invisible, the boxes show them.
                  Positioned.fill(
                    child: Semantics(
                      label: widget.semanticsLabel,
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.number,
                        textInputAction: widget.textInputAction,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        autocorrect: false,
                        enableSuggestions: false,
                        showCursor: false,
                        cursorColor: Colors.transparent,
                        style: const TextStyle(color: Colors.transparent),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(widget.length),
                        ],
                        decoration: const InputDecoration.collapsed(
                          hintText: null,
                        ),
                        onTap: _focus,
                        onSubmitted: widget.onSubmitted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (field.errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Text(
                  field.errorText!,
                  style: TextStyle(
                    color: colors.error,
                    fontSize: AppTextSize.caption,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One box: the digit typed there, or nothing. The box being typed into has the primary outline and a soft ring.
class _OtpBox extends StatelessWidget {
  const _OtpBox({
    super.key,
    required this.width,
    required this.digit,
    required this.border,
    required this.ring,
  });

  final double width;
  final String? digit;
  final Color border;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: OtpInput.boxHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_OtpInputState._radius),
        border: Border.all(color: border, width: _OtpInputState._borderWidth),
        boxShadow: ring == null
            ? null
            : [
                BoxShadow(
                  color: ring!,
                  spreadRadius: _OtpInputState._ringWidth,
                ),
              ],
      ),
      child: digit == null
          ? null
          : Text(
              digit!,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: AppTextSize.pageTitle,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
