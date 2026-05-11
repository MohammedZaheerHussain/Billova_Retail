/// Date filter types for smart date-based reporting
enum DateFilterType {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  custom,
}

/// Helper to compute date ranges
class DateFilterHelper {
  DateFilterHelper._();

  /// Get start and end DateTime for a given filter type
  static ({DateTime start, DateTime end}) getRange(
    DateFilterType type, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    switch (type) {
      case DateFilterType.today:
        return (start: todayStart, end: todayEnd);
      case DateFilterType.yesterday:
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));
        return (start: yesterdayStart, end: todayStart);
      case DateFilterType.thisWeek:
        // Monday start
        final weekday = now.weekday;
        final weekStart = todayStart.subtract(Duration(days: weekday - 1));
        return (start: weekStart, end: todayEnd);
      case DateFilterType.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        return (start: monthStart, end: todayEnd);
      case DateFilterType.custom:
        return (
          start: customStart ?? todayStart,
          end: customEnd?.add(const Duration(days: 1)) ?? todayEnd,
        );
    }
  }

  /// Pretty label for date group headers
  static String groupLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final localDate = date.toLocal();
    final dateOnly = DateTime(localDate.year, localDate.month, localDate.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == today.subtract(const Duration(days: 1))) return 'Yesterday';
    
    // Same year → skip year
    if (localDate.year == now.year) {
      return '${_weekdayShort(localDate.weekday)}, ${localDate.day} ${_monthName(localDate.month)}';
    }
    return '${_weekdayShort(localDate.weekday)}, ${localDate.day} ${_monthName(localDate.month)} ${localDate.year}';
  }

  /// Full date label for headers
  static String fullLabel(DateTime date) {
    return '${date.day} ${_monthName(date.month)} ${date.year}';
  }

  /// Filter type display label
  static String filterLabel(DateFilterType type) {
    switch (type) {
      case DateFilterType.today: return 'Today';
      case DateFilterType.yesterday: return 'Yesterday';
      case DateFilterType.thisWeek: return 'This Week';
      case DateFilterType.thisMonth: return 'This Month';
      case DateFilterType.custom: return 'Custom';
    }
  }

  static String _weekdayShort(int wd) {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[wd];
  }

  static String _monthName(int m) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m];
  }
}
