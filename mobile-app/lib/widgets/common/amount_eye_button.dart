import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/cubits/amount_visibility_cubit.dart';

/// The eye that hides and shows the amounts of the home and statistics bands (T9 spec, 2.3), through the shared
/// [AmountVisibilityCubit]: a 30 px square to see, inside a 48 px area to tap.
class AmountEyeButton extends StatelessWidget {
  static const double _size = 30;
  static const double _tapSize = 48;

  final bool hidden;

  const AmountEyeButton({super.key, required this.hidden});

  /// What an amount shows while the amounts are hidden.
  static const String hiddenText = '••••••';

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Tooltip(
      message: hidden ? loc.dashboardShowAmounts : loc.dashboardHideAmounts,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.read<AmountVisibilityCubit>().toggle(),
        child: SizedBox.square(
          dimension: _tapSize,
          child: Center(
            child: Material(
              color: BandColors.tint,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox.square(
                dimension: _size,
                child: Icon(
                  hidden
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: BandColors.primary,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
