import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/theme/category_colors.dart';

/// The icon and colour of a savings goal, guessed from its title (nothing is stored): a few common goals by keyword,
/// otherwise the piggy bank in the primary colour. Colours come from the category palette (T9 spec, 2.1).
abstract final class GoalVisual {
  static final RegExp _separators = RegExp(r'[\s,.;:!?()/\-]+');

  /// Each rule: the words that must follow one another in the title, its icon and its colour (null = primary).
  static const List<(List<String>, IconData, Color?)> _rules = [
    (['laptop'], Icons.laptop_mac_rounded, CategoryColors.bills),
    (['macbook'], Icons.laptop_mac_rounded, CategoryColors.bills),
    (['máy', 'tính'], Icons.laptop_mac_rounded, CategoryColors.bills),
    (['computer'], Icons.laptop_mac_rounded, CategoryColors.bills),
    (['điện', 'thoại'], Icons.smartphone_rounded, CategoryColors.shopping),
    (['iphone'], Icons.smartphone_rounded, CategoryColors.shopping),
    (['phone'], Icons.smartphone_rounded, CategoryColors.shopping),
    (['du', 'lịch'], Icons.flight_rounded, CategoryColors.transport),
    (['travel'], Icons.flight_rounded, CategoryColors.transport),
    (['trip'], Icons.flight_rounded, CategoryColors.transport),
    (['khẩn', 'cấp'], Icons.shield_rounded, null),
    (['dự', 'phòng'], Icons.shield_rounded, null),
    (['emergency'], Icons.shield_rounded, null),
    (['xe', 'máy'], Icons.two_wheeler_rounded, CategoryColors.transport),
    (['ô', 'tô'], Icons.directions_car_rounded, CategoryColors.transport),
    (['xe'], Icons.directions_car_rounded, CategoryColors.transport),
    (['car'], Icons.directions_car_rounded, CategoryColors.transport),
    (['nhà'], Icons.home_rounded, CategoryColors.bills),
    (['house'], Icons.home_rounded, CategoryColors.bills),
    (['home'], Icons.home_rounded, CategoryColors.bills),
    (['học'], Icons.school_rounded, CategoryColors.food),
    (['school'], Icons.school_rounded, CategoryColors.food),
    (['tuition'], Icons.school_rounded, CategoryColors.food),
    (['cưới'], Icons.favorite_rounded, CategoryColors.shopping),
    (['wedding'], Icons.favorite_rounded, CategoryColors.shopping),
    (['quà'], Icons.card_giftcard_rounded, CategoryColors.shopping),
    (['gift'], Icons.card_giftcard_rounded, CategoryColors.shopping),
  ];

  static ({IconData icon, Color color}) of(String title, ColorScheme scheme) {
    final words = title
        .toLowerCase()
        .split(_separators)
        .where((w) => w.isNotEmpty)
        .toList();
    for (final (keywords, icon, color) in _rules) {
      if (_contains(words, keywords)) {
        return (icon: icon, color: color ?? scheme.primary);
      }
    }
    return (icon: Icons.savings_rounded, color: scheme.primary);
  }

  /// Whole words only, so that "xem" never reads as "xe".
  static bool _contains(List<String> words, List<String> keywords) {
    for (var i = 0; i + keywords.length <= words.length; i++) {
      var match = true;
      for (var j = 0; j < keywords.length; j++) {
        if (words[i + j] != keywords[j]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }
}

/// The icon of a goal on a pale tile of its colour.
class GoalIconTile extends StatelessWidget {
  const GoalIconTile({
    super.key,
    required this.title,
    this.size = 34,
    this.radius = 11,
  });

  static const double _iconShare = 0.48;

  final String title;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = GoalVisual.of(title, theme.colorScheme);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: CategoryColors.tileFor(visual.color, theme.brightness),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(visual.icon, color: visual.color, size: size * _iconShare),
    );
  }
}
