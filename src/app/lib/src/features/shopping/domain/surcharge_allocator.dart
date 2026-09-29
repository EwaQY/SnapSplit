import '../../../core/errors/app_exception.dart';

/// 附加费/折扣分摊器：纯函数，无 DB 依赖。
///
/// 不生成独立账目，直接摊入各商品最终金额。返回与 `baseAmounts`
/// 等长的分摊增量（可正可负），调用方叠加到原始金额即得 `finalAmount`。
///
/// 规则：
/// - 按各商品原始金额比例分摊，四舍五入；
/// - 四舍五入差额调整到原始金额最大的商品（并列取首位）；
/// - 只有一个商品时，全额计入该商品；
/// - 总和恒等于 `adjustment`；空列表抛 [ValidationException]。
List<int> allocateAdjustment({
  required int adjustment,
  required List<int> baseAmounts,
}) {
  if (baseAmounts.isEmpty) {
    throw ValidationException('分摊基数不能为空');
  }
  if (baseAmounts.length == 1) {
    return <int>[adjustment];
  }
  final int total = baseAmounts.fold(0, (int a, int b) => a + b);
  if (total == 0) {
    // 基数全 0 时无法按比例，均摊找补（余数给首位）。
    final int base = adjustment ~/ baseAmounts.length;
    final List<int> even = List<int>.filled(baseAmounts.length, base);
    even[0] += adjustment - base * baseAmounts.length;
    return even;
  }
  final List<int> shares = <int>[
    for (final int amount in baseAmounts)
      (adjustment * amount / total).round(),
  ];
  final int diff = adjustment - shares.fold(0, (int a, int b) => a + b);
  int biggest = 0;
  for (int i = 1; i < baseAmounts.length; i++) {
    if (baseAmounts[i] > baseAmounts[biggest]) {
      biggest = i;
    }
  }
  shares[biggest] += diff;
  return shares;
}
