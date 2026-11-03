import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/models/receipt_status.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_source.dart';

class TransactionModel {
  /// Columns of the local `transactions` table that only exist for the sync state (see SqfliteHelper).
  static const String columnClientId = 'client_id';
  static const String columnSyncStatus = 'sync_status';

  /// Columns of the receipt attached to a transaction that waits to be sent (version 7), so a resend still carries it.
  static const String columnImageUrl = 'image_url';
  static const String columnRawReceiptData = 'raw_receipt_data';

  /// Column of the "save anyway" of a scanned receipt (version 9), 0 or 1, so a resend from the outbox still carries it.
  static const String columnAllowDuplicate = 'allow_duplicate';

  /// The checkout field that saves a scanned receipt even when the server thinks it is already saved.
  static const String checkoutAllowDuplicate = 'allowDuplicate';

  /// Values of the body of POST /api/transactions/checkout that every transaction of the app sends the same way.
  static const String paymentMethodWallet = 'WALLET';

  /// Data, not a UI text: the location core-backend stores for a transaction made in the app.
  static const String defaultLocation = 'Trong ứng dụng';

  static const Uuid _uuid = Uuid();

  /// The id on the server. Null while the server does not have the transaction: one that is still to be sent is found
  /// by its [clientId], never by a local row number, which could pass for the id of another transaction of the server.
  final String? id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final bool isExpense;
  final String iconName;
  final int? walletId;
  final String? imageUrl;

  /// What ai-service answered for the scanned receipt, as one JSON text (rawReceiptData of the checkout). Only set on a
  /// transaction created from a scan on this device; the server does not send it back.
  final String? rawReceiptData;

  /// The state of the receipt attached to the transaction. Null without a receipt, and always null offline: the local
  /// SQLite rows do not store it.
  final ReceiptStatus? receiptStatus;

  /// UUID v4 that this device gave the transaction when it was created. The server stores it and uses it to recognise
  /// the same transaction arriving twice, so sending it again never creates a duplicate. Null for a transaction read
  /// from the server, which does not send it back.
  final String? clientId;

  /// Whether the server has the transaction. Whatever comes from the server is [SyncStatus.synced]; a transaction
  /// created on this device is pending or in error until the server confirms it.
  final SyncStatus syncStatus;

  /// The user's "save anyway" after the server took a scanned receipt for one already saved (409). It is stored with the
  /// transaction in the outbox, so every send of it (the first one and any resend) carries it.
  final bool allowDuplicate;

  /// Where the transaction comes from. Only what the server sends can be anything but [TransactionSource.normal]: the
  /// local table holds the transactions this device made and has not sent yet, all normal, so it has no column for it.
  final TransactionSource source;

  TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.isExpense,
    this.iconName = 'default',
    this.walletId,
    this.imageUrl,
    this.rawReceiptData,
    this.receiptStatus,
    this.clientId,
    this.syncStatus = SyncStatus.synced,
    this.allowDuplicate = false,
    this.source = TransactionSource.normal,
  });

  /// A new transaction of the user, not stored anywhere yet: it gets its [clientId] here, once, so every send of it
  /// (the first one and any resend) carries the same one. [imageUrl] and [rawReceiptData] are the receipt it was scanned
  /// from, if any.
  factory TransactionModel.draft({
    required String title,
    required String category,
    required double amount,
    required DateTime date,
    required bool isExpense,
    String? imageUrl,
    String? rawReceiptData,
  }) {
    return TransactionModel(
      title: title,
      category: category,
      amount: amount,
      date: date,
      isExpense: isExpense,
      iconName: category,
      imageUrl: imageUrl,
      rawReceiptData: rawReceiptData,
      clientId: _uuid.v4(),
    );
  }

  IconData get icon => isExpense ? Icons.money_off : Icons.attach_money;

  /// Money moved from the wallet into a savings goal: it leaves the wallet but is not spending.
  bool get isSavingsContribution =>
      isExpense && TransactionCategories.isSavings(category);

  /// True when the user made this transaction, as opposed to the refund of a savings goal or a transfer to or from a
  /// linked wallet: those change the balance of the wallet but are neither income nor spending.
  bool get isNormal => source == TransactionSource.normal;

  /// True when this counts in "income" totals: an income of the user, not a refund or a transfer.
  bool get countsAsIncome => !isExpense && isNormal;

  /// True when this counts in "spending" totals: an expense of the user that is not a savings contribution.
  bool get countsAsSpending => isExpense && isNormal && !isSavingsContribution;

  /// True while the server has not confirmed the transaction: it is waiting to be sent, or its last send failed.
  bool get isUnsynced => syncStatus != SyncStatus.synced;

  /// The same transaction in another sync state.
  TransactionModel withSyncStatus(SyncStatus status) =>
      _copy(syncStatus: status);

  /// The same transaction, saved even when the server takes it for a receipt already saved.
  TransactionModel allowingDuplicate() => _copy(allowDuplicate: true);

  TransactionModel _copy({SyncStatus? syncStatus, bool? allowDuplicate}) {
    return TransactionModel(
      id: id,
      title: title,
      amount: amount,
      date: date,
      category: category,
      isExpense: isExpense,
      iconName: iconName,
      walletId: walletId,
      imageUrl: imageUrl,
      rawReceiptData: rawReceiptData,
      receiptStatus: receiptStatus,
      clientId: clientId,
      syncStatus: syncStatus ?? this.syncStatus,
      allowDuplicate: allowDuplicate ?? this.allowDuplicate,
      source: source,
    );
  }

  /// The body of POST /api/transactions/checkout. It is built only from the fields that are stored locally, so a resend
  /// sends exactly what the first send did; the server answers a repeated [clientId] with the first transaction and
  /// ignores any difference in the rest, [allowDuplicate] included.
  Map<String, dynamic> toCheckoutJson() {
    return {
      'amount': amount.round(),
      'note': title,
      'location': title.isEmpty ? defaultLocation : title,
      'paymentMethod': paymentMethodWallet,
      'transactionDate': date.toIso8601String(),
      'categoryName': category,
      'isExpense': isExpense,
      if (clientId != null) 'clientId': clientId,
      if (rawReceiptData != null) 'rawReceiptData': rawReceiptData,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (allowDuplicate) checkoutAllowDuplicate: true,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'isExpense': isExpense,
      'icon_name': iconName,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id']?.toString(),
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: DateTime.parse(map['date']),
      category: map['category'] ?? TransactionCategories.otherExpense,
      isExpense: map['isExpense'] ?? true,
      iconName: map['icon_name'] ?? 'default',
    );
  }

  /// A transaction as core-backend sends it (TransactionResponseDto). Its title is already the note, or the category
  /// when there is no note. [clientId] is set when this device (or another one) created it, so the copy of it still
  /// waiting on this device can be recognised.
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id']?.toString(),
      title: (json['title'] ?? json['category'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      category: (json['category'] ?? TransactionCategories.otherExpense)
          .toString(),
      isExpense: json['isExpense'] == true,
      iconName: (json['category'] ?? 'default').toString(),
      imageUrl: json['imageUrl']?.toString(),
      receiptStatus: ReceiptStatus.fromServer(json['receiptStatus']),
      clientId: json['clientId']?.toString(),
      source: TransactionSource.fromServer(json['source']),
    );
  }

  Map<String, dynamic> toDbMap(int userId) {
    return {
      'user_id': userId,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'is_expense': isExpense ? 1 : 0,
      'icon_name': iconName,
      'wallet_id': walletId,
      columnClientId: clientId,
      columnSyncStatus: syncStatus.dbValue,
      columnImageUrl: imageUrl,
      columnRawReceiptData: rawReceiptData,
      columnAllowDuplicate: allowDuplicate ? 1 : 0,
    };
  }

  factory TransactionModel.fromDbMap(Map<String, dynamic> map) {
    final syncStatus = SyncStatus.fromDb(map[columnSyncStatus]);
    return TransactionModel(
      // A row the server has not confirmed has no id there; its row number must not pass for one.
      id: syncStatus == SyncStatus.synced ? map['id']?.toString() : null,
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: DateTime.parse(map['date']),
      category: map['category'] ?? TransactionCategories.otherExpense,
      isExpense: map['is_expense'] == 1,
      iconName: map['icon_name'] ?? 'default',
      walletId: map['wallet_id'] as int?,
      imageUrl: map[columnImageUrl] as String?,
      rawReceiptData: map[columnRawReceiptData] as String?,
      clientId: map[columnClientId] as String?,
      syncStatus: syncStatus,
      allowDuplicate: map[columnAllowDuplicate] == 1,
    );
  }
}
