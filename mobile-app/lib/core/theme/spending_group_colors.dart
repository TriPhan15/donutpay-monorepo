import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';

/// The three groups of "Cân đối chi tiêu" on the AI tab (T9 spec 3.1): needs in the primary colour, wants in violet,
/// savings in the income colour. Like [CategoryColors], the violet is an identity colour, the same in light and dark
/// mode, light enough for the dark surface; the other two follow the theme.
abstract final class SpendingGroupColors {
  static const Color wants = Color(0xFFA78BFA);

  static Color needs(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color savings(BuildContext context) => context.colors.incomeColor;
}
