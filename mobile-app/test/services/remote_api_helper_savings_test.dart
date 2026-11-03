import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/models/savings_goal.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

import '../helpers/fake_backend.dart';

const String _list = '/api/savings';
const String _me = '/api/users/me';
const String _contributions = '/api/savings/7/contributions';

Map<String, Object?> _goal({num current = 2500000}) => {
  'id': 7,
  'title': 'Du lịch',
  'target': 10000000,
  'current': current,
  'deadline': '31/12/2026',
};

void main() {
  // The 401 interceptor reads the navigator key, and a GlobalKey needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  final backend = FakeBackend();

  setUpAll(() {
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend.reset();
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(42);
    await SessionService.setTokens('access-token', 'refresh-token');
  });

  tearDown(() async {
    await SessionService.clearSession();
  });

  group('fetchSavings', () {
    test('reads the goals into typed goals, in the order sent', () async {
      backend.on(
        'GET',
        _list,
        (_) => okResponse([_goal(), _goal(current: 10000000)..['id'] = 8]),
      );

      final goals = await RemoteApiHelper.instance.fetchSavings();

      final request = backend.requests.single;
      expect(request.method, 'GET');
      expect(request.path, _list);
      expect(request.headers['Authorization'], 'Bearer access-token');
      expect(goals, isA<List<SavingsGoal>>());
      expect(goals.map((g) => g.id), ['7', '8']);
      expect(goals.first.title, 'Du lịch');
      expect(goals.first.target, 10000000);
      expect(goals.first.current, 2500000);
      expect(goals.first.deadline, '31/12/2026');
      expect(goals.last.isDone, isTrue);
    });

    test('keeps the map of each goal, for the planner of the AI tab', () async {
      backend.on('GET', _list, (_) => okResponse([_goal()]));

      final goals = await RemoteApiHelper.instance.fetchSavings();

      expect(goals.single.json, _goal());
    });

    test('an answer without data is the empty list', () async {
      backend.on('GET', _list, (_) => okResponse(null));

      expect(await RemoteApiHelper.instance.fetchSavings(), isEmpty);
    });

    final failures = {
      'a refused request': () => jsonResponse(500, {'code': 500}),
      'data that is not a list': () => okResponse('oops'),
      'a goal that is not an object': () => okResponse([1]),
    };
    failures.forEach((how, answer) {
      test('$how throws, so "none" is told from "could not load"', () async {
        backend.on('GET', _list, (_) => answer());

        await expectLater(
          RemoteApiHelper.instance.fetchSavings(),
          throwsA(anything),
        );
      });
    });
  });

  group('addSaving', () {
    test(
      'posts the title and target, and no deadline when there is none',
      () async {
        backend.on('POST', _list, (_) => okResponse(null));

        await RemoteApiHelper.instance.addSaving(title: 'Mua xe', target: 5e7);

        final request = backend.requests.single;
        expect(request.method, 'POST');
        expect(request.path, _list);
        expect(request.data, {'title': 'Mua xe', 'target': 5e7});
      },
    );

    test('posts a deadline when there is one', () async {
      backend.on('POST', _list, (_) => okResponse(null));

      await RemoteApiHelper.instance.addSaving(
        title: 'Mua xe',
        target: 5e7,
        deadline: '31/12/2026',
      );

      expect(backend.requests.single.data, {
        'title': 'Mua xe',
        'target': 5e7,
        'deadline': '31/12/2026',
      });
    });

    test(
      'does not read the answer, and tells the screens that data changed',
      () async {
        backend.on('POST', _list, (_) => okResponse('anything'));
        var changes = 0;
        void count() => changes++;
        RemoteApiHelper.instance.dataChangedNotifier.addListener(count);
        addTearDown(
          () => RemoteApiHelper.instance.dataChangedNotifier.removeListener(
            count,
          ),
        );

        await RemoteApiHelper.instance.addSaving(title: 'Mua xe', target: 5e7);

        expect(changes, 1);
      },
    );

    test('a refused request throws and tells nobody', () async {
      backend.on('POST', _list, (_) => jsonResponse(400, {'code': 400}));
      var changes = 0;
      void count() => changes++;
      RemoteApiHelper.instance.dataChangedNotifier.addListener(count);
      addTearDown(
        () =>
            RemoteApiHelper.instance.dataChangedNotifier.removeListener(count),
      );

      await expectLater(
        RemoteApiHelper.instance.addSaving(title: 'Mua xe', target: 5e7),
        throwsA(isA<DioException>()),
      );
      expect(changes, 0);
    });
  });

  group('contributeToSaving', () {
    test('posts the amount and returns the goal as it is now', () async {
      backend.on(
        'POST',
        _contributions,
        (_) => okResponse(_goal(current: 3000000)),
      );
      var changes = 0;
      void count() => changes++;
      RemoteApiHelper.instance.dataChangedNotifier.addListener(count);
      addTearDown(
        () =>
            RemoteApiHelper.instance.dataChangedNotifier.removeListener(count),
      );

      final goal = await RemoteApiHelper.instance.contributeToSaving(
        '7',
        500000,
      );

      expect(backend.requests.single.data, {'amount': 500000.0});
      expect(goal, isA<SavingsGoal>());
      expect(goal.id, '7');
      expect(goal.current, 3000000);
      expect(changes, 1);
    });

    final failures = {
      'a refused request': () => jsonResponse(400, {'code': 400}),
      'an answer without the goal': () => okResponse(null),
      'a goal that is not an object': () => okResponse('oops'),
    };
    failures.forEach((how, answer) {
      test('$how throws', () async {
        backend.on('POST', _contributions, (_) => answer());

        await expectLater(
          RemoteApiHelper.instance.contributeToSaving('7', 500000),
          throwsA(anything),
        );
      });
    });
  });

  group('fetchWalletBalance', () {
    test('reads walletBalance of the signed-in user', () async {
      backend.on(
        'GET',
        _me,
        (_) => okResponse({'id': 1, 'walletBalance': 12400000}),
      );

      expect(await RemoteApiHelper.instance.fetchWalletBalance(), 12400000.0);
      expect(backend.requests.single.path, _me);
    });

    test('a decimal balance keeps its decimals', () async {
      backend.on(
        'GET',
        _me,
        (_) => okResponse({'id': 1, 'walletBalance': 12.5}),
      );

      expect(await RemoteApiHelper.instance.fetchWalletBalance(), 12.5);
    });

    test('0 is a balance, a missing field is null', () async {
      backend.on('GET', _me, (_) => okResponse({'id': 1, 'walletBalance': 0}));
      expect(await RemoteApiHelper.instance.fetchWalletBalance(), 0.0);

      backend.on('GET', _me, (_) => okResponse({'id': 1}));
      expect(await RemoteApiHelper.instance.fetchWalletBalance(), isNull);
    });

    final failures = {
      'a refused request': () => jsonResponse(500, {'code': 500}),
      'a balance that is not a number': () =>
          okResponse({'id': 1, 'walletBalance': 'a lot'}),
    };
    failures.forEach((how, answer) {
      test('$how throws', () async {
        backend.on('GET', _me, (_) => answer());

        await expectLater(
          RemoteApiHelper.instance.fetchWalletBalance(),
          throwsA(anything),
        );
      });
    });
  });
}
