import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Architecture rules from `mobile-app/CLAUDE.md`, checked by scanning `lib/` as text.
///
/// Every allowlist below is legacy: it may only shrink. A new violation fails the test, and so does a listed file
/// that no longer violates (remove it from the list).
void main() {
  group('architecture rules', () {
    test('screens and widgets never import dio (use RemoteApiHelper or a repository)', () {
      _expectRule(
        description: 'imports package:dio from lib/screens or lib/widgets',
        violators: _dartFiles(under: const ['lib/screens/', 'lib/widgets/'], containing: _dioImport),
        allowlist: _dioImportAllowlist,
      );
    });

    test('no Color(0x...) hex literals outside lib/core/theme (use context.colors)', () {
      _expectRule(
        description: 'uses a Color(0x...) hex literal outside lib/core/theme/',
        violators: _dartFiles(under: const ['lib/'], excluding: const ['lib/core/theme/'], containing: _hexColor),
        allowlist: _hexColorAllowlist,
      );
    });

    test('no print( / debugPrint( in lib (log through a shared helper or show a toast)', () {
      _expectRule(
        description: 'calls print( or debugPrint(',
        violators: _dartFiles(under: const ['lib/'], containing: _printCall),
        allowlist: _printAllowlist,
      );
    });
  });
}

final RegExp _dioImport = RegExp(r'''import\s+['"]package:dio/''');
final RegExp _hexColor = RegExp(r'\bColor\(0x');
final RegExp _printCall = RegExp(r'(^|[^\w.])(print|debugPrint)\(');

// legacy: may only shrink
const List<String> _dioImportAllowlist = [
  'lib/screens/ai/ai_tab_page.dart',
  'lib/screens/auth/password_recovery_errors.dart',
  'lib/screens/budget/budget_screen.dart',
  'lib/screens/dashboard/dashboard_page.dart',
  'lib/screens/ledger/edit_transaction_page.dart',
  'lib/screens/notifications/notification_screen.dart',
  'lib/screens/profile/account_credentials_screen.dart',
  'lib/widgets/receipt/receipt_detail_sheet.dart',
];

// legacy: may only shrink
const List<String> _hexColorAllowlist = [
  'lib/widgets/auth/auth_form_layout.dart',
  'lib/widgets/auth/auth_social_buttons.dart',
];

// legacy: may only shrink
const List<String> _printAllowlist = [
  'lib/core/constants/transaction_categories.dart',
  'lib/core/utils/user_facing_error.dart',
  'lib/main.dart',
  'lib/models/app_notification.dart',
  'lib/repositories/app_repository.dart',
  'lib/repositories/settings_repository_impl.dart',
  'lib/screens/ai/ai_tab_page.dart',
  'lib/screens/auth/password_recovery_errors.dart',
  'lib/screens/budget/budget_form_sheet.dart',
  'lib/screens/budget/budget_screen.dart',
  'lib/screens/dashboard/dashboard_page.dart',
  'lib/screens/ledger/add_transaction_page.dart',
  'lib/screens/ledger/ledger_page.dart',
  'lib/screens/ledger/transaction_detail_page.dart',
  'lib/screens/notifications/notification_screen.dart',
  'lib/screens/profile/profile_page.dart',
  'lib/screens/receipt_scanner/pending_receipts_screen.dart',
  'lib/screens/receipt_scanner/receipt_submitter.dart',
  'lib/screens/receipt_scanner/review_form_page.dart',
  'lib/services/budget_alert_tracker.dart',
  'lib/services/receipt_scan_queue.dart',
  'lib/services/remote_api_auth.dart',
  'lib/services/remote_api_helper.dart',
  'lib/services/remote_api_receipt.dart',
  'lib/services/session_service.dart',
  'lib/services/social_auth_service.dart',
  'lib/widgets/budget/budget_alert_presenter.dart',
  'lib/widgets/feedback/app_toast.dart',
  'lib/widgets/receipt/receipt_detail_sheet.dart',
  'lib/widgets/receipt/receipt_image_viewer.dart',
  'lib/widgets/receipt/receipt_scan_launcher.dart',
];

/// Paths (relative to the package root, `/` separated) of the `.dart` files under [under], minus [excluding], that
/// have at least one non-comment line matching [containing].
List<String> _dartFiles({
  required List<String> under,
  List<String> excluding = const [],
  required RegExp containing,
}) {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => file.path.replaceAll(r'\', '/'))
      .where((path) => path.endsWith('.dart'))
      .where((path) => under.any(path.startsWith))
      .where((path) => !excluding.any(path.startsWith))
      .where((path) => _hasMatchingCodeLine(File(path), containing))
      .toList()
    ..sort();
  return files;
}

bool _hasMatchingCodeLine(File file, RegExp pattern) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .any(pattern.hasMatch);

void _expectRule({
  required String description,
  required List<String> violators,
  required List<String> allowlist,
}) {
  final newViolations = violators.where((path) => !allowlist.contains(path)).toList();
  final staleEntries = allowlist.where((path) => !violators.contains(path)).toList();
  expect(
    newViolations,
    isEmpty,
    reason: 'New files that $description:\n${newViolations.join('\n')}',
  );
  expect(
    staleEntries,
    isEmpty,
    reason: 'Allowlisted files that no longer violate (remove them from the allowlist):\n${staleEntries.join('\n')}',
  );
}
