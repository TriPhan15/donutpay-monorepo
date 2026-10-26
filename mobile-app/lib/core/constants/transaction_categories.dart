import 'package:flutter/material.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';

class TransactionCategories {
  static const String all = 'Tất cả';

  /// Default categories the forms preselect, by the name core-backend stores.
  static const String food = 'Ăn uống';
  static const String otherExpense = 'Khác';

  /// Essential default expense categories, by the name core-backend stores (DefaultCategory key in each comment).
  static const String groceries = 'Siêu thị & Chợ'; // groceries
  static const String transport = 'Di chuyển'; // transport
  static const String housing = 'Nhà ở'; // housing
  static const String utilities = 'Điện nước'; // utilities
  static const String telecom = 'Internet & Điện thoại'; // telecom
  static const String health = 'Sức khỏe'; // health
  static const String education = 'Giáo dục'; // education
  static const String family = 'Gia đình & Con cái'; // family
  static const String insurance = 'Bảo hiểm'; // insurance

  /// Money moved from the wallet into a savings goal (POST /api/savings/{id}/contributions records it).
  static const String savings = 'Tiết kiệm'; // savings

  /// The default expense categories that are needs (the "50" of the 50/30/20 rule): food, home, bills, getting around,
  /// health, schooling, children and insurance. Shopping, entertainment, travel, gifts and "Khác" are wants.
  static const Set<String> essentialExpenses = {
    food,
    groceries,
    transport,
    housing,
    utilities,
    telecom,
    health,
    education,
    family,
    insurance,
  };

  /// The default categories, by the Vietnamese name core-backend stores (its DefaultCategory enum, whose stable key is
  /// in each comment), and their text in the language the app shows. Renaming one there means renaming it here too.
  static final Map<String, String Function(AppLocalizations)> _labelByName = {
    all: (loc) => loc.categoryAll,
    food: (loc) => loc.categoryFood, // food
    groceries: (loc) => loc.categoryGroceries, // groceries
    transport: (loc) => loc.categoryTransport, // transport
    housing: (loc) => loc.categoryHousing, // housing
    utilities: (loc) => loc.categoryUtilities, // utilities
    telecom: (loc) => loc.categoryTelecom, // telecom
    'Mua sắm': (loc) => loc.categoryShopping, // shopping
    health: (loc) => loc.categoryHealth, // health
    education: (loc) => loc.categoryEducation, // education
    'Giải trí': (loc) => loc.categoryEntertainment, // entertainment
    'Du lịch': (loc) => loc.categoryTravel, // travel
    family: (loc) => loc.categoryFamily, // family
    'Hiếu hỉ': (loc) => loc.categorySocial, // social
    insurance: (loc) => loc.categoryInsurance, // insurance
    savings: (loc) => loc.categorySavings, // savings
    otherExpense: (loc) => loc.categoryOtherExpense, // other_expense
    'Lương': (loc) => loc.categorySalary, // salary
    'Thưởng': (loc) => loc.categoryBonus, // bonus
    'Kinh doanh': (loc) => loc.categoryBusiness, // business
    'Đầu tư': (loc) => loc.categoryInvestment, // investment
    'Được tặng': (loc) => loc.categoryGift, // gift
    'Thu khác': (loc) => loc.categoryOtherIncome, // other_income
  };

  /// [name] as the user should read it: a default category (or [all]) in the language of [loc]; a category the user
  /// created keeps the name they gave it. Only for display: the server still gets and filters by [name].
  static String displayName(AppLocalizations loc, String name) =>
      _labelByName[name.trim()]?.call(loc) ?? name;

  static List<String> expenseSelectable = [];
  static List<String> incomeSelectable = [];
  static List<String> selectable = [];

  static Future<void> loadFromApi() async {
    try {
      final cats = await RemoteApiHelper.instance.fetchCategories();
      expenseSelectable.clear();
      incomeSelectable.clear();

      for (var c in cats) {
        final name = c['name'].toString();
        final type = c['type'].toString();
        if (type == 'EXPENSE') {
          expenseSelectable.add(name);
        } else {
          incomeSelectable.add(name);
        }
      }

      selectable = _uniquePreserveOrder([
        ...expenseSelectable,
        ...incomeSelectable,
      ]);
    } catch (e) {
      debugPrint("Lỗi nạp danh mục TransactionCategories: $e");
    }
  }

  static List<String> forType({required bool isExpense}) {
    return isExpense ? expenseSelectable : incomeSelectable;
  }

  static List<String> _uniquePreserveOrder(List<String> input) {
    final seen = <String>{};
    final output = <String>[];
    for (final item in input) {
      if (seen.add(item)) output.add(item);
    }
    return output;
  }

  static IconData iconFor(String category) {
    final c = category.toLowerCase();

    if (c == 'tất cả') return Icons.filter_list_rounded;

    if (c.contains('ăn') ||
        c.contains('uống') ||
        c.contains('phê') ||
        c.contains('vặt')) {
      return Icons.fastfood_rounded;
    }
    if (c.contains('đi') || c.contains('xe') || c.contains('xăng')) {
      return Icons.local_gas_station_rounded;
    }
    if (c.contains('hóa đơn') ||
        c.contains('điện') ||
        c.contains('nước') ||
        c.contains('internet')) {
      return Icons.receipt_rounded;
    }
    if (c.contains('y tế') || c.contains('sức khỏe')) {
      return Icons.medical_services_rounded;
    }
    if (c.contains('giáo dục') || c.contains('học')) {
      return Icons.school_rounded;
    }
    if (c.contains('nhà ở')) return Icons.house_rounded;
    if (c.contains('mua sắm') ||
        c.contains('quần áo') ||
        c.contains('shopping')) {
      return Icons.shopping_bag_rounded;
    }
    if (c.contains('giải trí') || c.contains('game') || c.contains('đồ chơi')) {
      return Icons.sports_esports_rounded;
    }
    if (c.contains('du lịch')) return Icons.flight_takeoff_rounded;
    if (c.contains('làm đẹp')) return Icons.face_retouching_natural_rounded;
    if (c.contains('tiết kiệm')) return Icons.savings_rounded;

    if (c.contains('lương') || c.contains('thu nhập')) {
      return Icons.monetization_on_rounded;
    }
    if (c.contains('thưởng')) return Icons.card_giftcard_rounded;

    return Icons.label_important_rounded;
  }
}
