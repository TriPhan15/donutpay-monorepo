part of 'remote_api_helper.dart';

/// Savings goals and the wallet balance.
extension RemoteApiSavings on RemoteApiHelper {
  /// Throws when the savings cannot be read (or are not a list of goals), so a screen can tell "none" from "could not
  /// load".
  Future<List<SavingsGoal>> fetchSavings() async {
    final res = await _dio.get('/api/savings');
    final goals = List<Map<String, dynamic>>.from(res.data['data'] ?? []);
    return [for (final goal in goals) SavingsGoal.fromJson(goal)];
  }

  /// POST /api/savings: a new goal with nothing saved yet. The server sends no goal back and the answer is not read.
  /// A missing [deadline] is left out of the body.
  Future<void> addSaving({
    required String title,
    required double target,
    String? deadline,
  }) async {
    await _dio.post(
      '/api/savings',
      data: {'title': title, 'target': target, 'deadline': ?deadline},
    );
    notifyDataChanged();
  }

  /// PUT /api/savings/{id}: the name, target and deadline of a goal. The body never carries `current` (the server
  /// refuses it: the saved amount only moves through contributions). The server treats a missing [deadline] as "clear
  /// it", so a caller keeping the deadline must pass it.
  Future<void> updateSaving(
    String id, {
    required String title,
    required double target,
    String? deadline,
  }) async {
    await _dio.put(
      '/api/savings/$id',
      data: {'title': title, 'target': target, 'deadline': deadline},
    );
    notifyDataChanged();
  }

  Future<void> deleteSaving(String id) async {
    await _dio.delete('/api/savings/$id');
    notifyDataChanged();
  }

  /// POST /api/savings/{id}/contributions: moves [amount] from the wallet into the goal [id]. The server records it as
  /// an expense in the "Tiết kiệm" category, so the balance and the Ledger change too. Returns the goal as it is now;
  /// throws when it is refused (e.g. 400 when the wallet is too low) or when the answer holds no goal.
  Future<SavingsGoal> contributeToSaving(String id, double amount) async {
    final res = await _dio.post(
      '/api/savings/$id/contributions',
      data: {'amount': amount},
    );
    notifyDataChanged();
    return SavingsGoal.fromJson(
      Map<String, dynamic>.from(res.data['data'] as Map),
    );
  }

  /// The wallet balance the server keeps for the signed-in user; null when the answer has none. Throws when it cannot
  /// be read, or is not a number.
  Future<double?> fetchWalletBalance() async =>
      ((await fetchMe())['walletBalance'] as num?)?.toDouble();
}
