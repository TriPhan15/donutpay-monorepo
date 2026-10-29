import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:finance_ai_app/repositories/settings_repository.dart';

/// Whether the balance and the month totals are hidden (the state is true while they are). One instance sits above
/// every tab; the home tab reads it, and the statistics tab is meant to read the same one (T9 batch 4).
class AmountVisibilityCubit extends Cubit<bool> {
  AmountVisibilityCubit(this._settings) : super(_settings.amountsHidden);

  final SettingsRepository _settings;

  /// Hides or shows at once, then saves the choice. Returns false when saving failed; the choice stays applied anyway.
  Future<bool> toggle() {
    final hidden = !state;
    emit(hidden);
    return _settings.setAmountsHidden(hidden);
  }
}
