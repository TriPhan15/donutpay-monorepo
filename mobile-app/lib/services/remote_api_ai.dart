part of 'remote_api_helper.dart';

/// The AI service: receipt scan, spending analysis, budget recommendation.
extension RemoteApiAi on RemoteApiHelper {
  Future<Map<String, dynamic>> scanReceipt(String imagePath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imagePath,
        filename: imagePath.split(Platform.pathSeparator).last,
      ),
    });
    final res = await _mlDio.post('/donut/scan', data: formData);
    return Map<String, dynamic>.from(res.data);
  }

  Future<SpendingAnalysis> analyzeSpending(
    List<Map<String, dynamic>> transactions,
  ) async {
    final res = await _mlDio.post(
      '/spade/analyze',
      data: {'transactions': transactions},
    );
    final data = res.data;
    return data is Map
        ? SpendingAnalysis.fromJson(Map<String, dynamic>.from(data))
        : SpendingAnalysis.empty;
  }

  Future<Map<String, dynamic>> recommendBudget({
    required List<Map<String, dynamic>> transactions,
    double target = 0,
    double current = 0,
    int? monthsLeft,
    double? monthlyIncome,
    double? neededMonthly,
  }) async {
    final res = await _mlDio.post(
      '/spade/recommend',
      data: {
        'transactions': transactions,
        'target': target,
        'current': current,
        // ai-service reads a missing field as 0 (no monthly need); null would be refused: the field is an int.
        'months_left': ?monthsLeft,
        'monthly_income': ?monthlyIncome,
        'needed_monthly': ?neededMonthly,
      },
    );
    return Map<String, dynamic>.from(res.data);
  }
}
