import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/features/settlement/domain/settlement_calculator.dart';

/// T4-1：结算数学正确（我视角 + 全局，不做最优转账）。
void main() {
  group('T4-1 calcSettlementBoard', () {
    // 我垫 3000（我/明/红均摊）+ 小明垫 1500（明/红均摊）。
    List<ExpenseShare> shares() => <ExpenseShare>[
      (payerId: 'me', userId: 'me', shareAmount: 1000),
      (payerId: 'me', userId: 'ming', shareAmount: 1000),
      (payerId: 'me', userId: 'hong', shareAmount: 1000),
      (payerId: 'ming', userId: 'ming', shareAmount: 750),
      (payerId: 'ming', userId: 'hong', shareAmount: 750),
    ];

    test('我视角与全局净额', () {
      final SettlementBoard board = calcSettlementBoard(
        shares: shares(),
        transfers: const <TransferFact>[],
        selfId: 'me',
      );
      // 我视角：明欠我 1000 → net -1000；红欠我 1000 → net -1000。
      // （小明自己那 750 是自付，不算债。）
      expect(board.selfNets, <SelfNet>[
        (otherUserId: 'hong', netAmount: -1000),
        (otherUserId: 'ming', netAmount: -1000),
      ]);
      // 全局：我 +2000 应收；明收 750 欠 1000 → -250 应付；
      // 红欠 1000 + 欠 750 → -1750 应付（2000-250-1750=0 守恒）。
      expect(board.globalNets, <GlobalNet>[
        (userId: 'hong', netAmount: -1750),
        (userId: 'me', netAmount: 2000),
        (userId: 'ming', netAmount: -250),
      ]);
    });

    test('转账核销后归零不列出', () {
      final SettlementBoard board = calcSettlementBoard(
        shares: shares(),
        // 红还我 1000、明还我 1000、红还明 750 → 全结平。
        transfers: const <TransferFact>[
          (fromUserId: 'hong', toUserId: 'me', amount: 1000),
          (fromUserId: 'ming', toUserId: 'me', amount: 1000),
          (fromUserId: 'hong', toUserId: 'ming', amount: 750),
        ],
        selfId: 'me',
      );
      expect(board.selfNets, isEmpty);
      expect(
        board.globalNets.map((GlobalNet e) => e.netAmount),
        everyElement(0),
      );
    });

    test('超额转账变负（对方欠我转我欠对方）', () {
      final SettlementBoard board = calcSettlementBoard(
        shares: shares(),
        transfers: const <TransferFact>[
          (fromUserId: 'hong', toUserId: 'me', amount: 1500),
        ],
        selfId: 'me',
      );
      // 红本欠我 1000，还 1500 → 我欠红 500；小明仍欠我 1000。
      expect(board.selfNets, <SelfNet>[
        (otherUserId: 'hong', netAmount: 500),
        (otherUserId: 'ming', netAmount: -1000),
      ]);
    });
  });
}
