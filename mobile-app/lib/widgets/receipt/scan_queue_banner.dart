import 'dart:math';

import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/screens/receipt_scanner/pending_receipts_screen.dart';
import 'package:finance_ai_app/services/receipt_scan_queue.dart';

/// The strip at the foot of the home band that tells how far the scan queue has come: the receipt being read while it
/// reads, then how many wait for a confirmation. A tap opens [PendingReceiptsScreen]. With nothing in the queue it
/// takes no room at all. Only this widget rebuilds when the progress changes.
class ScanQueueBanner extends StatelessWidget {
  /// Handed to the review forms opened from the pending list, to show a saved transaction in the Ledger.
  final ValueChanged<int>? onOpenTransaction;

  /// Room around the strip, kept only while it shows.
  final EdgeInsetsGeometry padding;

  const ScanQueueBanner({
    super.key,
    this.onOpenTransaction,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ScanQueueProgress>(
      valueListenable: ReceiptScanQueue.instance.progress,
      builder: (context, progress, _) {
        if (!progress.isReading &&
            progress.ready == 0 &&
            progress.failed == 0) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: padding,
          child: _BannerCard(
            progress: progress,
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PendingReceiptsScreen(onOpenTransaction: onOpenTransaction),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The strip itself (T9 C2/D1): one line on a solid surface at the foot of the home band, its text and icon in the
/// colour of the state, and a thin progress bar along its bottom edge while a receipt is being read.
class _BannerCard extends StatelessWidget {
  static const double _height = 40;
  static const double _radius = 14;
  static const double _iconSize = 18;
  static const double _barHeight = 3;

  final ScanQueueProgress progress;
  final VoidCallback onTap;

  const _BannerCard({required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;

    final String label;
    final IconData icon;
    final Color accent;
    if (progress.isReading) {
      // The receipt being read, counted from 1: the run shows 1/5 ... 5/5.
      final current = min(progress.done + 1, progress.total);
      label = loc.scanQueueReading(current, progress.total);
      icon = Icons.document_scanner_rounded;
      // The deep blue of the light theme reads best on white; the dark surface takes the bright primary.
      accent = theme.brightness == Brightness.light
          ? colors.onPrimaryContainer
          : colors.primary;
    } else if (progress.ready > 0) {
      label = loc.scanQueueReady(progress.ready);
      icon = Icons.receipt_long_rounded;
      accent = context.colors.successColor;
    } else {
      label = loc.scanQueueFailed(progress.failed);
      icon = Icons.error_outline_rounded;
      accent = colors.error;
    }

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _height),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                child: Row(
                  children: [
                    Icon(icon, color: accent, size: _iconSize),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontSize: AppTextSize.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: accent,
                      size: _iconSize + 2,
                    ),
                  ],
                ),
              ),
              if (progress.isReading)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: progress.done / progress.total,
                    minHeight: _barHeight,
                    color: colors.primary,
                    backgroundColor: colors.primary.withValues(alpha: 0.15),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
