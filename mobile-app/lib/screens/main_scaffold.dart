import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/screens/dashboard/dashboard_page.dart';
import 'package:finance_ai_app/screens/ledger/ledger_page.dart';
import 'package:finance_ai_app/screens/ai/ai_tab_page.dart';
import 'package:finance_ai_app/screens/profile/profile_page.dart';
import 'package:finance_ai_app/screens/receipt_scanner/review_form_page.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';

/// What the ML Kit document scanner throws when the user closes it without scanning: not an error to show.
const String _scannerCancelledMessage = 'Operation cancelled';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  final _ledgerKey = GlobalKey<LedgerPageState>();
  final _dashboardKey = GlobalKey<DashboardPageState>();

  late final List<Widget> _pages = [
    DashboardPage(
      key: _dashboardKey,
      onNavigateToAI: () {
        setState(() {
          _currentIndex = 2;
        });
      },
    ),
    LedgerPage(key: _ledgerKey),
    const AITabPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resendOutbox();
  }

  @override
  void dispose() {
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

  void _showScannerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final loc = context.loc;
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                loc.scanSheetTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildScanOptionBtn(
                    colors,
                    Icons.document_scanner_rounded,
                    loc.scanWithAi,
                    () => _startAutoScanner(context),
                  ),
                  _buildScanOptionBtn(
                    colors,
                    Icons.photo_library_rounded,
                    loc.scanFromGallery,
                    () => _pickImageAndScan(context, ImageSource.gallery),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
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
        Navigator.pop(context);
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewFormPage(imagePath: images.first),
          ),
        );
        if (saved == true && mounted) {
          setState(() => _currentIndex = 1);
        }
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
        imageQuality: 50,
        maxWidth: 1280,
        maxHeight: 1280,
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
      Navigator.pop(context);
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => ReviewFormPage(imagePath: imagePath)),
      );
      if (saved == true && mounted) {
        setState(() => _currentIndex = 1);
      }
    }
  }

  /// The options sheet stays open behind the dialog, so the user can pick the other way at once.
  /// The texts are picked only once the screen is known to be still there, in the language it shows.
  Future<void> _showScanError(
    String Function(AppLocalizations loc) title,
    String Function(AppLocalizations loc) message,
  ) async {
    if (!mounted) return;
    final loc = context.loc;
    await AppDialog.error(context, title: title(loc), message: message(loc));
  }

  Widget _buildScanOptionBtn(
    ColorScheme colors,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colors.primary, size: 32),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
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
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
