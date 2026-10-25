import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/repositories/app_repository.dart';

void main() {
  group('AppRepository.displayNameOf', () {
    test('the name of /me when it is not the email', () {
      expect(
        AppRepository.displayNameOf({
          'email': 'an@example.com',
          'username': 'Nguyễn Văn An',
        }),
        'Nguyễn Văn An',
      );
    });

    test(
      'the part before the @ when the username is the registration email or blank',
      () {
        expect(
          AppRepository.displayNameOf({
            'email': 'an@example.com',
            'username': 'an@example.com',
          }),
          'an',
        );
        expect(
          AppRepository.displayNameOf({
            'email': 'an@example.com',
            'username': ' ',
          }),
          'an',
        );
        expect(AppRepository.displayNameOf({'email': 'an@example.com'}), 'an');
      },
    );

    test('a default when there is neither', () {
      expect(AppRepository.displayNameOf({}), 'Người dùng');
    });
  });
}
