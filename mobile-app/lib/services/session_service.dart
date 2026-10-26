import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// The session could not be written to the device; the stored and the cached session are both left as they were.
class SessionStorageException implements Exception {
  const SessionStorageException(this.message);

  final String message;

  @override
  String toString() => 'SessionStorageException: $message';
}

/// Who is signed in, and the token pair of the backend. Stored as ONE JSON object under ONE key, so the user id, the
/// access token and the refresh token are always written together: a crash between two writes can no longer leave a new
/// access token next to an old refresh token. Inside the JSON the access token is "token", like in the login answer.
class SessionService {
  static const String _keySession = 'auth_session';
  static const String _fieldUserId = 'userId';
  static const String _fieldToken = 'token';
  static const String _fieldRefreshToken = 'refreshToken';
  static const String _fieldRemember = 'remember';

  /// The email of the last sign-in made with "remember me", kept apart from the session so that signing out leaves it:
  /// the login screen fills it in. Only the email: the password is left to the password manager of the system.
  static const String _keyRememberedEmail = 'remembered_email';

  // The format before the JSON session: one key per value. Read once to migrate, removed once the JSON session is stored.
  static const String _legacyKeyUserId = 'current_user_id';
  static const String _legacyKeyToken = 'auth_token';
  static const String _legacyKeyRefreshToken = 'refresh_token';
  static const List<String> _legacyKeys = [
    _legacyKeyUserId,
    _legacyKeyToken,
    _legacyKeyRefreshToken,
  ];

  static final ValueNotifier<bool> needRefreshAI = ValueNotifier(false);

  // Replaced as a whole, never field by field, so a reader never sees a token of one pair next to one of another.
  static _Session _session = _Session.empty;

  static Future<SharedPreferences> Function() _preferences =
      SharedPreferences.getInstance;

  /// Tests only: a storage whose writes can fail.
  @visibleForTesting
  static set preferences(Future<SharedPreferences> Function() load) =>
      _preferences = load;

  static int? get currentUserId => _session.userId;
  static String? get currentToken => _session.token;
  static String? get currentRefreshToken => _session.refreshToken;

  /// Loads the stored session at a cold start. A session signed in without "remember me" ends here: it lived only
  /// until the app was closed.
  static Future<void> init() async {
    final prefs = await _preferences();
    final stored = _Session.decode(prefs.getString(_keySession));
    if (stored != null && !stored.remember) {
      debugPrint(
        'SessionService: the last sign-in was not remembered, the session ends with the app restart.',
      );
      await clearSession();
      return;
    }
    if (stored != null) {
      _session = stored;
      // A migration that stored the JSON session but could not remove the old keys ends here.
      await _removeLegacyKeys(prefs);
      return;
    }
    await _migrateLegacySession(prefs);
  }

  /// Moves a session of the old format into the JSON session. The cache gets the three old values first, exactly what
  /// init() has always loaded, so nobody is signed out by the new format. The old keys are removed only once the JSON
  /// session is stored; when that fails they stay (the next start tries again) and the cache is left as loaded.
  static Future<void> _migrateLegacySession(SharedPreferences prefs) async {
    final legacy = _Session(
      userId: prefs.getInt(_legacyKeyUserId),
      token: prefs.getString(_legacyKeyToken),
      refreshToken: prefs.getString(_legacyKeyRefreshToken),
    );
    _session = legacy;
    if (legacy.isEmpty) return;

    if (!await _write(prefs, legacy)) {
      debugPrint(
        'SessionService: the session could not be moved to the new format, the old keys stay.',
      );
      return;
    }
    await _removeLegacyKeys(prefs);
  }

  static Future<void> setCurrentUserId(int userId) =>
      _replace(_session.copyWith(userId: userId));

  /// Replaces the token pair and keeps the signed-in user. The cache takes the new pair only once it is stored, so the
  /// app never runs on tokens that the next start would not find. Throws [SessionStorageException] when the write fails;
  /// storage and cache then both still hold the previous pair.
  /// [remember] is the "remember me" choice of a sign-in: false ends the session at the next cold start (init). A renewal
  /// leaves it out and keeps the choice of the session.
  static Future<void> setTokens(
    String token,
    String refreshToken, {
    bool? remember,
  }) => _replace(
    _session.copyWith(
      token: token,
      refreshToken: refreshToken,
      remember: remember,
    ),
  );

  static Future<void> _replace(_Session next) async {
    final prefs = await _preferences();
    if (!await _write(prefs, next)) {
      throw const SessionStorageException(
        'The session could not be saved on this device.',
      );
    }
    _session = next;
    await _removeLegacyKeys(prefs);
  }

  /// Signs out on this device. The cache is emptied first, so no request leaves with these tokens any more; then the
  /// JSON session and every key of the old format are removed.
  static Future<void> clearSession() async {
    _session = _Session.empty;
    final prefs = await _preferences();
    await prefs.remove(_keySession);
    await _removeLegacyKeys(prefs);
  }

  /// The email to fill in on the login screen, or null when none is remembered.
  static Future<String?> rememberedEmail() async {
    final prefs = await _preferences();
    final email = prefs.getString(_keyRememberedEmail)?.trim();
    return email == null || email.isEmpty ? null : email;
  }

  /// After a successful sign-in: keeps [email] when "remember me" was ticked, forgets the one kept before when [email]
  /// is null. Best effort: a failed write only means the field is not filled in next time, so it never fails a sign-in.
  static Future<void> rememberEmail(String? email) async {
    try {
      final prefs = await _preferences();
      final trimmed = email?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        await prefs.remove(_keyRememberedEmail);
      } else {
        await prefs.setString(_keyRememberedEmail, trimmed);
      }
    } on Exception catch (e) {
      debugPrint('SessionService: the remembered email could not be saved: $e');
    }
  }

  static Future<bool> isLoggedIn() async {
    return _session.userId != null;
  }

  static Future<bool> _write(SharedPreferences prefs, _Session session) async {
    try {
      return await prefs.setString(_keySession, session.encode());
    } on Exception catch (e) {
      debugPrint('SessionService: the session could not be written: $e');
      return false;
    }
  }

  /// Best effort: the JSON session is what counts once it is stored, and the next start tries again.
  static Future<void> _removeLegacyKeys(SharedPreferences prefs) async {
    try {
      for (final key in _legacyKeys) {
        if (prefs.containsKey(key)) await prefs.remove(key);
      }
    } on Exception catch (e) {
      debugPrint(
        'SessionService: the old session keys could not be removed: $e',
      );
    }
  }
}

@immutable
class _Session {
  const _Session({
    this.userId,
    this.token,
    this.refreshToken,
    this.remember = true,
  });

  static const _Session empty = _Session();

  final int? userId;
  final String? token;
  final String? refreshToken;

  /// Whether the session survives a restart of the app. Sessions stored before the choice existed have no such field
  /// and are remembered, as they always were.
  final bool remember;

  bool get isEmpty => userId == null && token == null && refreshToken == null;

  _Session copyWith({
    int? userId,
    String? token,
    String? refreshToken,
    bool? remember,
  }) => _Session(
    userId: userId ?? this.userId,
    token: token ?? this.token,
    refreshToken: refreshToken ?? this.refreshToken,
    remember: remember ?? this.remember,
  );

  /// All three keys, always: a value the session does not have (no tokens in local mode) is stored as null.
  String encode() => jsonEncode({
    SessionService._fieldUserId: userId,
    SessionService._fieldToken: token,
    SessionService._fieldRefreshToken: refreshToken,
    SessionService._fieldRemember: remember,
  });

  /// Null when nothing is stored, or when what is stored is not a session.
  static _Session? decode(String? stored) {
    if (stored == null) return null;
    final Object? data;
    try {
      data = jsonDecode(stored);
    } on FormatException {
      return null;
    }
    if (data is! Map) return null;
    final userId = data[SessionService._fieldUserId];
    final token = data[SessionService._fieldToken];
    final refreshToken = data[SessionService._fieldRefreshToken];
    final remember = data[SessionService._fieldRemember];
    return _Session(
      userId: userId is int ? userId : null,
      token: token is String ? token : null,
      refreshToken: refreshToken is String ? refreshToken : null,
      remember: remember is bool ? remember : true,
    );
  }
}
