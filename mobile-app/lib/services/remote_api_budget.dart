part of 'remote_api_helper.dart';

/// Budgets.
extension RemoteApiBudget on RemoteApiHelper {
  /// All budgets of the logged-in user, newest first. The owner comes from the login token, so nothing identifying
  /// the user is sent.
  Future<List<BudgetModel>> getBudgets() async {
    final res = await _dio.get('/api/budgets');
    final items = (res.data['data'] as List?) ?? [];
    return items
        .map(
          (item) =>
              BudgetModel.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<BudgetModel> createBudget(BudgetModel budget) async {
    final res = await _dio.post('/api/budgets', data: budget.toJson());
    notifyDataChanged();
    return BudgetModel.fromJson(
      Map<String, dynamic>.from(res.data['data'] as Map),
    );
  }

  Future<BudgetModel> updateBudget(BudgetModel budget) async {
    final res = await _dio.put(
      '/api/budgets/${budget.id}',
      data: budget.toJson(),
    );
    notifyDataChanged();
    return BudgetModel.fromJson(
      Map<String, dynamic>.from(res.data['data'] as Map),
    );
  }

  Future<void> deleteBudget(int budgetId) async {
    await _dio.delete('/api/budgets/$budgetId');
    notifyDataChanged();
  }
}
