import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/screens/ledger/widgets/transaction_form_fields.dart';

/// A field of the receipt review form (T9 spec, 3.1), with [label] above it unless the field carries its own label on
/// its border. When the AI is not sure of it ([needsCheck]) the field gets a dashed outline in the warning colour,
/// "Cần kiểm tra" at the end of the label row and [hint] under it.
class NeedsCheckField extends StatelessWidget {
  const NeedsCheckField({
    super.key,
    this.label,
    required this.child,
    this.needsCheck = false,
    this.hint,
    this.required = false,
  });

  static const double _radius = 14;

  final String? label;
  final Widget child;
  final bool needsCheck;
  final String? hint;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final warning = context.colors.warningColor;
    final loc = context.loc;
    final hint = this.hint;
    final label = this.label;
    // Every slot stays in place whether the field is doubted or not: [child] is never moved to another parent, so a
    // text field keeps its focus and keyboard when the first keystroke clears the mark.
    final showHeader = label != null || needsCheck;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: showHeader ? 8 : 0),
          child: !showHeader
              ? const SizedBox.shrink()
              : Row(
                  children: [
                    Expanded(
                      child: label == null
                          ? const SizedBox.shrink()
                          : FormFieldLabel(label, required: required),
                    ),
                    if (needsCheck) ...[
                      Icon(
                        Icons.error_outline_rounded,
                        size: 14,
                        color: warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        loc.reviewNeedsCheck,
                        style: TextStyle(
                          color: warning,
                          fontSize: AppTextSize.caption,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        CustomPaint(
          foregroundPainter: needsCheck
              ? DashedOutlinePainter(color: warning, radius: _radius)
              : null,
          child: child,
        ),
        Padding(
          padding: EdgeInsets.only(top: needsCheck && hint != null ? 6 : 0),
          child: needsCheck && hint != null
              ? Text(
                  hint,
                  style: TextStyle(
                    color: warning,
                    fontSize: AppTextSize.caption,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// A rounded rectangle drawn in dashes around its child.
class DashedOutlinePainter extends CustomPainter {
  const DashedOutlinePainter({required this.color, required this.radius});

  static const double _dash = 5;
  static const double _gap = 4;
  static const double _stroke = 1.5;

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in outline.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += _dash + _gap) {
        canvas.drawPath(metric.extractPath(at, at + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedOutlinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
