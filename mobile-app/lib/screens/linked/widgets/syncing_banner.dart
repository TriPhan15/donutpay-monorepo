import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/theme/app_typography.dart';

/// The line at the top of the linked services while a sync waits for the gateway (T9 spec 3.9, mockup M4): a small
/// spinner and "Đang đồng bộ … hoàn tất thanh toán trên cổng." on the primary container.
class SyncingBanner extends StatelessWidget {
  const SyncingBanner({super.key, required this.message});

  static const double _radius = 14;
  static const double _spinnerSize = 18;

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: _spinnerSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontSize: AppTextSize.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
