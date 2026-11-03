part of 'remote_api_helper.dart';

/// The signed-in user: profile and the review of the app.
extension RemoteApiUser on RemoteApiHelper {
  Future<Map<String, dynamic>> fetchMe() async {
    final res = await _dio.get('/api/users/me');
    return Map<String, dynamic>.from(res.data['data'] ?? {});
  }

  /// PUT /api/users/{id} with the fields of core-backend's UserUpdateDto that a user may change; a field left null is
  /// not sent and the server keeps it. The server refuses an id that is not the caller's (JWT). Returns the updated user
  /// (UserResponseDto).
  Future<Map<String, dynamic>> updateUserProfile({
    required int userId,
    String? username,
    String? phone,
  }) async {
    final res = await _dio.put(
      '/api/users/$userId',
      data: {'username': ?username, 'phone': ?phone},
    );
    return Map<String, dynamic>.from(res.data['data'] ?? {});
  }

  /// The author is the caller of the request (JWT): the body carries no user id.
  Future<bool> submitAppReview(int rating, String comment) async {
    try {
      final res = await _dio.post(
        '/api/reviews',
        data: {'rating': rating, 'comment': comment},
      );
      return res.data['code'] == 200;
    } catch (e) {
      UserFacingError.log('submitAppReview', e);
      return false;
    }
  }
}
