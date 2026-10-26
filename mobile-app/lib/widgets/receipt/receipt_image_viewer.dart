import 'dart:io';

import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';

/// The photo of a receipt that can be zoomed: pinch with two fingers, or double-tap to zoom in on that spot and
/// double-tap again to see the whole photo. The photo keeps its own colours in both themes: no filter over it.
class ZoomableReceiptImage extends StatefulWidget {
  const ZoomableReceiptImage({super.key, required this.imagePath});

  /// How far a double tap zooms in, and how far a pinch may go.
  static const double doubleTapScale = 2.5;
  static const double maxScale = 5;

  final String imagePath;

  @override
  State<ZoomableReceiptImage> createState() => _ZoomableReceiptImageState();
}

class _ZoomableReceiptImageState extends State<ZoomableReceiptImage> {
  final TransformationController _transformation = TransformationController();
  Offset _doubleTapAt = Offset.zero;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_transformation.value.getMaxScaleOnAxis() > 1) {
      _transformation.value = Matrix4.identity();
      return;
    }
    const scale = ZoomableReceiptImage.doubleTapScale;
    // Zooms in around the tapped point: it stays under the finger.
    _transformation.value = Matrix4.identity()
      ..translateByDouble(
        -_doubleTapAt.dx * (scale - 1),
        -_doubleTapAt.dy * (scale - 1),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transformation,
        maxScale: ZoomableReceiptImage.maxScale,
        child: Center(
          child: Image.file(
            File(widget.imagePath),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              Icons.image_not_supported,
              size: 48,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The photo of a receipt over the whole screen, to read what the AI read. Always dark, like a photo viewer, so the
/// photo stands out in both themes.
class ReceiptImageViewerPage extends StatelessWidget {
  const ReceiptImageViewerPage({super.key, required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final scrim = Theme.of(context).colorScheme.scrim;
    return Scaffold(
      backgroundColor: scrim,
      appBar: AppBar(
        backgroundColor: scrim,
        foregroundColor: Colors.white,
        title: Text(context.loc.reviewOpenImage),
      ),
      body: SafeArea(child: ZoomableReceiptImage(imagePath: imagePath)),
    );
  }
}
