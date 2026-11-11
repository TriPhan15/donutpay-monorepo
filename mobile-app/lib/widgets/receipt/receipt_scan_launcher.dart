import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart' show DatabaseException;

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/review_exit.dart';
import 'package:finance_ai_app/screens/main_tabs.dart';
import 'package:finance_ai_app/screens/receipt_scanner/review_form_page.dart';
import 'package:finance_ai_app/services/receipt_scan_queue.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';
import 'package:finance_ai_app/widgets/receipt/scan_options_sheet.dart';

/// What the ML Kit document scanner throws when the user closes it without scanning: not an error to show.
const String _scannerCancelledMessage = 'Operation cancelled';

/// The size and quality gallery photos are kept at. DONUT reads 1920x1440, so a smaller or heavily compressed photo
/// loses the small text (address, date); 2560 px at quality 90 stays far under the server's 15 MB upload limit.
@visibleForTesting
const int pickedImageQuality = 90;
@visibleForTesting
const double pickedImageMaxSide = 2560;

/// The whole "bring a receipt in" flow behind the scan button: the options sheet, the ML Kit scanner, the gallery
/// picker, the review page of a single receipt and the hand-over of many receipts to [ReceiptScanQueue].
///
/// It is not a widget: it works on the screen that owns it, [host]. Every `await` is followed by a check of
/// `host.mounted` before [host]'s context is read, so a flow that outlives its screen ends quietly instead of
/// touching a dead context. Taking the [State] (rather than a [BuildContext] and a flag) keeps the two together: the
/// context it hands out is the one `mounted` speaks for.
class ReceiptScanLauncher {
  ReceiptScanLauncher({
    required this.host,
    required this.onOpenTransaction,
    required this.showTab,
  });

  /// The screen the dialogs, toasts and review pages show over.
  final State host;

  /// Opens the transaction [id] in the Ledger; handed to the review page.
  final ValueChanged<int> onOpenTransaction;

  /// Brings a tab of the main screen to the front.
  final ValueChanged<MainTab> showTab;

  /// The scan sheet closes itself before the picked way starts, so an error dialog of that way shows over the host.
  Future<void> start() async {
    final option = await showScanOptionsSheet(host.context);
    if (option == null || !host.mounted) return;
    switch (option) {
      case ScanOption.cameraOne:
        await _startAutoScanner();
      case ScanOption.galleryOne:
        await _pickImageAndScan(ImageSource.gallery);
      case ScanOption.cameraMany:
        await _startBatchScanner();
      case ScanOption.galleryMany:
        await _pickImagesForQueue();
    }
  }

  Future<void> _startAutoScanner() async {
    final DocumentScanner documentScanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: {DocumentFormat.jpeg},
        mode: ScannerMode.base,
        pageLimit: 1,
        isGalleryImport: true,
      ),
    );
    try {
      final result = await documentScanner.scanDocument();
      final images = result.images;
      if (images != null && images.isNotEmpty && host.mounted) {
        await _review(images.first);
      }
    } catch (e) {
      if (e is PlatformException && e.message == _scannerCancelledMessage) {
        return;
      }
      debugPrint('Lỗi quét tài liệu ML Kit: $e');
      await _showScanError(
        (loc) => loc.scanScannerFailedTitle,
        (loc) => loc.scanScannerFailedMessage,
      );
    } finally {
      documentScanner.close();
    }
  }

  Future<void> _pickImageAndScan(ImageSource source) async {
    final ImagePicker picker = ImagePicker();

    final XFile? image;
    try {
      image = await picker.pickImage(
        source: source,
        imageQuality: pickedImageQuality,
        maxWidth: pickedImageMaxSide,
        maxHeight: pickedImageMaxSide,
      );
    } catch (e) {
      debugPrint('Lỗi chọn ảnh hóa đơn: $e');
      await _showScanError(
        (loc) => loc.scanGalleryFailedTitle,
        (loc) => loc.scanGalleryFailedMessage,
      );
      return;
    }

    final imagePath = image?.path;
    if (imagePath != null && host.mounted) await _review(imagePath);
  }

  /// Opens the review page of one receipt and acts on how the user leaves it.
  Future<void> _review(String imagePath) async {
    final saved = await Navigator.push<ReviewExit>(
      host.context,
      MaterialPageRoute(
        builder: (_) => ReviewFormPage(
          imagePath: imagePath,
          onOpenTransaction: onOpenTransaction,
        ),
      ),
    );
    if (host.mounted) _afterReview(saved);
  }

  /// After a review opened from a single scan: "Lưu & quét tiếp" opens the scan sheet again, "Lưu" shows the Ledger.
  void _afterReview(ReviewExit? exit) {
    switch (exit) {
      case ReviewExit.savedScanNext:
        start();
      case ReviewExit.saved:
        showTab(MainTab.ledger);
      case null:
        break;
    }
  }

  /// Scans up to [ReceiptScanQueue.maxBatch] receipts in one go and queues them; DONUT reads them in the background.
  Future<void> _startBatchScanner() async {
    final DocumentScanner documentScanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: {DocumentFormat.jpeg},
        mode: ScannerMode.base,
        pageLimit: ReceiptScanQueue.maxBatch,
        isGalleryImport: true,
      ),
    );
    try {
      final result = await documentScanner.scanDocument();
      final images = result.images;
      if (images != null && images.isNotEmpty && host.mounted) {
        await _enqueueBatch(images);
      }
    } catch (e) {
      if (e is PlatformException && e.message == _scannerCancelledMessage) {
        return;
      }
      debugPrint('Lỗi quét nhiều hóa đơn bằng ML Kit: $e');
      await _showScanError(
        (loc) => loc.scanScannerFailedTitle,
        (loc) => loc.scanScannerFailedMessage,
      );
    } finally {
      documentScanner.close();
    }
  }

  /// Picks up to [ReceiptScanQueue.maxBatch] photos from the gallery and queues them.
  Future<void> _pickImagesForQueue() async {
    final List<XFile> images;
    try {
      images = await ImagePicker().pickMultiImage(
        limit: ReceiptScanQueue.maxBatch,
        imageQuality: pickedImageQuality,
        maxWidth: pickedImageMaxSide,
        maxHeight: pickedImageMaxSide,
      );
    } catch (e) {
      debugPrint('Lỗi chọn nhiều ảnh hóa đơn: $e');
      await _showScanError(
        (loc) => loc.scanGalleryFailedTitle,
        (loc) => loc.scanGalleryFailedMessage,
      );
      return;
    }
    if (images.isEmpty || !host.mounted) return;
    await _enqueueBatch([for (final image in images) image.path]);
  }

  /// Hands [imagePaths] to the scan queue and tells how many it took, and how many it left out over the limit.
  Future<void> _enqueueBatch(List<String> imagePaths) async {
    final int accepted;
    try {
      accepted = await ReceiptScanQueue.instance.enqueue(imagePaths);
    } on DatabaseException catch (e) {
      debugPrint('Lỗi lưu hàng đợi quét: $e');
      return _showQueueStorageError();
    } on FileSystemException catch (e) {
      debugPrint('Lỗi chép ảnh vào hàng đợi quét: $e');
      return _showQueueStorageError();
    }
    if (!host.mounted) return;
    // The scan strip that follows the reading sits on the home tab.
    if (accepted > 0) showTab(MainTab.home);
    final loc = host.context.loc;
    final skipped = imagePaths.length - accepted;
    if (skipped == 0) {
      AppToast.success(host.context, loc.scanQueueAdded(accepted));
    } else {
      AppToast.info(
        host.context,
        loc.scanQueueOverLimit(accepted, skipped, ReceiptScanQueue.maxBatch),
      );
    }
  }

  void _showQueueStorageError() {
    if (!host.mounted) return;
    AppToast.error(host.context, host.context.loc.scanQueueStorageFailed);
  }

  /// The scan sheet is already closed: the user opens it again to pick another way.
  /// The texts are picked only once the screen is known to be still there, in the language it shows.
  Future<void> _showScanError(
    String Function(AppLocalizations loc) title,
    String Function(AppLocalizations loc) message,
  ) async {
    if (!host.mounted) return;
    final loc = host.context.loc;
    await AppDialog.error(
      host.context,
      title: title(loc),
      message: message(loc),
    );
  }
}
