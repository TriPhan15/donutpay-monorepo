part of 'remote_api_helper.dart';

/// Categories, transactions and the upload of their photo.
extension RemoteApiTransactions on RemoteApiHelper {
  /// The categories of the signed-in user (GET /api/categories). A failure is thrown, never answered with an empty
  /// list: an empty list is a real answer, and a caller that took a failure for it would wipe what it has cached.
  /// Throws [DioException] when the request fails and [FormatException] when the answer has an unknown shape.
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final response = await _dio.get('/api/categories');
    final data = response.data;
    if (response.statusCode == 200) {
      if (data is List) return List<Map<String, dynamic>>.from(data);
      if (data is Map && data.containsKey('data')) {
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
    }
    throw FormatException(
      'GET /api/categories: unexpected answer (${response.statusCode}).',
    );
  }

  Future<List<TransactionModel>> fetchTransactions() async {
    final res = await _dio.get('/api/transactions/mine');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map(
          (e) => TransactionModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// Ids of the transactions of the user that match [query], best match first, from GET /api/transactions/search
  /// (Elasticsearch, or PostgreSQL when it is down). [size] is at most 50, the limit of the backend.
  Future<List<int>> searchTransactionIds(String query, {int size = 50}) async {
    final res = await _dio.get(
      '/api/transactions/search',
      queryParameters: {'q': query, 'page': 0, 'size': size},
    );
    final items = (res.data['data']['items'] as List?) ?? [];
    return [
      for (final item in items)
        if (item is Map && item['id'] is num) (item['id'] as num).toInt(),
    ];
  }

  /// Sends the transaction. A photo that cannot be uploaded does not stop it: it is saved without the photo and the
  /// reason goes to [onImageUploadFailed], for the caller to tell the user.
  Future<void> addTransaction(
    Map<String, dynamic> data, {
    String? imagePath,
    void Function(Object error)? onImageUploadFailed,
  }) async {
    if (imagePath != null && imagePath.isNotEmpty) {
      try {
        data['imageUrl'] = await uploadImage(imagePath);
      } catch (e) {
        UserFacingError.log('Upload transaction photo', e);
        onImageUploadFailed?.call(e);
      }
    }
    // No notifyDataChanged here: AppRepository announces the write once it has flagged the outbox row, otherwise a
    // reload started now would still list the row as waiting.
    await _dio.post('/api/transactions/checkout', data: data);
  }

  /// PUT /api/transactions/{id}: only the fields in [data] change (amount, categoryName, note ...) and the server keeps
  /// the wallet in step. The owner comes from the login token. A refusal reaches the caller as a DioException.
  Future<void> updateTransaction(String id, Map<String, dynamic> data) async {
    await _dio.put('/api/transactions/$id', data: data);
    notifyDataChanged();
  }

  /// Uploads a photo and returns its link. A refusal or a failure of the request (400, 413, 503, no network) reaches
  /// the caller as a DioException, and an answer without a link as a FormatException: the caller tells the user.
  Future<String> uploadImage(String imagePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imagePath,
        filename: imagePath.split(Platform.pathSeparator).last,
      ),
    });
    final res = await _dio.post('/api/upload', data: formData);
    final body = res.data;
    if (body is Map) {
      final url = body['url'] ?? (body['data'] as Map?)?['url'];
      if (url != null) return url.toString();
    }
    throw const FormatException('core-backend sent no link for the photo');
  }

  Future<bool> deleteTransaction(String id) async {
    try {
      final res = await _dio.delete('/api/transactions/$id');
      notifyDataChanged();

      return res.data['code'] == 200;
    } catch (e) {
      debugPrint("LỖI XÓA GIAO DỊCH: $e");
      return false;
    }
  }
}
