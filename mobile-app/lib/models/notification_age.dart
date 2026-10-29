/// How long ago a notification was raised, in calendar days of the phone, which decides how its time is written in the
/// notification list (T9 spec 3.7: the time, with the date when it is older).
enum NotificationAge {
  today,
  yesterday,
  thisYear,
  older;

  /// A [createdAt] after [now] (the phone's clock is behind the server's) counts as today.
  static NotificationAge of(DateTime createdAt, DateTime now) {
    final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final today = DateTime(now.year, now.month, now.day);
    if (!day.isBefore(today)) return NotificationAge.today;
    if (day == DateTime(now.year, now.month, now.day - 1)) {
      return NotificationAge.yesterday;
    }
    return day.year == now.year
        ? NotificationAge.thisYear
        : NotificationAge.older;
  }
}
