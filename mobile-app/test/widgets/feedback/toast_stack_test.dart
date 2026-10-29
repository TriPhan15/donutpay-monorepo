import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/widgets/feedback/toast_stack.dart';

void main() {
  late ToastStack stack;

  setUp(() => stack = ToastStack());
  tearDown(() => stack.dispose());

  ToastEntryData push(String message, {String? actionLabel}) => stack.push(
    kind: AppToastKind.info,
    message: message,
    actionLabel: actionLabel,
    onAction: actionLabel == null ? null : () {},
  );

  test('push puts the newest first', () {
    push('A');
    push('B');

    expect(stack.items.map((item) => item.message), ['B', 'A']);
  });

  test('a fourth push drops the oldest', () {
    final oldest = push('A');
    push('B');
    push('C');
    push('D');

    expect(stack.items, hasLength(ToastStack.maxLayers));
    expect(stack.items.map((item) => item.id), isNot(contains(oldest.id)));
    expect(stack.items.first.message, 'D');
  });

  test('removing the last item collapses the stack', () {
    final a = push('A');
    final b = push('B');
    stack.expand();
    expect(stack.expanded, isTrue);

    stack.remove(a.id);
    stack.remove(b.id);

    expect(stack.items, isEmpty);
    expect(stack.expanded, isFalse);
  });

  test('a list left with one toast folds back, so its timer runs again', () {
    final a = push('A');
    push('B');
    stack.expand();

    stack.remove(a.id);

    expect(stack.items, hasLength(1));
    expect(stack.expanded, isFalse);
  });

  test('clear empties and collapses', () {
    push('A');
    push('B');
    stack.expand();
    var notified = 0;
    stack.addListener(() => notified++);

    stack.clear();

    expect(stack.items, isEmpty);
    expect(stack.expanded, isFalse);
    expect(notified, 1);
  });

  test('holdFor is 3 s without a button and 5 s with one', () {
    expect(push('A').holdFor, const Duration(seconds: 3));
    expect(
      push('B', actionLabel: 'Thử lại').holdFor,
      const Duration(seconds: 5),
    );
  });

  test('ids are unique, even after a removal', () {
    final a = push('A');
    stack.remove(a.id);
    final b = push('B');

    expect(b.id, isNot(a.id));
  });

  group('toastAge', () {
    final vi = lookupAppLocalizations(const Locale('vi'));
    final en = lookupAppLocalizations(const Locale('en'));

    test('speaks Vietnamese', () {
      String age(int seconds) => toastAge(vi, Duration(seconds: seconds));
      expect(age(0), 'vừa xong');
      expect(age(4), 'vừa xong');
      expect(age(5), '5 giây trước');
      expect(age(59), '59 giây trước');
      expect(age(60), '1 phút trước');
      expect(age(125), '2 phút trước');
    });

    test('speaks English', () {
      expect(toastAge(en, Duration.zero), 'just now');
      expect(toastAge(en, const Duration(seconds: 12)), '12s ago');
      expect(toastAge(en, const Duration(minutes: 3)), '3 min ago');
    });
  });
}
