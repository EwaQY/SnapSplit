import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/utils/app_time.dart';

int _unix(int year, int month, int day, [int hour = 12]) =>
    DateTime(year, month, day, hour).millisecondsSinceEpoch ~/ 1000;

void main() {
  group('T0-5 app_time', () {
    test('自然月边界（含 2 月与跨年）', () {
      final ({int end, int start}) feb = monthBounds(2026, 2);
      expect(
        DateTime.fromMillisecondsSinceEpoch(feb.start * 1000),
        DateTime(2026, 2, 1),
      );
      // 2026 非闰年，2 月末为 28 日 23:59:59。
      expect(
        DateTime.fromMillisecondsSinceEpoch(feb.end * 1000),
        DateTime(2026, 2, 28, 23, 59, 59),
      );

      final ({int end, int start}) dec = monthBounds(2026, 12);
      expect(
        DateTime.fromMillisecondsSinceEpoch(dec.start * 1000),
        DateTime(2026, 12, 1),
      );
      expect(
        DateTime.fromMillisecondsSinceEpoch(dec.end * 1000),
        DateTime(2026, 12, 31, 23, 59, 59),
      );
    });

    test('归档判断：同月非归档，跨月归档', () {
      final int now = _unix(2026, 9, 22);
      expect(isArchivedPeriod(_unix(2026, 9, 1), nowSeconds: now), isFalse);
      expect(isArchivedPeriod(_unix(2026, 9, 30, 23), nowSeconds: now), isFalse);
      expect(isArchivedPeriod(_unix(2026, 8, 31), nowSeconds: now), isTrue);
      expect(isArchivedPeriod(_unix(2025, 9, 22), nowSeconds: now), isTrue);
    });
  });
}
