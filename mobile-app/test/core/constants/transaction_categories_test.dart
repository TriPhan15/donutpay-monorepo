import 'package:dio/dio.dart';
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
    final backend = FakeBackend();

    setUpAll(() {
      RemoteApiHelper.instance.init(httpClientAdapter: backend);
    });

    setUp(backend.reset);

    test(
      'the savings category cannot be picked for a manual expense',
      () async {
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
      },
    );

    group('with categories already cached', () {
      setUp(() async {
        backend.reset();
        backend.on(
          'GET',
          '/api/categories',
          (_) => okResponse([
            {'id': 1, 'name': 'Ăn uống', 'type': 'EXPENSE'},
            {'id': 2, 'name': 'Nuôi mèo', 'type': 'EXPENSE'},
            {'id': 3, 'name': 'Lương', 'type': 'INCOME'},
          ]),
        );
        await TransactionCategories.loadFromApi();
      });

      tearDown(TransactionCategories.clear);

      test('a failed load leaves the cached categories as they were', () async {
        for (final failure in <ResponseBody Function(RequestOptions)>[
          (_) => jsonResponse(500, {'code': 500, 'message': 'Lỗi hệ thống'}),
          (_) => jsonResponse(200, {'unexpected': 'shape'}),
          (options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'no network',
          ),
        ]) {
          backend.on('GET', '/api/categories', failure);

          await TransactionCategories.loadFromApi();

          expect(TransactionCategories.forType(isExpense: true), [
            'Ăn uống',
            'Nuôi mèo',
          ]);
          expect(TransactionCategories.forType(isExpense: false), ['Lương']);
          expect(TransactionCategories.selectable, [
            'Ăn uống',
            'Nuôi mèo',
            'Lương',
          ]);
        }
      });

      test('a successful load replaces them', () async {
        backend.on(
          'GET',
          '/api/categories',
          (_) => okResponse([
            {'id': 1, 'name': 'Ăn uống', 'type': 'EXPENSE'},
            {'id': 4, 'name': 'Thưởng', 'type': 'INCOME'},
          ]),
        );

        await TransactionCategories.loadFromApi();

        expect(TransactionCategories.forType(isExpense: true), ['Ăn uống']);
        expect(TransactionCategories.forType(isExpense: false), ['Thưởng']);
      });

      test(
        'clear() empties the cache, and a list read earlier is not touched',
        () {
          final readBefore = TransactionCategories.forType(isExpense: true);

          TransactionCategories.clear();

          expect(TransactionCategories.forType(isExpense: true), isEmpty);
          expect(TransactionCategories.forType(isExpense: false), isEmpty);
          expect(TransactionCategories.selectable, isEmpty);
          expect(readBefore, ['Ăn uống', 'Nuôi mèo']);
        },
      );
    });
  });
}
