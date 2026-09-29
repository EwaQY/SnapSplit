import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/errors/app_exception.dart';
import 'package:snap_split/src/features/shopping/domain/surcharge_allocator.dart';

int _sum(List<int> shares) => shares.fold(0, (int a, int b) => a + b);

/// T3-1：附加费/折扣按比例摊入，总和恒等于调整额。
void main() {
  group('T3-1 allocateAdjustment', () {
    test('多商品按比例（3000/2400/4500 + 配送 800）', () {
      final List<int> shares = allocateAdjustment(
        adjustment: 800,
        baseAmounts: <int>[3000, 2400, 4500],
      );
      expect(_sum(shares), 800);
      // 比例：3000/9900*800≈242.4→242；2400/9900*800≈193.9→194；
      // 4500/9900*800≈363.6→364；和 800 整除无差额。
      expect(shares, <int>[242, 194, 364]);
    });

    test('四舍五入差额归最大商品', () {
      // 100 按 1:1:1 分：33.33→33×3=99，差 1 给首位最大（并列取首）。
      final List<int> shares = allocateAdjustment(
        adjustment: 100,
        baseAmounts: <int>[10, 10, 10],
      );
      expect(_sum(shares), 100);
      expect(shares, <int>[34, 33, 33]);
    });

    test('折扣负数直接冲减', () {
      final List<int> shares = allocateAdjustment(
        adjustment: -1500,
        baseAmounts: <int>[8000, 12000],
      );
      expect(_sum(shares), -1500);
      expect(shares, <int>[-600, -900]);
    });

    test('单商品全额计入', () {
      expect(
        allocateAdjustment(adjustment: 800, baseAmounts: <int>[2500]),
        <int>[800],
      );
      expect(
        allocateAdjustment(adjustment: -1500, baseAmounts: <int>[2500]),
        <int>[-1500],
      );
    });

    test('基数全 0 时均摊兜底', () {
      final List<int> shares = allocateAdjustment(
        adjustment: 100,
        baseAmounts: <int>[0, 0, 0],
      );
      expect(_sum(shares), 100);
      expect(shares, <int>[34, 33, 33]);
    });

    test('空列表抛错', () {
      expect(
        () => allocateAdjustment(adjustment: 100, baseAmounts: const <int>[]),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
