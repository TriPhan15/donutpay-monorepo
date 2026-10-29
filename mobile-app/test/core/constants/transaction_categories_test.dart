import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';

import '../../helpers/fake_backend.dart';

final AppLocalizations _vi = lookupAppLocalizations(const Locale('vi'));
final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));

/// The Vietnamese names of core-backend's DefaultCategory, the only names the server stores for its default categories.
const List<String> _backendNames = [
  'Ăn uống',
  'Siêu thị & Chợ',
  'Di chuyển',
  'Nhà ở',
  'Điện nước',
  'Internet & Điện thoại',
  'Mua sắm',
  'Sức khỏe',
  'Giáo dục',
  'Giải trí',
  'Du lịch',
  'Gia đình & Con cái',
  'Hiếu hỉ',
  'Bảo hiểm',
  'Khác',
  'Lương',
  'Thưởng',
  'Kinh doanh',
  'Đầu tư',
  'Được tặng',
  'Thu khác',
];

void main() {
  group('TransactionCategories.displayName', () {
    test(
      'in Vietnamese every default category keeps the name the server stores',
      () {
        for (final name in _backendNames) {
          expect(TransactionCategories.displayName(_vi, name), name);
        }
      },
    );

    test(
      'in English every default category is translated, each to its own text',
      () {
        final translated = {
          for (final name in _backendNames)
            TransactionCategories.displayName(_en, name),
        };
        expect(translated, hasLength(_backendNames.length));
        expect(translated.intersection(_backendNames.toSet()), isEmpty);
        expect(
          TransactionCategories.displayName(_en, 'Ăn uống'),
          'Food & drinks',
        );
        expect(TransactionCategories.displayName(_en, ' Lương '), 'Salary');
      },
    );

    test('a category the user created keeps its name in every language', () {
      expect(TransactionCategories.displayName(_en, 'Nuôi mèo'), 'Nuôi mèo');
      expect(TransactionCategories.displayName(_vi, 'Nuôi mèo'), 'Nuôi mèo');
    });

    test('the "all" filter is translated too', () {
      expect(
        TransactionCategories.displayName(_en, TransactionCategories.all),
        _en.categoryAll,
      );
    });
  });

  group('TransactionCategories.loadFromApi', () {
    test('the savings category cannot be picked for a manual expense', () async {
      final backend = FakeBackend();
      RemoteApiHelper.instance.init(httpClientAdapter: backend);
      backend.on(
        'GET',
        '/api/categories',
        (_) => okResponse([
          {'id': 1, 'name': 'Ăn uống', 'type': 'EXPENSE'},
          {'id': 2, 'name': 'Tiết kiệm', 'type': 'EXPENSE'},
          {'id': 3, 'name': 'Lương', 'type': 'INCOME'},
        ]),
      );

      await TransactionCategories.loadFromApi();

      expect(TransactionCategories.forType(isExpense: true), ['Ăn uống']);
      expect(TransactionCategories.forType(isExpense: false), ['Lương']);
      expect(TransactionCategories.isSavings(' Tiết kiệm '), isTrue);
    });
  });
}
