import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/screens/dashboard/dashboard_page.dart';
import 'package:finance_ai_app/screens/ledger/ledger_page.dart';
import 'package:finance_ai_app/screens/main_tabs.dart';
import 'package:finance_ai_app/screens/ai/ai_tab_page.dart';
import 'package:finance_ai_app/screens/profile/profile_page.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/services/receipt_scan_queue.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_scan_launcher.dart';

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

  late final ReceiptScanLauncher _scanLauncher = ReceiptScanLauncher(
    host: this,
    onOpenTransaction: _openTransaction,
    showTab: _showTab,
  );

  late final List<Widget> _pages = [
    DashboardPage(
      key: _dashboardKey,
      onOpenTransaction: _openTransaction,
      // The home shortcut opens the same scan options as the scan button.
      onScanReceipt: _scanLauncher.start,
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
  void _openScanner() => _scanLauncher.start();

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
          onPressed: _scanLauncher.start,
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
