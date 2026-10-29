import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/cubits/amount_visibility_cubit.dart';

import '../helpers/fake_settings_repository.dart';

void main() {
  AmountVisibilityCubit cubitFor(FakeSettingsRepository settings) {
    final cubit = AmountVisibilityCubit(settings);
    addTearDown(cubit.close);
    return cubit;
  }

  test('starts from the saved value and toggle saves the new one', () async {
    final settings = FakeSettingsRepository()..amountsHidden = false;
    final cubit = cubitFor(settings);
    expect(cubit.state, isFalse);

    expect(await cubit.toggle(), isTrue);

    expect(cubit.state, isTrue);
    expect(settings.amountsHidden, isTrue);
    expect(settings.saved, [true]);
  });

  test('a failed save still toggles on screen', () async {
    final settings = FakeSettingsRepository(saveResult: false);
    final cubit = cubitFor(settings);
    expect(cubit.state, isTrue);

    expect(await cubit.toggle(), isFalse);

    expect(cubit.state, isFalse);
  });
}
