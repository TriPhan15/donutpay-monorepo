import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:sqflite/sqflite.dart' show DatabaseException;

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/screens/dashboard/dashboard_page.dart';
import 'package:finance_ai_app/screens/ledger/ledger_page.dart';
import 'package:finance_ai_app/screens/main_tabs.dart';
import 'package:finance_ai_app/models/review_exit.dart';
import 'package:finance_ai_app/screens/ai/ai_tab_page.dart';
import 'package:finance_ai_app/screens/profile/profile_page.dart';
import 'package:finance_ai_app/screens/receipt_scanner/review_form_page.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/services/receipt_scan_queue.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';
import 'package:finance_ai_app/widgets/receipt/scan_options_sheet.dart';

/// What the ML Kit document scanner throws when the user closes it without scanning: not an error to show.
const String _scannerCancelledMessage = 'Operation cancelled';

/// The size and quality the picked photos are scaled to before DONUT reads them, as for a single photo.
const int _pickedImageQuality = 50;
const double _pickedImageMaxSide = 1280;

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with WidgetsBindingObserver {
  static const int _ledgerTabIndex = 1;

  int _currentIndex = 0;

  final _ledgerKey = GlobalKey<LedgerPageState>();
  final _dashboardKey = GlobalKey<DashboardPageState>();

  late final List<Widget> _pages = [
    DashboardPage(
      key: _dashboardKey,
      onOpenTransaction: _openTransaction,
      // The home shortcut opens the same scan options as the scan button.
      onScanReceipt: () => _showScannerOptions(context),
    ),
    LedgerPage(key: _ledgerKey),
    const AITabPage(),
    const ProfilePage(),
  ];

  /// Switches to the Ledger tab and shows the transaction [id] in its detail sheet.
  void _openTransaction(int id) {
    setState(() => _currentIndex = _ledgerTabIndex);
    _ledgerKey.currentState?.showTransaction(id);
  }

  /// Brings [tab] to the front for a page pushed over this one (see [MainTabs]).
  void _showTab(MainTab tab) {
    if (mounted) setState(() => _currentIndex = tab.index);
  }

  /// Handed to [MainTabs.attachScanner]; tear-offs of one method are equal, so detaching recognises it.
  void _openScanner() => _showScannerOptions(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MainTabs.attach(_showTab);
    MainTabs.attachScanner(_openScanner);
    _resendOutbox();
    // Reads on the receipts that the user queued before the app was closed.
    unawaited(ReceiptScanQueue.instance.resume());
  }

  @override
  void dispose() {
    MainTabs.detach(_showTab);
    MainTabs.detachScanner(_openScanner);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the background, like opening the app: the network may be back too.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _resendOutbox();
  }

  /// Sends again, without asking, the transactions that wait on this device. The tabs hear each outcome through
  /// dataChangedNotifier.
  void _resendOutbox() {
    final userId = SessionService.currentUserId;
    if (userId == null) return;
    unawaited(AppRepository.instance.resendUnsyncedTransactions(userId));
  }

  /// The scan sheet closes itself before the picked way starts, so an error dialog of that way shows over this page.
  Future<void> _showScannerOptions(BuildContext context) async {
    final option = await showScanOptionsSheet(context);
    if (option == null || !context.mounted) return;
    switch (option) {
      case ScanOption.cameraOne:
        await _startAutoScanner(context);
      case ScanOption.galleryOne:
        await _pickImageAndScan(context, ImageSource.gallery);
      case ScanOption.cameraMany:
        await _startBatchScanner(context);
      case ScanOption.galleryMany:
        await _pickImagesForQueue(context);
    }
  }

  Future<void> _startAutoScanner(BuildContext context) async {
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
      if (images != null && images.isNotEmpty && context.mounted) {
        final saved = await Navigator.push<ReviewExit>(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewFormPage(
              imagePath: images.first,
              onOpenTransaction: _openTransaction,
            ),
          ),
        );
        if (mounted) _afterReview(saved);
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

  Future<void> _pickImageAndScan(
    BuildContext context,
    ImageSource source,
  ) async {
    final ImagePicker picker = ImagePicker();

    final XFile? image;
    try {
      image = await picker.pickImage(
        source: source,
        imageQuality: _pickedImageQuality,
        maxWidth: _pickedImageMaxSide,
        maxHeight: _pickedImageMaxSide,
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
    if (imagePath != null && context.mounted) {
      final saved = await Navigator.push<ReviewExit>(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewFormPage(
            imagePath: imagePath,
            onOpenTransaction: _openTransaction,
          ),
        ),
      );
      if (mounted) _afterReview(saved);
    }
  }

  /// After a review opened from a single scan: "Lưu & quét tiếp" opens the scan sheet again, "Lưu" shows the Ledger.
  void _afterReview(ReviewExit? exit) {
    switch (exit) {
      case ReviewExit.savedScanNext:
        _showScannerOptions(context);
      case ReviewExit.saved:
        setState(() => _currentIndex = _ledgerTabIndex);
      case null:
        break;
    }
  }

  /// Scans up to [ReceiptScanQueue.maxBatch] receipts in one go and queues them; DONUT reads them in the background.
  Future<void> _startBatchScanner(BuildContext context) async {
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
      if (images != null && images.isNotEmpty && context.mounted) {
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
  Future<void> _pickImagesForQueue(BuildContext context) async {
    final List<XFile> images;
    try {
      images = await ImagePicker().pickMultiImage(
        limit: ReceiptScanQueue.maxBatch,
        imageQuality: _pickedImageQuality,
        maxWidth: _pickedImageMaxSide,
        maxHeight: _pickedImageMaxSide,
      );
    } catch (e) {
      debugPrint('Lỗi chọn nhiều ảnh hóa đơn: $e');
      await _showScanError(
        (loc) => loc.scanGalleryFailedTitle,
        (loc) => loc.scanGalleryFailedMessage,
      );
      return;
    }
    if (images.isEmpty || !context.mounted) return;
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
    if (!mounted) return;
    // The scan strip that follows the reading sits on the home tab.
    if (accepted > 0) setState(() => _currentIndex = MainTab.home.index);
    final loc = context.loc;
    final skipped = imagePaths.length - accepted;
    if (skipped == 0) {
      AppToast.success(context, loc.scanQueueAdded(accepted));
    } else {
      AppToast.info(
        context,
        loc.scanQueueOverLimit(accepted, skipped, ReceiptScanQueue.maxBatch),
      );
    }
  }

  void _showQueueStorageError() {
    if (!mounted) return;
    AppToast.error(context, context.loc.scanQueueStorageFailed);
  }

  /// The scan sheet is already closed: the user opens it again to pick another way.
  /// The texts are picked only once the screen is known to be still there, in the language it shows.
  Future<void> _showScanError(
    String Function(AppLocalizations loc) title,
    String Function(AppLocalizations loc) message,
  ) async {
    if (!mounted) return;
    final loc = context.loc;
    await AppDialog.error(context, title: title(loc), message: message(loc));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(top: 30),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            // Brand glow around the scan button, not an elevation shadow: it takes the primary of each theme.
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showScannerOptions(context),
          elevation: 0,
          child: const Icon(Icons.document_scanner_rounded, size: 28),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(colors, Icons.home_rounded, loc.navHome, 0),
              _buildNavItem(colors, Icons.bar_chart_rounded, loc.navLedger, 1),
              const SizedBox(width: 48),
              _buildNavItem(colors, Icons.auto_awesome_rounded, loc.navAi, 2),
              _buildNavItem(colors, Icons.person_rounded, loc.navProfile, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    ColorScheme colors,
    IconData icon,
    String label,
    int index,
  ) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? colors.primary : colors.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (_currentIndex == index) {
            if (index == 0) {
              _dashboardKey.currentState?.reload();
            } else if (index == 1) {
              _ledgerKey.currentState?.reload();
            }
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: color,
                fontSize: AppTextSize.caption,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
