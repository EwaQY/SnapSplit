// 时间工具：所有时间字段使用 Unix 秒（INTEGER）。
//
// 周期为自然月（本地时区，1 日 00:00:00 至月末 23:59:59）。

/// 当前时间的 Unix 秒。
int nowUnixSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// 指定自然月的起止 Unix 秒（均为闭区间，本地时区）。
///
/// 返回 record：[start] 为 1 日 00:00:00，[end] 为月末 23:59:59。
({int start, int end}) monthBounds(int year, int month) {
  final DateTime start = DateTime(year, month, 1);
  final DateTime nextMonth = month == 12
      ? DateTime(year + 1, 1, 1)
      : DateTime(year, month + 1, 1);
  final int startSeconds = start.millisecondsSinceEpoch ~/ 1000;
  final int endSeconds = nextMonth.millisecondsSinceEpoch ~/ 1000 - 1;
  return (start: startSeconds, end: endSeconds);
}

/// Unix 秒对应的年月。
({int year, int month}) yearMonthOf(int unixSeconds) {
  final DateTime date = DateTime.fromMillisecondsSinceEpoch(
    unixSeconds * 1000,
  );
  return (year: date.year, month: date.month);
}

/// [occurredAt] 是否属于历史周期（与当前自然月不同即为已归档）。
bool isArchivedPeriod(int occurredAt, {int? nowSeconds}) {
  final ({int month, int year}) occurred = yearMonthOf(occurredAt);
  final ({int month, int year}) now = yearMonthOf(
    nowSeconds ?? nowUnixSeconds(),
  );
  return occurred.year != now.year || occurred.month != now.month;
}
