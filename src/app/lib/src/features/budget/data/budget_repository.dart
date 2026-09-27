import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/utils/app_time.dart';
import '../../../core/utils/ids.dart';

/// 预算进度：预算（分，未设置则 null）、已消费（分）、是否超支。
///
/// 已消费 = 该自然月内用户作为付款人的全部账目 `finalAmount` 之和
/// （全局粒度，跨账本；发生月份按购物单 `occurred_at`）。
typedef BudgetProgress = ({int? budget, int spent, bool overBudget});

/// 周期预算 Repository（自然月，全局粒度）。
///
/// - 仅当月可设（含未来月放行，历史月抛 [ArchivedReadOnlyException]）。
/// - 超支仅标识，不阻断记账。
class BudgetRepository {
  BudgetRepository(this._db);

  final AppDatabase _db;

  /// 设置某月预算（同用户同月幂等覆盖）。
  Future<Budget> setBudget({
    required String userId,
    required int year,
    required int month,
    required int amountCents,
  }) => AppLogger.audit(
    action: 'budget.setBudget',
    entity: 'budget',
    run: () async {
      if (month < 1 || month > 12) {
        throw ValidationException('月份非法：$month');
      }
      if (amountCents < 0) {
        throw ValidationException('预算金额不能为负');
      }
      final ({int month, int year}) now = yearMonthOf(nowUnixSeconds());
      if (year < now.year || (year == now.year && month < now.month)) {
        throw ArchivedReadOnlyException('历史周期预算不可变');
      }
      final int nowSeconds = nowUnixSeconds();
      final Budget? existing =
          await (_db.select(_db.budgets)
                ..where(
                  (t) =>
                      t.userId.equals(userId) &
                      t.year.equals(year) &
                      t.month.equals(month) &
                      t.deletedAt.isNull(),
                )).getSingleOrNull();
      if (existing == null) {
        final String id = newId();
        await _db
            .into(_db.budgets)
            .insert(
              BudgetsCompanion.insert(
                id: id,
                userId: userId,
                amount: amountCents,
                year: year,
                month: month,
                createdAt: nowSeconds,
                updatedAt: nowSeconds,
              ),
            );
        return (_db.select(_db.budgets)
              ..where((t) => t.id.equals(id))).getSingle();
      }
      await (_db.update(_db.budgets)..where(
            (t) => t.id.equals(existing.id),
          )).write(
        BudgetsCompanion(
          amount: Value(amountCents),
          updatedAt: Value(nowSeconds),
        ),
      );
      return (_db.select(_db.budgets)
            ..where((t) => t.id.equals(existing.id))).getSingle();
    },
  );

  /// 取某月预算，未设置返回 null。
  Future<Budget?> getBudget({
    required String userId,
    required int year,
    required int month,
  }) =>
      (_db.select(_db.budgets)..where(
            (Budgets t) =>
                t.userId.equals(userId) &
                t.year.equals(year) &
                t.month.equals(month) &
                t.deletedAt.isNull(),
          )).getSingleOrNull();

  /// 取某月预算进度（支持查历史月，归档数据只读）。
  Future<BudgetProgress> getProgress({
    required String userId,
    required int year,
    required int month,
  }) async {
    final ({int end, int start}) bounds = monthBounds(year, month);
    final JoinedSelectStatement query = _db
        .select(_db.expenseItems)
        .join([
          innerJoin(
            _db.shoppingLists,
            _db.shoppingLists.id.equalsExp(_db.expenseItems.shoppingListId),
          ),
        ])
      ..where(
        _db.expenseItems.payerId.equals(userId) &
            _db.expenseItems.deletedAt.isNull() &
            _db.shoppingLists.deletedAt.isNull() &
            _db.shoppingLists.occurredAt.isBiggerOrEqualValue(bounds.start) &
            _db.shoppingLists.occurredAt.isSmallerOrEqualValue(bounds.end),
      );
    final List<TypedResult> rows = await query.get();
    final int spent = rows.fold(
      0,
      (int sum, TypedResult row) =>
          sum + row.readTable(_db.expenseItems).finalAmount,
    );
    final Budget? budget = await getBudget(
      userId: userId,
      year: year,
      month: month,
    );
    return (
      budget: budget?.amount,
      spent: spent,
      overBudget: budget != null && spent > budget.amount,
    );
  }
}
