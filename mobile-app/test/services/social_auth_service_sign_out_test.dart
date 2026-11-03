import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:finance_ai_app/services/social_auth_service.dart';

/// Answers at once and keeps no Future between tests (see profile_logout_test.dart).
class _FakeGoogleSignIn implements GoogleSignIn {
  _FakeGoogleSignIn({this.fails = false});

  final bool fails;

  @override
  Future<GoogleSignInAccount?> disconnect() async {
    if (fails) throw PlatformException(code: 'sign_out_failed');
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_FakeGoogleSignIn does not fake ${invocation.memberName}',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const facebookChannel = MethodChannel('app.meedu/flutter_facebook_auth');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> facebookCalls;
  Object? facebookError;

  setUp(() {
    facebookCalls = [];
    facebookError = null;
    messenger.setMockMethodCallHandler(facebookChannel, (call) async {
      facebookCalls.add(call.method);
      if (facebookError != null) throw facebookError!;
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(facebookChannel, null));

  test('a Google failure does not stop the Facebook sign-out', () async {
    SocialAuthService.instance.googleSignIn = _FakeGoogleSignIn(fails: true);
    await SocialAuthService.instance.signOut();
    expect(facebookCalls, contains('logOut'));
  });

  test('a Facebook failure does not make signOut throw', () async {
    SocialAuthService.instance.googleSignIn = _FakeGoogleSignIn();
    facebookError = PlatformException(code: 'boom');
    await SocialAuthService.instance.signOut();
    expect(facebookCalls, contains('logOut'));
  });
}
