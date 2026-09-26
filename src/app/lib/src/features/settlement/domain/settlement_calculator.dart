/// 单条分摊事实：参与人 `userId` 欠付款人 `payerId` 金额 `shareAmount`（分）。
typedef ExpenseShare = ({
  String payerId,
  String userId,
  int shareAmount,
});

/// 单条转账事实：`fromUserId` 向 `toUserId` 支付 `amount`（分）。
typedef TransferFact = ({
  String fromUserId,
  String toUserId,
  int amount,
});

/// 我视角两两净额：正数表示我欠对方，负数表示对方欠我；结平（0）的不列出。
typedef SelfNet = ({String otherUserId, int netAmount});

/// 全局成员净额：正数表示应收，负数表示应付。
typedef GlobalNet = ({String userId, int netAmount});

/// 结算板：我视角净额 + 全局净额，不做最优转账。
typedef SettlementBoard = ({
  List<SelfNet> selfNets,
  List<GlobalNet> globalNets,
});

/// 结算计算器：纯函数，无 DB 依赖。
///
/// 记 `debt[a→b]` 为 a 欠 b 的累计金额：
/// - 每条分摊：`debt[参与人→付款人] += share`；
/// - 每条转账：`debt[付款方→收款方] -= amount`（核销欠款，可为负即预付）；
/// - 两两净额 = 双向相减；全局净额 = 应收合计 − 应付合计。
SettlementBoard calcSettlementBoard({
  required List<ExpenseShare> shares,
  required List<TransferFact> transfers,
  required String selfId,
}) {
  final Map<(String, String), int> debt = <(String, String), int>{};

  void addDebt(String from, String to, int amount) {
    if (from == to || amount == 0) {
      return;
    }
    debt[(from, to)] = (debt[(from, to)] ?? 0) + amount;
  }

  for (final ExpenseShare share in shares) {
    if (share.shareAmount == 0) {
      continue;
    }
    addDebt(share.userId, share.payerId, share.shareAmount);
  }
  for (final TransferFact transfer in transfers) {
    addDebt(transfer.fromUserId, transfer.toUserId, -transfer.amount);
  }

  int pairNet(String a, String b) =>
      (debt[(a, b)] ?? 0) - (debt[(b, a)] ?? 0);

  final Set<String> users = <String>{
    selfId,
    for (final ExpenseShare share in shares) ...<String>[
      share.payerId,
      share.userId,
    ],
    for (final TransferFact transfer in transfers) ...<String>[
      transfer.fromUserId,
      transfer.toUserId,
    ],
  }..remove(selfId);

  final List<SelfNet> selfNets = <SelfNet>[
    for (final String other in users)
      if (pairNet(selfId, other) != 0)
        (otherUserId: other, netAmount: pairNet(selfId, other)),
  ]..sort((SelfNet a, SelfNet b) => a.otherUserId.compareTo(b.otherUserId));

  final Set<String> everyone = <String>{
    for (final ExpenseShare share in shares) ...<String>[
      share.payerId,
      share.userId,
    ],
    for (final TransferFact transfer in transfers) ...<String>[
      transfer.fromUserId,
      transfer.toUserId,
    ],
  };
  final List<GlobalNet> globalNets = <GlobalNet>[
    for (final String user in everyone)
      (
        userId: user,
        netAmount: _globalNet(user, debt, everyone),
      ),
  ]..sort((GlobalNet a, GlobalNet b) => a.userId.compareTo(b.userId));

  return (selfNets: selfNets, globalNets: globalNets);
}

/// 某成员全局净额 = 他人欠他合计 − 他欠他人合计。
int _globalNet(
  String user,
  Map<(String, String), int> debt,
  Set<String> everyone,
) {
  int net = 0;
  for (final String other in everyone) {
    if (other == user) {
      continue;
    }
    net += (debt[(other, user)] ?? 0) - (debt[(user, other)] ?? 0);
  }
  return net;
}
