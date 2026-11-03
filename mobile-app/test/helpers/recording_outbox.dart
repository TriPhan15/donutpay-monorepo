import 'package:finance_ai_app/services/sqflite_helper.dart';

/// The SQLite outbox of a sign-out without a real database: a real sqflite call cannot finish inside the fake-async
/// zone of a widget test. Records the users whose synced rows were asked to be removed.
class RecordingOutbox implements SqfliteHelper {
  final List<int> cleaned = [];

  @override
  Future<int> deleteSyncedTransactions(int userId) async {
    cleaned.add(userId);
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
