import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/screens/main_tabs.dart';

void main() {
  tearDown(() {
    final scanner = MainTabs.scanner;
    if (scanner != null) MainTabs.detachScanner(scanner);
  });

  test('no scanner is attached without a MainScaffold', () {
    expect(MainTabs.scanner, isNull);
  });

  test('the attached scanner is the one handed out', () {
    var opened = 0;
    void open() => opened++;
    MainTabs.attachScanner(open);

    MainTabs.scanner!();

    expect(opened, 1);
    MainTabs.detachScanner(open);
    expect(MainTabs.scanner, isNull);
  });

  test('an older scanner detaching does not cut off a newer one', () {
    var newer = 0;
    void older() {}
    void current() => newer++;
    MainTabs.attachScanner(older);
    MainTabs.attachScanner(current);

    MainTabs.detachScanner(older);
    MainTabs.scanner!();

    expect(newer, 1);
  });
}
