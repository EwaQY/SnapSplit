import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/errors/app_exception.dart';
import 'package:snap_split/src/core/utils/money.dart';

void main() {
  group('T0-5 money', () {
    test('元分互转与格式化', () {
      expect(yuanToCents(15.0), 1500);
      expect(yuanToCents(8.75), 875);
      expect(centsToYuan(875), 8.75);
      expect(formatCents(875), '8.75');
      expect(formatCents(-150), '-1.50');
    });

    test('解析元字符串', () {
      expect(parseYuanToCents('15'), 1500);
      expect(parseYuanToCents(' 8.75 '), 875);
      expect(parseYuanToCents('8.7'), 870);
      expect(parseYuanToCents('-1.05'), -105);
      expect(parseYuanToCents('-0.01'), -1);
    });

    test('非法输入抛 ValidationException', () {
      for (final String bad in <String>[
        '',
        'abc',
        '1.234',
        '1,000',
        '--1',
        '1.',
        '.5',
      ]) {
        expect(
          () => parseYuanToCents(bad),
          throwsA(isA<ValidationException>()),
          reason: bad,
        );
      }
    });
  });
}
