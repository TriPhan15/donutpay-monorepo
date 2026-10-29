import 'dart:io';

import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';

/// The receipt photo at the top of the review form (T9 spec, 3.1): the width of the card at a fixed height, so a very
/// long or very wide photo never pushes the fields away, and a "Phóng to" pill; a tap anywhere opens the viewer.
class ReceiptPhotoHeader extends StatelessWidget {
  const ReceiptPhotoHeader({
    super.key,
    required this.imagePath,
    required this.onOpen,
  });

  static const double _height = 180;
  static const double _radius = 12;

  final String imagePath;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    return Semantics(
      button: true,
      label: loc.reviewOpenImage,
      // One clear label for screen readers instead of "Phóng to" read on its own.
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: SizedBox(
            height: _height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.broken_image_outlined,
                    size: 40,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.scrim.withValues(alpha: 0.55),
                      shape: const StadiumBorder(),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.zoom_in_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            loc.reviewZoom,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: AppTextSize.caption,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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
