import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/money_input_formatter.dart';

/// "Danh mục *": the label over a part of a transaction form, the star in the expense colour when the part is
/// required.
class FormFieldLabel extends StatelessWidget {
  const FormFieldLabel(this.text, {super.key, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: context.colors.expenseColor),
            ),
        ],
      ),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: AppTextSize.caption,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// The amount of a transaction form (T9 spec, 2.2: typed in 30), outlined with the floating label "Số tiền *",
/// grouped as the language groups it while typing.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.label,
    this.onChanged,
  });

  final TextEditingController controller;

  /// "Số tiền" when null.
  final String? label;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      inputFormatters: [MoneyInputFormatter(loc.localeName)],
      style: TextStyle(
        color: colors.onSurface,
        fontSize: AppTextSize.amountLarge,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        label: FormFieldLabel(
          label ?? loc.addTransactionAmountLabel,
          required: true,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: '0',
        hintStyle: TextStyle(
          color: colors.onSurfaceVariant.withValues(alpha: 0.4),
          fontSize: AppTextSize.amountLarge,
          fontWeight: FontWeight.w700,
        ),
        suffixText: loc.currencySymbol,
        suffixStyle: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: AppTextSize.title,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The optional note of a transaction form, outlined with the floating label "Ghi chú (tùy chọn)".
class NoteField extends StatelessWidget {
  const NoteField({super.key, required this.controller, this.hintText});

  final TextEditingController controller;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: AppTextSize.body),
      decoration: InputDecoration(
        labelText: context.loc.transactionNoteOptional,
        hintText: hintText,
      ),
    );
  }
}
