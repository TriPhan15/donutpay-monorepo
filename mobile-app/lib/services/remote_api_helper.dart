import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
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
import 'package:finance_ai_app/models/spending_analysis.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:finance_ai_app/main.dart';
import 'package:finance_ai_app/screens/auth/login_page.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

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

  /// Throws the [DioException] as it is: the screen tells a lost connection, a 5xx and a 401 apart (UserFacingError).
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post(
      _loginPath,
      data: {'email': email, 'password': password},
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String token,
    String? email,
    String? name,
    String? avatar,
  }) async {
    final res = await _dio.post(
      _socialLoginPath,
      data: {
        'provider': provider,
        'token': token,
        'email': ?email,
        'name': ?name,
        'avatar': ?avatar,
      },
    );

    var responseData = res.data;
    if (responseData is String) {
      responseData = jsonDecode(responseData);
    }
    return Map<String, dynamic>.from(responseData);
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final res = await _dio.post(
      _registerPath,
      data: {
        'username': email,
        'email': email,
        'password': password,
        'fullName': fullName,
        'phone': ?phone,
      },
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> createPayment({
    required String type,
    required double amount,
    String provider = 'MOCK',
    String? description,
  }) async {
    final res = await _dio.post(
      '/api/payment/create',
      data: {
        'type': type,
        'amount': amount,
        'provider': provider,
        'description': ?description,
      },
    );
    return Map<String, dynamic>.from(res.data['data'] ?? {});
  }

  Future<Map<String, dynamic>> paymentStatus(String orderCode) async {
    final res = await _dio.get('/api/payment/status/$orderCode');
    return Map<String, dynamic>.from(res.data['data'] ?? {});
  }

  Future<List<Map<String, dynamic>>> paymentHistory() async {
    final res = await _dio.get('/api/payment/mine');
    return List<Map<String, dynamic>>.from(res.data['data'] ?? []);
  }

  Future<Map<String, dynamic>> cancelPayment(String orderCode) async {
    final res = await _dio.put('/api/payment/cancel/$orderCode');
    return Map<String, dynamic>.from(res.data['data'] ?? {});
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      final response = await _dio.get('/api/categories');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('data')) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        }
      }
    } catch (e) {
      debugPrint('Lỗi tải danh mục từ Backend bằng Dio: $e');
    }
    return [];
  }

  Future<List<TransactionModel>> fetchTransactions() async {
    final res = await _dio.get('/api/transactions/mine');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map(
          (e) => TransactionModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// Ids of the transactions of the user that match [query], best match first, from GET /api/transactions/search
  /// (Elasticsearch, or PostgreSQL when it is down). [size] is at most 50, the limit of the backend.
  Future<List<int>> searchTransactionIds(String query, {int size = 50}) async {
    final res = await _dio.get(
      '/api/transactions/search',
      queryParameters: {'q': query, 'page': 0, 'size': size},
    );
    final items = (res.data['data']['items'] as List?) ?? [];
    return [
      for (final item in items)
        if (item is Map && item['id'] is num) (item['id'] as num).toInt(),
    ];
  }

  Future<Map<String, dynamic>> fetchMe() async {
    final res = await _dio.get('/api/users/me');
    return Map<String, dynamic>.from(res.data['data'] ?? {});
  }

  Future<void> addTransaction(
    Map<String, dynamic> data, {
    String? imagePath,
  }) async {
    if (imagePath != null && imagePath.isNotEmpty) {
      try {
        final imageUrl = await uploadImage(imagePath);
        if (imageUrl != null) {
          data['imageUrl'] = imageUrl;
        }
      } catch (e) {
        debugPrint("Lỗi upload ảnh lên Cloudinary: $e");
      }
    }
    // No notifyDataChanged here: AppRepository announces the write once it has flagged the outbox row, otherwise a
    // reload started now would still list the row as waiting.
    await _dio.post('/api/transactions/checkout', data: data);
  }

  /// PUT /api/transactions/{id}: only the fields in [data] change (amount, categoryName, note ...) and the server keeps
  /// the wallet in step. The owner comes from the login token. A refusal reaches the caller as a DioException.
  Future<void> updateTransaction(String id, Map<String, dynamic> data) async {
    await _dio.put('/api/transactions/$id', data: data);
    notifyDataChanged();
  }

  /// Downloads a file of another host (a receipt photo on the image CDN) into the temporary directory, without the
  /// login token, and returns its path; null when it could not be downloaded. The same URL lands in the same file.
  Future<String?> downloadToTemp(String url) async {
    final name = 'receipt_${url.hashCode.toUnsigned(32).toRadixString(16)}.jpg';
    final path = '${Directory.systemTemp.path}${Platform.pathSeparator}$name';
    try {
      final res = await _externalDio.get<List<int>>(url);
      await File(path).writeAsBytes(res.data!, flush: true);
      return path;
    } catch (e) {
      debugPrint('Không tải được ảnh $url: $e');
      return null;
    }
  }

  Future<String?> uploadImage(String imagePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imagePath,
          filename: imagePath.split(Platform.pathSeparator).last,
        ),
      });
      final res = await _dio.post('/api/upload', data: formData);

      if (res.data is Map) {
        if (res.data['url'] != null) {
          return res.data['url'].toString();
        } else if (res.data['data'] != null &&
            res.data['data']['url'] != null) {
          return res.data['data']['url'].toString();
        }
      }

      debugPrint(
        "FLUTTER: Backend không trả về link ảnh! Nội dung: ${res.data}",
      );
      return null;
    } catch (e) {
      debugPrint("LỖI UPLOAD ẢNH FLUTTER: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>> scanReceipt(String imagePath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imagePath,
        filename: imagePath.split(Platform.pathSeparator).last,
      ),
    });
    final res = await _mlDio.post('/donut/scan', data: formData);
    return Map<String, dynamic>.from(res.data);
  }

  Future<SpendingAnalysis> analyzeSpending(
    List<Map<String, dynamic>> transactions,
  ) async {
    final res = await _mlDio.post(
      '/spade/analyze',
      data: {'transactions': transactions},
    );
    final data = res.data;
    return data is Map
        ? SpendingAnalysis.fromJson(Map<String, dynamic>.from(data))
        : SpendingAnalysis.empty;
  }

  Future<Map<String, dynamic>> recommendBudget({
    required List<Map<String, dynamic>> transactions,
    double target = 0,
    double current = 0,
    int? monthsLeft,
    double? monthlyIncome,
    double? neededMonthly,
  }) async {
    final res = await _mlDio.post(
      '/spade/recommend',
      data: {
        'transactions': transactions,
        'target': target,
        'current': current,
        // ai-service reads a missing field as 0 (no monthly need); null would be refused: the field is an int.
        'months_left': ?monthsLeft,
        'monthly_income': ?monthlyIncome,
        'needed_monthly': ?neededMonthly,
      },
    );
    return Map<String, dynamic>.from(res.data);
  }

  /// PUT /api/users/{id} with the fields of core-backend's UserUpdateDto that a user may change; a field left null is
  /// not sent and the server keeps it. The server refuses an id that is not the caller's (JWT). Returns the updated user
  /// (UserResponseDto).
  Future<Map<String, dynamic>> updateUserProfile({
    required int userId,
    String? username,
    String? phone,
  }) async {
    final res = await _dio.put(
      '/api/users/$userId',
      data: {'username': ?username, 'phone': ?phone},
    );
    return Map<String, dynamic>.from(res.data['data'] ?? {});
  }

  Future<void> forgotPassword({required String email}) async {
    await _dio.post(_forgotPasswordPath, queryParameters: {'email': email});
  }

  /// Completes the reset started by [forgotPassword]. The OTP and the new password travel in the JSON body, never in
  /// the query string, so they cannot end up in server or proxy access logs.
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _dio.post(
      _resetPasswordPath,
      data: {'email': email, 'otp': otp, 'newPassword': newPassword},
    );
  }

  /// Changes the password of the logged-in user (the owner comes from the login token). The server answers 400 with a
  /// readable message when [currentPassword] is wrong or [newPassword] breaks the policy. A change ends every session of
  /// the account on every device, this one included, and hands back a new token pair: it is stored at once, so that
  /// this device stays signed in.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await _dio.put(
      _changePasswordPath,
      data: {'oldPassword': currentPassword, 'newPassword': newPassword},
    );
    final pair = _tokenPairOf(res.data);
    if (pair == null) {
      // The password has changed all the same; without a new pair the next request finds the session ended.
      debugPrint(
        'RemoteApiHelper: the change-password answer carries no token pair.',
      );
      return;
    }
    await SessionService.setTokens(pair.token, pair.refreshToken);
  }

  /// Longest the app waits for the server to revoke the tokens: signing out must not hang on a bad network.
  static const Duration _logoutTimeout = Duration(seconds: 5);

  /// Asks the server to revoke the stored access token and refresh token (POST /api/auth/logout). Best effort: a network
  /// error, a timeout, a 401 or a 5xx is only logged and never thrown, so the caller can always clear the local session
  /// and go to the login screen. Call it BEFORE SessionService.clearSession(), the request needs the stored tokens.
  Future<void> logout() async {
    if (SessionService.currentToken == null) return;
    final refreshToken = SessionService.currentRefreshToken;
    try {
      await _dio
          .post(_logoutPath, data: {'refreshToken': ?refreshToken})
          .timeout(_logoutTimeout);
    } on DioException catch (e) {
      debugPrint(
        'Logout: the server did not revoke the tokens (${e.response?.statusCode ?? e.type.name}).',
      );
    } on TimeoutException {
      debugPrint(
        'Logout: no answer from the server within ${_logoutTimeout.inSeconds}s.',
      );
    }
  }

  /// One page of the logged-in user's notifications, newest first (GET /api/notifications?page=&size=). The server
  /// fixes the order and takes the owner from the login token, so only the page is sent. A failure reaches the caller as
  /// a DioException, an answer that is not a page as a FormatException.
  Future<NotificationPage> getNotifications({
    required int page,
    required int size,
  }) async {
    final res = await _dio.get(
      '/api/notifications',
      queryParameters: {'page': page, 'size': size},
    );
    return NotificationPage.fromJson(_dataObject(res));
  }

  /// How many notifications of the logged-in user are unread (GET /api/notifications/unread-count).
  Future<int> getUnreadNotificationCount() async {
    final res = await _dio.get('/api/notifications/unread-count');
    return _dataCount(res);
  }

  /// Marks one notification as read (PATCH /api/notifications/{id}/read) and returns it as the server now has it. One
  /// that does not exist, or is not the user's, is a 404 DioException.
  Future<AppNotification> markNotificationRead(int id) async {
    final res = await _dio.patch('/api/notifications/$id/read');
    return AppNotification.fromJson(_dataObject(res));
  }

  /// Marks every unread notification of the logged-in user as read (PATCH /api/notifications/read-all) and returns
  /// how many changed.
  Future<int> markAllNotificationsRead() async {
    final res = await _dio.patch('/api/notifications/read-all');
    return _dataCount(res);
  }

  /// The `data` object of an ApiResponse.
  Map<String, dynamic> _dataObject(Response<dynamic> res) {
    final body = res.data;
    final data = body is Map ? body['data'] : null;
    if (data is! Map) {
      throw FormatException('The answer carries no data object', body);
    }
    return Map<String, dynamic>.from(data);
  }

  /// The `data` number of an ApiResponse.
  int _dataCount(Response<dynamic> res) {
    final body = res.data;
    final data = body is Map ? body['data'] : null;
    if (data is! num) {
      throw FormatException('The answer carries no count', body);
    }
    return data.toInt();
  }

  /// All budgets of the logged-in user, newest first. The owner comes from the login token, so nothing identifying
  /// the user is sent.
  Future<List<BudgetModel>> getBudgets() async {
    final res = await _dio.get('/api/budgets');
    final items = (res.data['data'] as List?) ?? [];
    return items
        .map(
          (item) =>
              BudgetModel.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<BudgetModel> createBudget(BudgetModel budget) async {
    final res = await _dio.post('/api/budgets', data: budget.toJson());
    notifyDataChanged();
    return BudgetModel.fromJson(
      Map<String, dynamic>.from(res.data['data'] as Map),
    );
  }

  Future<BudgetModel> updateBudget(BudgetModel budget) async {
    final res = await _dio.put(
      '/api/budgets/${budget.id}',
      data: budget.toJson(),
    );
    notifyDataChanged();
    return BudgetModel.fromJson(
      Map<String, dynamic>.from(res.data['data'] as Map),
    );
  }

  Future<void> deleteBudget(int budgetId) async {
    await _dio.delete('/api/budgets/$budgetId');
    notifyDataChanged();
  }

  /// The author is the caller of the request (JWT): the body carries no user id.
  Future<bool> submitAppReview(int rating, String comment) async {
    try {
      final res = await _dio.post(
        '/api/reviews',
        data: {'rating': rating, 'comment': comment},
      );
      return res.data['code'] == 200;
    } catch (e) {
      UserFacingError.log('submitAppReview', e);
      return false;
    }
  }

  Future<bool> deleteTransaction(String id) async {
    try {
      final res = await _dio.delete('/api/transactions/$id');
      notifyDataChanged();

      return res.data['code'] == 200;
    } catch (e) {
      debugPrint("LỖI XÓA GIAO DỊCH: $e");
      return false;
    }
  }

  /// Throws when the savings cannot be read, so a screen can tell "none" from "could not load".
  Future<List<Map<String, dynamic>>> fetchSavings() async {
    final res = await _dio.get('/api/savings');
    return List<Map<String, dynamic>>.from(res.data['data'] ?? []);
  }

  Future<void> addSaving(Map<String, dynamic> data) async {
    await _dio.post('/api/savings', data: data);
    notifyDataChanged();
  }

  /// PUT /api/savings/{id}: the name, target and deadline of a goal. The body never carries `current` (the server
  /// refuses it: the saved amount only moves through contributions). The server treats a missing [deadline] as "clear
  /// it", so a caller keeping the deadline must pass it.
  Future<void> updateSaving(
    String id, {
    required String title,
    required double target,
    String? deadline,
  }) async {
    await _dio.put(
      '/api/savings/$id',
      data: {'title': title, 'target': target, 'deadline': deadline},
    );
    notifyDataChanged();
  }

  Future<void> deleteSaving(String id) async {
    await _dio.delete('/api/savings/$id');
    notifyDataChanged();
  }

  /// POST /api/savings/{id}/contributions: moves [amount] from the wallet into the goal [id]. The server records it as
  /// an expense in the "Tiết kiệm" category, so the balance and the Ledger change too. Returns the goal as it is now
  /// (`{id, title, target, current, deadline}`); throws when it is refused (e.g. 400 when the wallet is too low).
  Future<Map<String, dynamic>> contributeToSaving(
    String id,
    double amount,
  ) async {
    final res = await _dio.post(
      '/api/savings/$id/contributions',
      data: {'amount': amount},
    );
    notifyDataChanged();
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }
}
