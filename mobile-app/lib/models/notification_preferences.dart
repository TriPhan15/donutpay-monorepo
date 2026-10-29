import 'package:shared_preferences/shared_preferences.dart';

/// The two switches of "Cài đặt thông báo", kept on the device. Both are on until the user turns one off. The server
/// does not know them: they only remember the user's choice between launches.
class NotificationPreferences {
  const NotificationPreferences({this.push = true, this.budgetAlert = true});

  static const String pushKey = 'notifications_push';
  static const String budgetAlertKey = 'notifications_budget_alert';

  final bool push;
  final bool budgetAlert;

  static Future<NotificationPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferences(
      push: prefs.getBool(pushKey) ?? true,
      budgetAlert: prefs.getBool(budgetAlertKey) ?? true,
    );
  }

  /// False when the device could not store one of the two values.
  Future<bool> save() async {
    final prefs = await SharedPreferences.getInstance();
    final results = await Future.wait([
      prefs.setBool(pushKey, push),
      prefs.setBool(budgetAlertKey, budgetAlert),
    ]);
    return results.every((ok) => ok);
  }

  NotificationPreferences copyWith({bool? push, bool? budgetAlert}) =>
      NotificationPreferences(
        push: push ?? this.push,
        budgetAlert: budgetAlert ?? this.budgetAlert,
      );
}
