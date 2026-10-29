import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';

/// The "Tươi vui" category colours (T9 spec, 2.1), the same in light and dark mode. A category icon sits on a pale
/// tile of its colour ([tileFor]) and is drawn in the colour itself ([accentFor]).
abstract final class CategoryColors {
  static const Color food = Color(0xFFFF9F43);
  static const Color shopping = Color(0xFFFF6B88);
  static const Color transport = Color(0xFF12B5A0);
  static const Color bills = Color(0xFF7C68E8);

  static const double _lightTileAlpha = 0.16;
  static const double _darkTileAlpha = 0.24;

  /// The default categories of the four groups, by the name core-backend stores.
  static const Map<String, Color> _byName = {
    TransactionCategories.food: food,
    TransactionCategories.shopping: shopping,
    TransactionCategories.groceries: shopping,
    TransactionCategories.transport: transport,
    TransactionCategories.utilities: bills,
    TransactionCategories.telecom: bills,
    TransactionCategories.housing: bills,
  };

  /// The colour of [category]. Every other category, a user-made one included, takes the primary colour of [scheme].
  static Color accentFor(String category, ColorScheme scheme) =>
      _byName[category.trim()] ?? scheme.primary;

  /// The pale tile behind an icon drawn in [accent].
  static Color tileFor(Color accent, Brightness brightness) =>
      accent.withValues(
        alpha: brightness == Brightness.light
            ? _lightTileAlpha
            : _darkTileAlpha,
      );
}
