import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/theme/category_colors.dart';

void main() {
  // Plain colour schemes: building AppTheme here, outside testWidgets, would start a google_fonts load with no binding.
  const light = ColorScheme.light(primary: Color(0xFF0284C7));
  const dark = ColorScheme.dark(primary: Color(0xFF38BDF8));

  test('the four groups get the Tươi vui colours', () {
    expect(CategoryColors.accentFor('Ăn uống', light), const Color(0xFFFF9F43));
    expect(CategoryColors.accentFor('Mua sắm', light), const Color(0xFFFF6B88));
    expect(
      CategoryColors.accentFor('Siêu thị & Chợ', light),
      CategoryColors.shopping,
    );
    expect(
      CategoryColors.accentFor('Di chuyển', light),
      const Color(0xFF12B5A0),
    );
    expect(
      CategoryColors.accentFor('Điện nước', light),
      const Color(0xFF7C68E8),
    );
    expect(
      CategoryColors.accentFor('Internet & Điện thoại', light),
      CategoryColors.bills,
    );
    expect(CategoryColors.accentFor('Nhà ở', light), CategoryColors.bills);
  });

  test('extra spaces are ignored', () {
    expect(CategoryColors.accentFor('  Ăn uống ', light), CategoryColors.food);
  });

  test(
    'other and user-made categories take the primary colour of the theme',
    () {
      expect(CategoryColors.accentFor('Cà phê', light), light.primary);
      expect(CategoryColors.accentFor('', light), light.primary);
      expect(CategoryColors.accentFor('Sức khỏe', dark), dark.primary);
    },
  );

  test('the category colours are the same in both themes', () {
    expect(CategoryColors.accentFor('Ăn uống', dark), CategoryColors.food);
  });

  test('the icon tile is the accent made pale', () {
    expect(
      CategoryColors.tileFor(CategoryColors.food, Brightness.light),
      CategoryColors.food.withValues(alpha: 0.16),
    );
    expect(
      CategoryColors.tileFor(CategoryColors.food, Brightness.dark),
      CategoryColors.food.withValues(alpha: 0.24),
    );
  });
}
