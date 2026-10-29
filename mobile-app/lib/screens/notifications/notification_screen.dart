import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/models/app_notification.dart';
import 'package:finance_ai_app/screens/main_tabs.dart';
import 'package:finance_ai_app/screens/notifications/notification_destination.dart';
import 'package:finance_ai_app/screens/notifications/widgets/notification_content_sheet.dart';
import 'package:finance_ai_app/screens/notifications/widgets/notification_row.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

export 'package:finance_ai_app/screens/notifications/widgets/notification_row.dart'
    show NotificationTypeLabels;

/// The user's notifications, newest first. Pull down to reload; the next page is asked for near the end of the list;
/// a tap shows the notification as read at once, tells the server in the background (and shows it unread again if that
/// fails), then opens where it leads ([NotificationDestination]); what cannot be opened shows its content in a sheet.
/// Notifications live on the server only: without a backend (demo mode) the screen is empty and requests nothing.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({
    super.key,
    this.onOpenTransaction,
    this.onOpenLedger,
  });

  /// Shows a transaction (by its server id) in the Ledger; the screen closes itself first. Without it, a transaction
  /// notification shows its content instead.
  final ValueChanged<int>? onOpenTransaction;

  /// Shows the Ledger tab, for a transaction or receipt notification without a transaction id; the screen closes itself
  /// first. Left out, the Ledger tab of MainScaffold ([MainTabs]); without that either, the content is shown.
  final VoidCallback? onOpenLedger;

  /// How many notifications one request asks for; the server accepts 1 to 50.
  static const int pageSize = 20;

  static const Key backKey = Key('notifications-back');
  static const Key markAllKey = Key('notifications-mark-all');

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  /// How close to the end of the list, in pixels, the next page is asked for.
  static const double _loadMoreExtent = 300;

  final ScrollController _scroll = ScrollController();

  List<AppNotification> _items = const [];
  int _nextPage = 1;
  bool _hasNext = false;
  bool _loadingFirstPage = true;
  bool _firstPageFailed = false;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  bool _markingAll = false;

  /// Ids whose "mark as read" request is still running, so a second tap sends no second request.
  final Set<int> _markingRead = {};

  /// Bumped by every load of the first page: whatever answers a request made before it is dropped, not mixed in.
  int _generation = 0;

  bool get _hasUnread => _items.any((notification) => !notification.isRead);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Loads the first page and replaces the list: on opening, on pull-to-refresh and on "try again".
  Future<void> _reload() async {
    final generation = ++_generation;
    try {
      final page = await RemoteApiHelper.instance.getNotifications(
        page: 0,
        size: NotificationScreen.pageSize,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = page.content;
        _nextPage = 1;
        _hasNext = page.hasNext;
        _loadingFirstPage = false;
        _firstPageFailed = false;
        _loadingMore = false;
        _loadMoreFailed = false;
      });
      _loadMoreIfTheListIsShort();
    } on DioException catch (e) {
      _onReloadFailed(generation, _describe(e));
    } on FormatException catch (e) {
      _onReloadFailed(generation, e.message);
    }
  }

  void _onReloadFailed(int generation, String reason) {
    debugPrint('Notifications: the first page could not be loaded ($reason).');
    if (!mounted || generation != _generation) return;
    final keepsAList = _items.isNotEmpty;
    setState(() {
      _loadingFirstPage = false;
      _firstPageFailed = !keepsAList;
      _loadingMore = false;
    });
    // A list is already on screen: it stays, and a short note says the reload failed and offers to try again.
    if (keepsAList) {
      final loc = context.loc;
      AppToast.error(
        context,
        loc.notificationsLoadFailed,
        actionLabel: loc.commonRetry,
        onAction: _reload,
      );
    }
  }

  void _retryFirstPage() {
    setState(() {
      _loadingFirstPage = true;
      _firstPageFailed = false;
    });
    _reload();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < _loadMoreExtent) _loadMore();
  }

  /// A list shorter than the screen cannot be scrolled, so the next page is asked for as soon as a page is shown.
  void _loadMoreIfTheListIsShort() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.position.extentAfter < _loadMoreExtent) _loadMore();
    });
  }

  /// After a failure the next page is only asked for again from the "try again" button ([retry]), never by scrolling.
  Future<void> _loadMore({bool retry = false}) async {
    if (_loadingFirstPage || _loadingMore || !_hasNext) return;
    if (_loadMoreFailed && !retry) return;
    final generation = _generation;
    final pageNumber = _nextPage;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      final page = await RemoteApiHelper.instance.getNotifications(
        page: pageNumber,
        size: NotificationScreen.pageSize,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        // A notification raised since the first page pushes the others one place down, so a page can repeat the last
        // ones already shown: those are skipped.
        final shown = {for (final notification in _items) notification.id};
        _items = [
          ..._items,
          ...page.content.where((notification) => shown.add(notification.id)),
        ];
        _nextPage = pageNumber + 1;
        _hasNext = page.hasNext;
        _loadingMore = false;
      });
      _loadMoreIfTheListIsShort();
    } on DioException catch (e) {
      _onLoadMoreFailed(generation, pageNumber, _describe(e));
    } on FormatException catch (e) {
      _onLoadMoreFailed(generation, pageNumber, e.message);
    }
  }

  void _onLoadMoreFailed(int generation, int pageNumber, String reason) {
    debugPrint(
      'Notifications: page $pageNumber could not be loaded ($reason).',
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _loadingMore = false;
      _loadMoreFailed = true;
    });
  }

  /// Every tap marks the notification read, wherever it then leads.
  void _open(AppNotification notification) {
    if (!notification.isRead) unawaited(_markAsRead(notification));
    switch (NotificationDestination.of(notification)) {
      case PageTarget(:final builder):
        Navigator.push(context, MaterialPageRoute(builder: builder));
      case TransactionTarget(:final transactionId):
        final openTransaction = widget.onOpenTransaction;
        _leaveFor(
          notification,
          openTransaction == null ? null : () => openTransaction(transactionId),
        );
      case LedgerTarget():
        _leaveFor(
          notification,
          widget.onOpenLedger ?? MainTabs.opener(MainTab.ledger),
        );
      case ContentTarget():
        _showContent(notification);
    }
  }

  /// Closes the screen and runs [open], which shows something under it; without one, shows the content instead.
  void _leaveFor(AppNotification notification, VoidCallback? open) {
    if (open == null) {
      _showContent(notification);
      return;
    }
    Navigator.pop(context);
    open();
  }

  void _showContent(AppNotification notification) {
    showNotificationContentSheet(context, notification);
  }

  /// Optimistic: [notification] shows as read at once and goes back to unread if the server does not confirm.
  Future<void> _markAsRead(AppNotification notification) async {
    if (!_markingRead.add(notification.id)) return;
    final generation = _generation;
    _replace(notification.copyWith(isRead: true));
    try {
      final saved = await RemoteApiHelper.instance.markNotificationRead(
        notification.id,
      );
      if (mounted && generation == _generation) _replace(saved);
    } on DioException catch (e) {
      debugPrint(
        'Notifications: ${notification.id} could not be marked as read (${_describe(e)}).',
      );
      if (!mounted) return;
      if (generation == _generation) _replace(notification);
      AppToast.error(context, context.loc.notificationsMarkReadFailed);
    } on FormatException catch (e) {
      // The server answered 2xx, so it did mark the notification: only its copy could not be read. It stays read.
      debugPrint(
        'Notifications: unreadable answer after marking ${notification.id} as read (${e.message}).',
      );
    } finally {
      _markingRead.remove(notification.id);
    }
  }

  /// Optimistic too: everything on screen shows as read at once; what was unread is put back if the server refuses.
  Future<void> _markAllAsRead() async {
    if (_markingAll || !_hasUnread) return;
    final generation = _generation;
    final wereUnread = {
      for (final notification in _items)
        if (!notification.isRead) notification.id,
    };
    setState(() {
      _markingAll = true;
      _items = [
        for (final notification in _items)
          notification.isRead
              ? notification
              : notification.copyWith(isRead: true),
      ];
    });
    try {
      await RemoteApiHelper.instance.markAllNotificationsRead();
    } on DioException catch (e) {
      debugPrint(
        'Notifications: marking all as read failed (${_describe(e)}).',
      );
      if (mounted) {
        if (generation == _generation) _markUnreadAgain(wereUnread);
        AppToast.error(context, context.loc.notificationsMarkAllReadFailed);
      }
    } on FormatException catch (e) {
      // 2xx: the server marked them; only the count in its answer could not be read.
      debugPrint(
        'Notifications: unreadable answer after marking all as read (${e.message}).',
      );
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  void _markUnreadAgain(Set<int> ids) {
    setState(() {
      _items = [
        for (final notification in _items)
          ids.contains(notification.id)
              ? notification.copyWith(isRead: false)
              : notification,
      ];
    });
  }

  /// Puts [notification] in the place of the one with the same id, when that one is still listed.
  void _replace(AppNotification notification) {
    final index = _items.indexWhere((shown) => shown.id == notification.id);
    if (index < 0) return;
    setState(() {
      _items = List.of(_items)..[index] = notification;
    });
  }

  static String _describe(DioException e) =>
      'HTTP ${e.response?.statusCode ?? e.type.name}';

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final Widget body;
    if (_loadingFirstPage) {
      body = const _StateList(child: AppStateView.loading());
    } else if (_firstPageFailed) {
      body = _StateList(
        child: AppStateView.error(
          title: loc.notificationsLoadFailed,
          onRetry: _retryFirstPage,
        ),
      );
    } else if (_items.isEmpty) {
      body = _StateList(
        child: AppStateView.empty(
          icon: Icons.notifications_off_outlined,
          title: loc.notificationsEmpty,
          message: loc.notificationsEmptyHint,
        ),
      );
    } else {
      body = _NotificationList(
        controller: _scroll,
        notifications: _items,
        footer: _loadingMore
            ? _FooterState.loading
            : (_loadMoreFailed ? _FooterState.failed : _FooterState.idle),
        onTap: _open,
        onRetryMore: () => _loadMore(retry: true),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          PageBand(
            title: loc.notificationsTitle,
            buttonKey: NotificationScreen.backKey,
            // Nothing to mark before a list is shown; with nothing unread left, or while marking, the pill fades.
            trailing: _items.isEmpty
                ? null
                : _MarkAllPill(
                    label: loc.notificationsMarkAllRead,
                    onTap: _hasUnread && !_markingAll ? _markAllAsRead : null,
                  ),
          ),
          Expanded(
            child: RefreshIndicator(onRefresh: _reload, child: body),
          ),
        ],
      ),
    );
  }
}

enum _FooterState { idle, loading, failed }

/// "Mark all as read", a white translucent pill in the band; faded and inert while [onTap] is null.
class _MarkAllPill extends StatelessWidget {
  const _MarkAllPill({required this.label, required this.onTap});

  static const double _disabledOpacity = 0.45;
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 7,
  );

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? _disabledOpacity : 1,
      child: Material(
        color: BandColors.tint,
        shape: const StadiumBorder(),
        child: InkWell(
          key: NotificationScreen.markAllKey,
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: _padding,
            child: Text(
              label,
              style: const TextStyle(
                color: BandColors.primary,
                fontSize: AppTextSize.caption,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The list: one white block of rows, then the footer. It is padded inside the scroll view so the last row clears the
/// system bar.
class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.controller,
    required this.notifications,
    required this.footer,
    required this.onTap,
    required this.onRetryMore,
  });

  static const double _gutter = 16;

  final ScrollController controller;
  final List<AppNotification> notifications;
  final _FooterState footer;
  final ValueChanged<AppNotification> onTap;
  final VoidCallback onRetryMore;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final last = notifications.length - 1;
    return ListView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        _gutter,
        _gutter,
        _gutter,
        _gutter + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: notifications.length + 1,
      itemBuilder: (context, index) {
        if (index > last) {
          return _ListFooter(state: footer, onRetry: onRetryMore);
        }
        final notification = notifications[index];
        return NotificationRow(
          notification: notification,
          onTap: () => onTap(notification),
          isFirst: index == 0,
          isLast: index == last,
          now: now,
        );
      },
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.state, required this.onRetry});

  static const double _idleHeight = 8;
  static const double _failedTop = 16;

  final _FooterState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _FooterState.idle:
        return const SizedBox(height: _idleHeight);
      case _FooterState.loading:
        return const AppStateView.loading();
      case _FooterState.failed:
        final loc = context.loc;
        final colors = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(top: _failedTop),
          child: Column(
            children: [
              Text(
                loc.notificationsLoadMoreFailed,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: AppTextSize.secondary,
                ),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: colors.primary),
                child: Text(loc.notificationsRetry),
              ),
            ],
          ),
        );
    }
  }
}

/// A loading, empty or error state in place of the list. It scrolls, so pulling it down reloads like the list does.
class _StateList extends StatelessWidget {
  const _StateList({required this.child});

  /// Lowers the state from the band, towards the middle of the page.
  static const double _top = 72;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: _top),
      children: [child],
    );
  }
}
