import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';

/// The ways of bringing receipts in, in the order of the sheet.
enum ScanOption { cameraOne, galleryOne, cameraMany, galleryMany }

/// The scan sheet (T9 spec, 3.1, layout 17): four rows with an icon, a name and a line that explains it. Closes itself
/// and returns the picked option, or null when dismissed.
Future<ScanOption?> showScanOptionsSheet(BuildContext context) {
  return showModalBottomSheet<ScanOption>(
    context: context,
    // Four explained rows are taller than the default 9/16 of the screen: the sheet takes the height it needs.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ScanOptionsSheet(),
  );
}

class _ScanOptionsSheet extends StatelessWidget {
  const _ScanOptionsSheet();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final options = [
      (
        ScanOption.cameraOne,
        Icons.document_scanner_rounded,
        loc.scanOptionCamera,
        loc.scanOptionCameraHint,
      ),
      (
        ScanOption.galleryOne,
        Icons.photo_library_rounded,
        loc.scanOptionGallery,
        loc.scanOptionGalleryHint,
      ),
      (
        ScanOption.cameraMany,
        Icons.burst_mode_rounded,
        loc.scanOptionBatch,
        loc.scanOptionBatchHint,
      ),
      (
        ScanOption.galleryMany,
        Icons.collections_rounded,
        loc.scanOptionBatchGallery,
        loc.scanOptionBatchGalleryHint,
      ),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              loc.scanSheetTitle,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: AppTextSize.title,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              loc.scanSheetSubtitle,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: AppTextSize.secondary,
              ),
            ),
            const SizedBox(height: 12),
            for (final (option, icon, title, hint) in options)
              _OptionRow(
                icon: icon,
                title: title,
                hint: hint,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  static const double _tileSize = 40;
  static const double _tileRadius = 12;

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_tileRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: _tileSize,
              height: _tileSize,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(_tileRadius),
              ),
              child: Icon(icon, color: colors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: AppTextSize.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: AppTextSize.secondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
