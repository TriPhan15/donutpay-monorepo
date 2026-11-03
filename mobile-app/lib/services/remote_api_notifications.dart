part of 'remote_api_helper.dart';

/// Notifications of the signed-in user.
extension RemoteApiNotifications on RemoteApiHelper {
  /// One page of the logged-in user's notifications, newest first (GET /api/notifications?page=&size=). The server
  /// fixes the order and takes the owner from the login token, so only the page is sent. A failure reaches the caller as
  /// a DioException, an answer that is not a page as a FormatException.
  Future<NotificationPage> getNotifications({
    required int page,
    required int size,
  }) async {
    final res = await _dio.get(
      '/api/notifications',
      queryParameters: {'page': page, 'size': size},
    );
    return NotificationPage.fromJson(_dataObject(res));
  }

  /// How many notifications of the logged-in user are unread (GET /api/notifications/unread-count).
  Future<int> getUnreadNotificationCount() async {
    final res = await _dio.get('/api/notifications/unread-count');
    return _dataCount(res);
  }

  /// Marks one notification as read (PATCH /api/notifications/{id}/read) and returns it as the server now has it. One
  /// that does not exist, or is not the user's, is a 404 DioException.
  Future<AppNotification> markNotificationRead(int id) async {
    final res = await _dio.patch('/api/notifications/$id/read');
    return AppNotification.fromJson(_dataObject(res));
  }

  /// Marks every unread notification of the logged-in user as read (PATCH /api/notifications/read-all) and returns
  /// how many changed.
  Future<int> markAllNotificationsRead() async {
    final res = await _dio.patch('/api/notifications/read-all');
    return _dataCount(res);
  }

  /// The `data` object of an ApiResponse.
  Map<String, dynamic> _dataObject(Response<dynamic> res) {
    final body = res.data;
    final data = body is Map ? body['data'] : null;
    if (data is! Map) {
      throw FormatException('The answer carries no data object', body);
    }
    return Map<String, dynamic>.from(data);
  }

  /// The `data` number of an ApiResponse.
  int _dataCount(Response<dynamic> res) {
    final body = res.data;
    final data = body is Map ? body['data'] : null;
    if (data is! num) {
      throw FormatException('The answer carries no count', body);
    }
    return data.toInt();
  }
}
