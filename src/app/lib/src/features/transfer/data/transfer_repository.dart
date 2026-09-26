import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/app_time.dart';
import '../../../core/utils/ids.dart';

/// 转账 Repository：转账/结算记录的唯一数据源。
///
/// - 不计消费，只冲销余额；默认 `我 → 对方` 由调用方组装。
/// - 仅当前周期可建改删，历史周期抛 [ArchivedReadOnlyException]。
/// - 双方须为账本活跃成员，且不能相同。
class TransferRepository {
  TransferRepository(this._db);

  final AppDatabase _db;

  /// 建转账记录。
  Future<Transfer> createTransfer({
    required String ledgerId,
    required String fromUserId,
    required String toUserId,
    required int amountCents,
    int? occurredAt,
    String? note,
  }) async {
    final int occurred = occurredAt ?? nowUnixSeconds();
    _requireCurrentPeriod(occurred);
    _requireValidParties(fromUserId, toUserId, amountCents);
    await _requireMembers(ledgerId, <String>{fromUserId, toUserId});
    final int now = nowUnixSeconds();
    final String id = newId();
    await _db
        .into(_db.transfers)
        .insert(
          TransfersCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            fromUserId: fromUserId,
            toUserId: toUserId,
            amount: amountCents,
            occurredAt: occurred,
            note: Value(note),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return getById(id);
  }

  /// 取转账记录，不存在抛 [NotFoundException]。
  Future<Transfer> getById(String id) async {
    final Transfer? transfer =
        await (_db.select(_db.transfers)
              ..where(
                (Transfers t) => t.id.equals(id) & t.deletedAt.isNull(),
              )).getSingleOrNull();
    if (transfer == null) {
      throw NotFoundException('转账记录不存在：$id');
    }
    return transfer;
  }

  /// 改转账记录（仅当前周期：原发生时间与新发生时间都须是当期）。
  Future<Transfer> updateTransfer(
    String id, {
    int? amountCents,
    int? occurredAt,
    String? note,
  }) async {
    final Transfer current = await getById(id);
    _requireCurrentPeriod(current.occurredAt);
    final int occurred = occurredAt ?? current.occurredAt;
    _requireCurrentPeriod(occurred);
    if (amountCents != null && amountCents <= 0) {
      throw ValidationException('转账金额必须大于 0');
    }
    await (_db.update(_db.transfers)..where(
          (Transfers t) => t.id.equals(id),
        )).write(
      TransfersCompanion(
        amount: amountCents == null ? const Value.absent() : Value(amountCents),
        occurredAt: Value(occurred),
        note: note == null ? const Value.absent() : Value(note),
        updatedAt: Value(nowUnixSeconds()),
      ),
    );
    return getById(id);
  }

  /// 软删转账记录（仅当前周期）。
  Future<void> softDeleteTransfer(String id) async {
    final Transfer current = await getById(id);
    _requireCurrentPeriod(current.occurredAt);
    final int now = nowUnixSeconds();
    await (_db.update(_db.transfers)..where(
          (Transfers t) => t.id.equals(id),
        )).write(
      TransfersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// 账本转账列表（发生时间倒序，默认排除软删）。
  Future<List<Transfer>> listTransfers(String ledgerId) =>
      (_db.select(_db.transfers)
            ..where(
              (Transfers t) =>
                  t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
            )
            ..orderBy([
              (Transfers t) => OrderingTerm.desc(t.occurredAt),
              (_) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
            ]))
          .get();

  void _requireValidParties(String from, String to, int amount) {
    if (from == to) {
      throw ValidationException('转账双方不能相同');
    }
    if (amount <= 0) {
      throw ValidationException('转账金额必须大于 0');
    }
  }

  void _requireCurrentPeriod(int occurredAt) {
    if (isArchivedPeriod(occurredAt)) {
      throw ArchivedReadOnlyException('历史周期转账记录只读，不可写入');
    }
  }

  Future<void> _requireMembers(String ledgerId, Set<String> userIds) async {
    final List<LedgerMember> members =
        await (_db.select(_db.ledgerMembers)..where(
              (LedgerMembers t) =>
                  t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
            )).get();
    final Set<String> memberIds = <String>{
      for (final LedgerMember member in members) member.userId,
    };
    for (final String userId in userIds) {
      if (!memberIds.contains(userId)) {
        throw ValidationException('非账本活跃成员：$userId');
      }
    }
  }
}
