import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../domain/settlement_calculator.dart';

/// 结算 Repository：以账本全量分摊 + 转账聚合结算板（只读聚合，不写库）。
///
/// 口径：全周期未软删数据（历史周期只读参与，不可改）。
class SettlementRepository {
  SettlementRepository(this._db);

  final AppDatabase _db;

  /// 计算账本结算板。
  Future<SettlementBoard> calcBoard({
    required String ledgerId,
    required String selfId,
  }) async {
    final List<ExpenseItem> items =
        await (_db.select(_db.expenseItems)..where(
              (ExpenseItems t) =>
                  t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
            )).get();
    final List<ExpenseShare> shares = <ExpenseShare>[];
    for (final ExpenseItem item in items) {
      final List<ItemParticipant> participants =
          await (_db.select(_db.itemParticipants)..where(
                (ItemParticipants t) =>
                    t.expenseItemId.equals(item.id) & t.deletedAt.isNull(),
              )).get();
      for (final ItemParticipant participant in participants) {
        shares.add(
          (
            payerId: item.payerId,
            userId: participant.userId,
            shareAmount: participant.shareAmount,
          ),
        );
      }
    }
    final List<Transfer> transfers =
        await (_db.select(_db.transfers)..where(
              (Transfers t) =>
                  t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
            )).get();
    return calcSettlementBoard(
      shares: shares,
      transfers: <TransferFact>[
        for (final Transfer transfer in transfers)
          (
            fromUserId: transfer.fromUserId,
            toUserId: transfer.toUserId,
            amount: transfer.amount,
          ),
      ],
      selfId: selfId,
    );
  }
}
