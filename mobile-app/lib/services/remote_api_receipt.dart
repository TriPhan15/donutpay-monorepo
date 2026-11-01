part of 'remote_api_helper.dart';

/// Receipts of the user, and the download of their photo.
extension RemoteApiReceipt on RemoteApiHelper {
  static const String _receiptDatePattern = 'yyyy-MM-dd';

  /// GET /api/receipts/transaction/{id}: the receipt of one of the user's own transactions (404 when there is none).
  Future<ReceiptDetail> fetchReceiptOfTransaction(String transactionId) async {
    final res = await _dio.get('/api/receipts/transaction/$transactionId');
    return _receiptOf(res);
  }

  /// GET /api/receipts/{id}.
  Future<ReceiptDetail> fetchReceipt(int id) async {
    final res = await _dio.get('/api/receipts/$id');
    return _receiptOf(res);
  }

  /// PUT /api/receipts/{id}: the owner corrects a read receipt. Only the fields given are sent, and [version] is the one
  /// the receipt was loaded with: the server answers 409 for an older one. It changes neither the amount of the
  /// transaction nor the wallet; that happens when an administrator approves.
  Future<ReceiptDetail> updateReceipt(
    int id, {
    required int version,
    String? vendorName,
    double? extractedTotal,
    DateTime? extractedDate,
  }) async {
    final res = await _dio.put(
      '/api/receipts/$id',
      data: {
        'version': version,
        'vendorName': ?vendorName,
        'extractedTotal': ?extractedTotal,
        if (extractedDate != null)
          'extractedDate': DateFormat(
            _receiptDatePattern,
          ).format(extractedDate),
      },
    );
    notifyDataChanged();
    return _receiptOf(res);
  }

  /// POST /api/receipts/{id}/retry: delivers what the AI answered for a new scan of a FAILED receipt
  /// ([rawReceiptData] is that answer as one JSON text, like a checkout's). core-backend never calls the AI itself.
  /// Send the same [clientId] again when the request is repeated, so that the reading is recorded once.
  Future<ReceiptDetail> retryReceipt(
    int id, {
    required String rawReceiptData,
    required String clientId,
  }) async {
    final res = await _dio.post(
      '/api/receipts/$id/retry',
      data: {'rawReceiptData': rawReceiptData, 'clientId': clientId},
    );
    notifyDataChanged();
    return _receiptOf(res);
  }

  /// POST /api/receipts/feedback/{id}: the owner of a FAILED receipt sends the right [amount] for an administrator to
  /// check; the receipt goes to WAITING_FOR_REVIEW.
  Future<void> submitReceiptFeedback(int id, double amount) async {
    await _dio.post(
      '/api/receipts/feedback/$id',
      queryParameters: {'manualAmount': amount},
    );
    notifyDataChanged();
  }

  static ReceiptDetail _receiptOf(Response<dynamic> res) =>
      ReceiptDetail.fromJson(
        Map<String, dynamic>.from(res.data['data'] as Map),
      );

  /// Downloads a file of another host (a receipt photo on the image CDN) into the temporary directory, without the
  /// login token, and returns its path; null when it could not be downloaded. The same URL lands in the same file.
  Future<String?> downloadToTemp(String url) async {
    final name = 'receipt_${url.hashCode.toUnsigned(32).toRadixString(16)}.jpg';
    final path = '${Directory.systemTemp.path}${Platform.pathSeparator}$name';
    try {
      final res = await _externalDio.get<List<int>>(url);
      await File(path).writeAsBytes(res.data!, flush: true);
      return path;
    } catch (e) {
      debugPrint('Không tải được ảnh $url: $e');
      return null;
    }
  }
}
