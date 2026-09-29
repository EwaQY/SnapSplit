import '../../../core/errors/app_exception.dart';

/// 分摊方式（UI 层选择，底层不持久化，只存算出的具体金额）。
enum SplitMode {
  /// 均摊。
  average,

  /// 按比例。
  ratio,

  /// 按金额。
  amount,
}

/// 单个参与人的分摊结果（分）。
typedef SplitShare = ({String userId, int shareAmount});

/// 分摊计算器：纯函数，无 DB 依赖。
///
/// 规则：
/// - 参与人 ≥ 1，否则抛 [ValidationException]；去重后仍 ≥ 1。
/// - 付款人可以不在参与人中。
/// - 余数（除不尽/四舍五入差额）优先给垫付人；垫付人不在参与人中时，
///   给参与人中份额最大者（并列取列表首位）；保证 `sum == finalAmount`。
/// - 支持负数 `finalAmount`（折扣/退款冲减）。
List<SplitShare> calcSplit({
  required int finalAmount,
  required List<String> participantIds,
  required String payerId,
  SplitMode mode = SplitMode.average,
  List<double>? ratios,
  List<int>? amounts,
}) {
  final List<String> participants = participantIds.toSet().toList();
  if (participants.isEmpty) {
    throw ValidationException('分摊参与人不能为空');
  }
  final List<int> base = switch (mode) {
    SplitMode.average => _average(finalAmount, participants.length),
    SplitMode.ratio => _byRatio(
      finalAmount,
      ratios,
      participants.length,
    ),
    SplitMode.amount => _byAmount(finalAmount, amounts, participants.length),
  };
  final int diff = finalAmount - base.fold(0, (int a, int b) => a + b);
  final int recipient = _recipientIndex(
    base,
    participants,
    payerId,
  );
  final List<int> shares = List<int>.of(base);
  shares[recipient] += diff;
  return <SplitShare>[
    for (int i = 0; i < participants.length; i++)
      (userId: participants[i], shareAmount: shares[i]),
  ];
}

/// 余数归属下标：垫付人在内则给垫付人，否则给份额最大者（并列取首位）。
int _recipientIndex(
  List<int> shares,
  List<String> participants,
  String payerId,
) {
  final int payerIndex = participants.indexOf(payerId);
  if (payerIndex >= 0) {
    return payerIndex;
  }
  int best = 0;
  for (int i = 1; i < shares.length; i++) {
    if (shares[i] > shares[best]) {
      best = i;
    }
  }
  return best;
}

/// 均摊：截断除法取基数，余数由调用方统一找补。
List<int> _average(int finalAmount, int n) {
  final int base = finalAmount ~/ n;
  return List<int>.filled(n, base);
}

/// 按比例：先四舍五入，差额由调用方统一找补。
List<int> _byRatio(int finalAmount, List<double>? ratios, int n) {
  if (ratios == null || ratios.length != n) {
    throw ValidationException('比例数量须与参与人数一致');
  }
  final double total = ratios.fold(0, (double a, double b) => a + b);
  if (total <= 0) {
    throw ValidationException('比例之和必须大于 0');
  }
  return <int>[
    for (final double ratio in ratios)
      (finalAmount * ratio / total).round(),
  ];
}

/// 按金额：必须加总等于最终金额，否则抛错（由 UI 层保证）。
List<int> _byAmount(int finalAmount, List<int>? amounts, int n) {
  if (amounts == null || amounts.length != n) {
    throw ValidationException('金额数量须与参与人数一致');
  }
  if (amounts.fold(0, (int a, int b) => a + b) != finalAmount) {
    throw ValidationException('指定金额加总必须等于账目金额');
  }
  return List<int>.of(amounts);
}
