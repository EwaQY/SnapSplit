import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/utils/ids.dart';

void main() {
  group('T0-5 ids', () {
    test('生成 UUID 且唯一', () {
      final Set<String> seen = <String>{for (int i = 0; i < 100; i++) newId()};
      expect(seen, hasLength(100));
      expect(
        seen.first,
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-')),
      );
    });
  });
}
