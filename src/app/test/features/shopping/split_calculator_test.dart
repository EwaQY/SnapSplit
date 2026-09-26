import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/errors/app_exception.dart';
import 'package:snap_split/src/features/shopping/domain/split_calculator.dart';

/// T2-1：分摊数学正确，`sum == finalAmount` 恒成立。
void main() {
  group('T2-1 calcSplit', () {
    test('整除：3500 分 4 人各 875', () {
      final List<SplitShare> shares = calcSplit(
        finalAmount: 3500,
        participantIds: <String>['a', 'b', 'c', 'd'],
        payerId: 'a',
      );
      expect(
        shares.map((SplitShare e) => e.shareAmount),
        <int>[875, 875, 875, 875],
      );
    });

    test('整除：100 分 B/C 各 50', () {
      final List<SplitShare> shares = calcSplit(
        finalAmount: 100,
        participantIds: <String>['b', 'c'],
        payerId: 'a',
      );
      expect(
        shares.map((SplitShare e) => e.shareAmount),
        <int>[50, 50],
      );
    });

    test('除不尽垫付人在内：100 分 3 人余 1 归垫付人', () {
      final List<SplitShare> shares = calcSplit(
        finalAmount: 100,
        participantIds: <String>['a', 'b', 'c'],
        payerId: 'a',
      );
      expect(
        shares.map((SplitShare e) => e.shareAmount),
        <int>[34, 33, 33],
      );
    });

    test('除不尽垫付人不在内：101 分 B/C 余 1 归并列首位', () {
      final List<SplitShare> shares = calcSplit(
        finalAmount: 101,
        participantIds: <String>['b', 'c'],
        payerId: 'a',
      );
      expect(
        shares.map((SplitShare e) => e.shareAmount),
        <int>[51, 50],
      );
    });

    test('按比例：600 分 2:1 与 100 分三等份', () {
      final List<SplitShare> ratio = calcSplit(
        finalAmount: 600,
        participantIds: <String>['a', 'b'],
        payerId: 'a',
        mode: SplitMode.ratio,
        ratios: <double>[2, 1],
      );
      expect(
        ratio.map((SplitShare e) => e.shareAmount),
        <int>[400, 200],
      );
      final List<SplitShare> thirds = calcSplit(
        finalAmount: 100,
        participantIds: <String>['a', 'b', 'c'],
        payerId: 'a',
        mode: SplitMode.ratio,
        ratios: <double>[1, 1, 1],
      );
      expect(
        thirds.map((SplitShare e) => e.shareAmount),
        <int>[34, 33, 33],
      );
    });

    test('按金额：加总一致通过，不一致抛错', () {
      final List<SplitShare> shares = calcSplit(
        finalAmount: 100,
        participantIds: <String>['a', 'b'],
        payerId: 'a',
        mode: SplitMode.amount,
        amounts: <int>[60, 40],
      );
      expect(
        shares.map((SplitShare e) => e.shareAmount),
        <int>[60, 40],
      );
      expect(
        () => calcSplit(
          finalAmount: 100,
          participantIds: <String>['a', 'b'],
          payerId: 'a',
          mode: SplitMode.amount,
          amounts: <int>[60, 39],
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('负数退款：-100 分 3 人和为 -100', () {
      final List<SplitShare> shares = calcSplit(
        finalAmount: -100,
        participantIds: <String>['a', 'b', 'c'],
        payerId: 'a',
      );
      expect(
        shares.map((SplitShare e) => e.shareAmount),
        <int>[-34, -33, -33],
      );
      expect(
        shares.fold(0, (int sum, SplitShare e) => sum + e.shareAmount),
        -100,
      );
    });

    test('非法输入抛错', () {
      expect(
        () => calcSplit(
          finalAmount: 100,
          participantIds: const <String>[],
          payerId: 'a',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => calcSplit(
          finalAmount: 100,
          participantIds: <String>['a', 'b'],
          payerId: 'a',
          mode: SplitMode.ratio,
          ratios: <double>[1],
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
