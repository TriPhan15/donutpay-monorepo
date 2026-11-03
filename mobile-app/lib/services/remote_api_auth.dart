part of 'remote_api_helper.dart';

/// Sign-in, registration, password recovery and sign-out.
extension RemoteApiAuth on RemoteApiHelper {
  /// Throws the [DioException] as it is: the screen tells a lost connection, a 5xx and a 401 apart (UserFacingError).
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post(
      RemoteApiHelper._loginPath,
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
      RemoteApiHelper._socialLoginPath,
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
      RemoteApiHelper._registerPath,
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

  Future<void> forgotPassword({required String email}) async {
    await _dio.post(
      RemoteApiHelper._forgotPasswordPath,
      queryParameters: {'email': email},
    );
  }

  /// Completes the reset started by [forgotPassword]. The OTP and the new password travel in the JSON body, never in
  /// the query string, so they cannot end up in server or proxy access logs.
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _dio.post(
      RemoteApiHelper._resetPasswordPath,
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
      RemoteApiHelper._changePasswordPath,
      data: {'oldPassword': currentPassword, 'newPassword': newPassword},
    );
    final pair = RemoteApiHelper._tokenPairOf(res.data);
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
          .post(
            RemoteApiHelper._logoutPath,
            data: {'refreshToken': ?refreshToken},
          )
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
}
