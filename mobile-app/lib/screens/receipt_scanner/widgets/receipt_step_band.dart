import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';

/// The band of the receipt review form (T9 spec, 3.1): "Xác nhận hóa đơn", the "Đối chiếu" pill and the steps
/// Ảnh → Kiểm tra → Lưu, the photo done and the check under way. Without [onToggleCompare] the pill is left out
/// (while the photo is being read).
class ReceiptStepBand extends StatelessWidget {
  const ReceiptStepBand({
    super.key,
    required this.compareOn,
    required this.onToggleCompare,
  });

  @visibleForTesting
  static const Key compareKey = ValueKey('receipt-compare');

  final bool compareOn;
  final VoidCallback? onToggleCompare;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final toggle = onToggleCompare;
    return PageBand(
      title: loc.reviewTitle,
      trailing: toggle == null
          ? null
          : _ComparePill(on: compareOn, onTap: toggle),
      bottom: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            _Step(label: loc.reviewStepPhoto, state: _StepState.done),
            const _StepArrow(),
            _Step(
              number: 2,
              label: loc.reviewStepCheck,
              state: _StepState.current,
            ),
            const _StepArrow(),
            _Step(number: 3, label: loc.reviewStepSave, state: _StepState.next),
          ],
        ),
      ),
    );
  }
}

class _ComparePill extends StatelessWidget {
  const _ComparePill({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Semantics(
      button: true,
      toggled: on,
      label: on ? loc.reviewCompareOff : loc.reviewCompareOn,
      excludeSemantics: true,
      child: Material(
        color: BandColors.tint,
        shape: const StadiumBorder(),
        child: InkWell(
          key: ReceiptStepBand.compareKey,
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  on ? Icons.check_rounded : Icons.vertical_split_outlined,
                  size: 15,
                  color: BandColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  loc.reviewCompare,
                  style: const TextStyle(
                    color: BandColors.primary,
                    fontSize: AppTextSize.caption,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _StepState { done, current, next }

class _Step extends StatelessWidget {
  const _Step({this.number, required this.label, required this.state});

  static const double _dotSize = 18;

  final int? number;
  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final current = state == _StepState.current;
    final textColor = switch (state) {
      _StepState.done => BandColors.primary,
      _StepState.current => AppTheme.primaryDark,
      _StepState.next => BandColors.secondary,
    };
    final dot = Container(
      width: _dotSize,
      height: _dotSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: current ? AppTheme.primaryDark : BandColors.tint,
      ),
      child: state == _StepState.done
          ? const Icon(Icons.check_rounded, size: 12, color: BandColors.primary)
          : Text(
              '$number',
              style: const TextStyle(
                color: BandColors.primary,
                fontSize: AppTextSize.caption,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: current
          ? const ShapeDecoration(
              color: BandColors.primary,
              shape: StadiumBorder(),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: AppTextSize.caption,
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepArrow extends StatelessWidget {
  const _StepArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 14,
        color: BandColors.secondary,
      ),
    );
  }
}
