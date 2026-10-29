import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

/// The photo of a receipt that can be zoomed: pinch with two fingers, or double-tap to zoom in on that spot and
/// double-tap again to see the whole photo. The photo keeps its own colours in both themes: no filter over it.
///
/// The photo is a file on the device ([imagePath], a receipt being reviewed) or on the image host ([imageUrl], a
/// saved transaction): exactly one of the two.
class ZoomableReceiptImage extends StatefulWidget {
  const ZoomableReceiptImage({super.key, this.imagePath, this.imageUrl})
    : assert(
        (imagePath == null) != (imageUrl == null),
        'Give either imagePath or imageUrl.',
      );

  /// How far a double tap zooms in, and how far a pinch may go.
  static const double doubleTapScale = 2.5;
  static const double maxScale = 5;

  final String? imagePath;
  final String? imageUrl;

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
    Widget broken(BuildContext _, Object _, StackTrace? _) => Icon(
      Icons.image_not_supported,
      size: 48,
      color: colors.onSurfaceVariant,
    );
    final url = widget.imageUrl;
    final image = url != null
        ? Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : const AppStateView.loading(),
            errorBuilder: broken,
          )
        : Image.file(
            File(widget.imagePath!),
            fit: BoxFit.contain,
            errorBuilder: broken,
          );
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transformation,
        maxScale: ZoomableReceiptImage.maxScale,
        child: Center(child: image),
      ),
    );
  }
}

/// The photo of a receipt over the whole screen (T9 spec 3.11, R4): black, with Back, the title and one Share button.
/// The system share sheet also offers saving to Photos or Drive, so there is no separate save button.
class ReceiptImageViewerPage extends StatefulWidget {
  const ReceiptImageViewerPage({
    super.key,
    required String this.imagePath,
    this.shareFile,
  }) : imageUrl = null,
       download = null;

  /// A saved receipt: the photo is downloaded to a temporary file before it is shared.
  const ReceiptImageViewerPage.network({
    super.key,
    required String this.imageUrl,
    this.download,
    this.shareFile,
  }) : imagePath = null;

  final String? imagePath;
  final String? imageUrl;

  /// Replace the system share sheet and the download in tests.
  @visibleForTesting
  final Future<void> Function(String filePath)? shareFile;
  @visibleForTesting
  final Future<String?> Function(String url)? download;

  @override
  State<ReceiptImageViewerPage> createState() => _ReceiptImageViewerPageState();
}

class _ReceiptImageViewerPageState extends State<ReceiptImageViewerPage> {
  static const double _busySize = 20;

  bool _sharing = false;

  static Future<void> _systemShare(String path) =>
      SharePlus.instance.share(ShareParams(files: [XFile(path)]));

  Future<void> _share() async {
    setState(() => _sharing = true);
    final url = widget.imageUrl;
    final download = widget.download ?? RemoteApiHelper.instance.downloadToTemp;
    final path = url == null ? widget.imagePath : await download(url);
    if (!mounted) return;
    if (path == null) {
      setState(() => _sharing = false);
      AppToast.error(context, context.loc.receiptViewerShareFailed);
      return;
    }
    try {
      await (widget.shareFile ?? _systemShare)(path);
    } catch (e) {
      debugPrint('Không chia sẻ được ảnh hóa đơn: $e');
      if (mounted) {
        AppToast.error(context, context.loc.receiptViewerShareFailed);
      }
    }
    if (!mounted) return;
    setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          loc.receiptViewerTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: AppTextSize.pageTitle,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: loc.receiptViewerShare,
            onPressed: _sharing ? null : _share,
            icon: _sharing
                ? const SizedBox.square(
                    dimension: _busySize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.ios_share_rounded, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        child: ZoomableReceiptImage(
          imagePath: widget.imagePath,
          imageUrl: widget.imageUrl,
        ),
      ),
    );
  }
}
