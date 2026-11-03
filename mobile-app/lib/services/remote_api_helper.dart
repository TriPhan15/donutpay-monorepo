import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:finance_ai_app/config/app_config.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/di/injection_container.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/repositories/settings_repository.dart';
import 'package:finance_ai_app/services/language_interceptor.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/models/app_notification.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/receipt_detail.dart';
import 'package:finance_ai_app/models/savings_goal.dart';
import 'package:finance_ai_app/models/spending_analysis.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:finance_ai_app/main.dart';
import 'package:finance_ai_app/screens/auth/login_page.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

part 'remote_api_ai.dart';
part 'remote_api_auth.dart';
part 'remote_api_budget.dart';
part 'remote_api_notifications.dart';
part 'remote_api_payment.dart';
part 'remote_api_receipt.dart';
part 'remote_api_savings.dart';
part 'remote_api_transactions.dart';
part 'remote_api_user.dart';

/// The two tokens of a login, refresh or change-password answer.
typedef _TokenPair = ({String token, String refreshToken});

class RemoteApiHelper {
  static final RemoteApiHelper instance = RemoteApiHelper._();
  RemoteApiHelper._();

  static const String _loginPath = '/api/auth/login';
  static const String _socialLoginPath = '/api/auth/social-login';
  static const String _registerPath = '/api/auth/register';
  static const String _forgotPasswordPath = '/api/auth/forgot-password';
  static const String _resetPasswordPath = '/api/auth/reset-password';
  static const String _refreshPath = '/api/auth/refresh';
  static const String _changePasswordPath = '/api/auth/change-password';
  static const String _logoutPath = '/api/auth/logout';

  /// A 401 of these is never answered with a refresh and a retry: on the sign-in and recovery endpoints the 401 is the
  /// answer itself, the refresh cannot renew itself, and a logout ends the session anyway.
  static const Set<String> _pathsWithoutRenewal = {
    _loginPath,
    _socialLoginPath,
    _registerPath,
    _forgotPasswordPath,
    _resetPasswordPath,
    _refreshPath,
    _logoutPath,
  };

  static const String _authorizationHeader = 'Authorization';

  /// Marks a request repeated after a renewal, so that it is repeated at most once.
  static const String _repeatedAfterRenewal = 'repeatedAfterRenewal';

  late final Dio _dio;
  late final Dio _mlDio;
  // No interceptors: a 401 of the refresh itself must never come back into the renewal.
  late final Dio _refreshDio;
  // No interceptors and no base URL: files from other hosts (receipt photos) must never receive the login token.
  late final Dio _externalDio;

  bool _initialized = false;
  bool _languageInterceptorAttached = false;
  // Also picks the language of the toast shown when a session ends.
  SettingsRepository? _settings;
  // The renewal in flight: a 401 that arrives meanwhile waits for it instead of starting another refresh.
  Future<String?>? _renewal;

  /// Moves on after every write of the user's data (transactions, budgets, savings), on the server or in the outbox of
  /// this device. The tabs of MainScaffold stay alive in an IndexedStack, so they reload on it instead of in initState only.
  /// Writes move it through [notifyDataChanged], never directly, so a [batchDataChanges] can hold them back.
  final ValueNotifier<int> dataChangedNotifier = ValueNotifier(0);

  /// How many [batchDataChanges] are running inside one another, and whether a write came during them.
  int _batchDepth = 0;
  bool _changedDuringBatch = false;

  /// Announces one write of the user's data: [dataChangedNotifier] moves once, or once at the end of the
  /// [batchDataChanges] in progress.
  void notifyDataChanged() {
    if (_batchDepth > 0) {
      _changedDuringBatch = true;
      return;
    }
    dataChangedNotifier.value++;
  }

  /// Runs [body], in which several writes are made, and moves [dataChangedNotifier] once when it ends (also when it
  /// throws) if any of them announced a change, so the screens reload once instead of once per write. Batches may nest;
  /// only the outermost one moves the notifier.
  Future<T> batchDataChanges<T>(Future<T> Function() body) async {
    _batchDepth++;
    try {
      return await body();
    } finally {
      _batchDepth--;
      if (_batchDepth == 0 && _changedDuringBatch) {
        _changedDuringBatch = false;
        dataChangedNotifier.value++;
      }
    }
  }

  /// [httpClientAdapter] replaces the real network layer of the core API, of the AI service and of the token refresh; only
  /// tests pass it, the app calls init() with no arguments.
  /// [settingsRepository] is for tests as well: the app registers it in GetIt (configureDependencies) before init().
  /// Calling init() again only attaches the language interceptor if the first call could not, never a second time.
  void init({
    HttpClientAdapter? httpClientAdapter,
    SettingsRepository? settingsRepository,
  }) {
    if (_initialized) {
      _attachLanguageInterceptor(settingsRepository);
      return;
    }
    _initialized = true;

    final coreApiOptions = BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    );
    _dio = Dio(coreApiOptions);
    if (httpClientAdapter != null) _dio.httpClientAdapter = httpClientAdapter;
    // Same base as _dio: the paths already start with /api, so adding apiVersion here would call /api/api/...
    _refreshDio = Dio(coreApiOptions.copyWith());
    if (httpClientAdapter != null) {
      _refreshDio.httpClientAdapter = httpClientAdapter;
    }

    _externalDio = Dio(
      BaseOptions(
        connectTimeout: coreApiOptions.connectTimeout,
        receiveTimeout: coreApiOptions.receiveTimeout,
        responseType: ResponseType.bytes,
      ),
    );
    if (httpClientAdapter != null) {
      _externalDio.httpClientAdapter = httpClientAdapter;
    }

    _dio.interceptors.add(_sessionInterceptor(_dio));

    _mlDio = Dio(
      BaseOptions(
        baseUrl: AppConfig.mlApiUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
    if (httpClientAdapter != null) _mlDio.httpClientAdapter = httpClientAdapter;
    // The proxy in front of the AI service checks the same access token (forward_auth to core-api), so its requests get
    // the same header and the same renewal on 401.
    _mlDio.interceptors.add(_sessionInterceptor(_mlDio));
    _attachLanguageInterceptor(settingsRepository);
  }

  void _attachLanguageInterceptor(SettingsRepository? settingsRepository) {
    if (_languageInterceptorAttached) return;
    final settings =
        settingsRepository ??
        (sl.isRegistered<SettingsRepository>()
            ? sl<SettingsRepository>()
            : null);
    if (settings == null) {
      debugPrint(
        'RemoteApiHelper: SettingsRepository is not registered, requests go out without Accept-Language.',
      );
      return;
    }
    final interceptor = LanguageInterceptor(settings);
    _dio.interceptors.add(interceptor);
    _mlDio.interceptors.add(interceptor);
    _languageInterceptorAttached = true;
    _settings = settings;
  }

  static String _bearer(String token) => 'Bearer $token';

  /// Puts the current access token on every request of [client] and renews the session on a 401; the request is repeated
  /// on [client] itself, so an AI-service request goes back to the AI service.
  Interceptor _sessionInterceptor(Dio client) => InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = SessionService.currentToken;
      if (token != null) {
        options.headers[_authorizationHeader] = _bearer(token);
      }
      handler.next(options);
    },
    onError: (e, handler) => _renewSessionOn401(e, handler, client),
  );

  /// A 401 on a request that carried a session: the session is renewed once, however many requests failed together,
  /// and the request is repeated once with the newest token. When the session cannot be renewed the request fails with
  /// its own 401.
  Future<void> _renewSessionOn401(
    DioException e,
    ErrorInterceptorHandler handler,
    Dio client,
  ) async {
    if (!_mayRenew(e)) {
      handler.next(e);
      return;
    }
    final String? token;
    try {
      token = await _renewedAccessToken(e.requestOptions);
    } catch (error) {
      // The handler must be called whatever happens: Dio would wait for it forever.
      debugPrint('RemoteApiHelper: the session could not be renewed: $error');
      handler.next(e);
      return;
    }
    if (token == null) {
      handler.next(e);
      return;
    }
    try {
      handler.resolve(
        await client.fetch<dynamic>(_repeatable(e.requestOptions)),
      );
    } on DioException catch (repeatError) {
      // The repeat failed on its own (400, 500...): that is its answer, not a failed renewal, so the session stays.
      handler.next(repeatError);
    }
  }

  bool _mayRenew(DioException e) {
    final options = e.requestOptions;
    return e.response?.statusCode == HttpStatus.unauthorized &&
        !_pathsWithoutRenewal.contains(options.path) &&
        options.extra[_repeatedAfterRenewal] != true;
  }

  /// The access token to repeat [failed] with, or null when there is none to be had.
  Future<String?> _renewedAccessToken(RequestOptions failed) async {
    final current = SessionService.currentToken;
    // Signed out meanwhile, e.g. the renewal of another request was refused: no second refresh, no second redirect.
    if (current == null) return null;
    // Renewed by another request while this one was on its way: repeat it with the newest token, no second refresh.
    if (failed.headers[_authorizationHeader] != _bearer(current)) {
      return current;
    }
    return _renewSession();
  }

  /// One refresh for every 401 that arrives while it is out: the first starts it, the others get the same Future. The
  /// field is cleared in finally whatever the outcome, so a failed renewal is never handed to a later 401 (which starts
  /// afresh) and nothing waits on it forever.
  Future<String?> _renewSession() async {
    final inFlight = _renewal;
    if (inFlight != null) return inFlight;
    final renewal = Completer<String?>();
    _renewal = renewal.future;
    String? token;
    try {
      token = await _refreshTokens();
    } finally {
      _renewal = null;
      renewal.complete(token);
    }
    return token;
  }

  /// Trades the stored refresh token for a new pair and stores both tokens (the server uses the old refresh token up).
  /// Returns the new access token, or null. A refusal (4xx) ends the session. When the server cannot be reached or fails
  /// (5xx) nothing is known about the session, so it is kept and the waiting requests fail with their own error.
  Future<String?> _refreshTokens() async {
    final refreshToken = SessionService.currentRefreshToken;
    if (refreshToken == null) {
      await _endSession();
      return null;
    }
    _TokenPair? pair;
    try {
      final res = await _refreshDio.post(
        _refreshPath,
        data: {'refreshToken': refreshToken},
      );
      pair = _tokenPairOf(res.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == null || status >= HttpStatus.internalServerError) {
        debugPrint(
          'RemoteApiHelper: the session could not be renewed now (${status ?? e.type.name}), it is kept.',
        );
        return null;
      }
    }
    if (pair != null) {
      try {
        await SessionService.setTokens(pair.token, pair.refreshToken);
        return pair.token;
      } on SessionStorageException catch (e) {
        // The old refresh token is used up on the server and the new pair cannot be kept: the session is over.
        debugPrint('RemoteApiHelper: $e');
      }
    }
    if (SessionService.currentRefreshToken != refreshToken) {
      // The session changed while the refresh was out: renewed by a password change on this device (its pair is the one
      // to use), or ended by a logout (nothing left to end).
      return SessionService.currentToken;
    }
    await _endSession();
    return null;
  }

  /// Ends a session that cannot be renewed: clears it, opens the login screen and says why in a toast. It runs inside
  /// the one shared renewal, so however many requests failed together there is one redirect and one toast, and the
  /// 401s that come later find no session and just pass their error on. No BuildContext: both go through the navigator
  /// key, the toast through the navigator's overlay (inserted after the login route, so it shows above it).
  Future<void> _endSession() async {
    await SessionService.clearSession();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay != null) {
      AppToast.showOn(overlay, AppToastKind.info, _sessionEndedMessage());
    }
  }

  String _sessionEndedMessage() {
    final language = _settings?.language ?? AppLanguage.fallback;
    return lookupAppLocalizations(language.locale).sessionEnded;
  }

  /// [failed] once more, marked so that it is not renewed a second time; onRequest puts the newest token on it.
  RequestOptions _repeatable(RequestOptions failed) {
    final data = failed.data;
    return failed.copyWith(
      // A multipart body can be sent only once; the copy reads its files again.
      data: data is FormData ? data.clone() : data,
      extra: {...failed.extra, _repeatedAfterRenewal: true},
    );
  }

  /// data.token and data.refreshToken of an answer, or null when it does not carry both.
  static _TokenPair? _tokenPairOf(Object? body) {
    final data = body is Map ? body['data'] : null;
    if (data is! Map) return null;
    final token = data['token'];
    final refreshToken = data['refreshToken'];
    if (token is! String || token.isEmpty) return null;
    if (refreshToken is! String || refreshToken.isEmpty) return null;
    return (token: token, refreshToken: refreshToken);
  }
}
