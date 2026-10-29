import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';

/// What the round button at the start of a [PageBand] does: go back, or close a form.
enum PageBandAction { back, close }

/// The thin blue band at the top of a secondary page (T9 spec, 2.3): the gradient without decoration, a round white
/// translucent button and the title in 18.
class PageBand extends StatelessWidget {
  const PageBand({
    super.key,
    required this.title,
    this.action = PageBandAction.back,
    this.buttonKey,
    this.onAction,
  });

  static const double _gutter = 16;
  static const double _radius = 28;
  static const double _buttonSize = 36;
  static const double _iconSize = 20;

  final String title;
  final PageBandAction action;
  final Key? buttonKey;

  /// Called by the button; closes the page ([Navigator.maybePop]) when null.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final material = MaterialLocalizations.of(context);
    final isClose = action == PageBandAction.close;
    return Container(
      padding: EdgeInsets.fromLTRB(_gutter, 12 + topInset, _gutter, 16),
      decoration: BoxDecoration(
        gradient: context.colors.headerGradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(_radius),
        ),
      ),
      child: Row(
        children: [
          Material(
            color: BandColors.tint,
            shape: const CircleBorder(),
            child: InkWell(
              key: buttonKey,
              customBorder: const CircleBorder(),
              onTap: onAction ?? () => Navigator.maybePop(context),
              child: SizedBox(
                width: _buttonSize,
                height: _buttonSize,
                child: Icon(
                  isClose ? Icons.close_rounded : Icons.arrow_back_rounded,
                  color: BandColors.primary,
                  size: _iconSize,
                  semanticLabel: isClose
                      ? material.closeButtonTooltip
                      : material.backButtonTooltip,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BandColors.primary,
                fontSize: AppTextSize.pageTitle,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
