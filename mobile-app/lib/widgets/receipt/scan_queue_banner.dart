import 'dart:math';

import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/screens/receipt_scanner/pending_receipts_screen.dart';
import 'package:finance_ai_app/services/receipt_scan_queue.dart';

/// The bar above the tabs of MainScaffold that tells how far the scan queue has come: the receipt being read while it
/// reads, then how many wait for a confirmation. A tap opens [PendingReceiptsScreen]. With nothing in the queue it
/// takes no room at all. Only this widget rebuilds when the progress changes.
class ScanQueueBanner extends StatelessWidget {
  /// Handed to the review forms opened from the pending list, to show a saved transaction in the Ledger.
  final ValueChanged<int>? onOpenTransaction;

  const ScanQueueBanner({super.key, this.onOpenTransaction});

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
        return _BannerCard(
          progress: progress,
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PendingReceiptsScreen(onOpenTransaction: onOpenTransaction),
            ),
          ),
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  static const double _radius = 16;
  static const double _iconSize = 22;
  static const double _barHeight = 4;

  /// Room left under the card for the scan button, which is docked into the tab bar and rises above it.
  static const EdgeInsets _margin = EdgeInsets.fromLTRB(16, 8, 16, 20);

  final ScanQueueProgress progress;
  final VoidCallback onTap;

  const _BannerCard({required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;
    final onlyFailed = !progress.isReading && progress.ready == 0;
    final accent = onlyFailed ? colors.error : colors.primary;

    final String label;
    final IconData icon;
    if (progress.isReading) {
      // The receipt being read, counted from 1: the run shows 1/5 ... 5/5.
      final current = min(progress.done + 1, progress.total);
      label = loc.scanQueueReading(current, progress.total);
      icon = Icons.document_scanner_rounded;
    } else if (progress.ready > 0) {
      label = loc.scanQueueReady(progress.ready);
      icon = Icons.receipt_long_rounded;
    } else {
      label = loc.scanQueueFailed(progress.failed);
      icon = Icons.error_outline_rounded;
    }

    return Padding(
      padding: _margin,
      child: Material(
        color: Color.alphaBlend(accent.withValues(alpha: 0.10), colors.surface),
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(icon, color: accent, size: _iconSize),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: accent),
                  ],
                ),
                if (progress.isReading) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_barHeight),
                    child: LinearProgressIndicator(
                      value: progress.done / progress.total,
                      minHeight: _barHeight,
                      color: accent,
                      backgroundColor: accent.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
