import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/database/app_database.dart';
import 'package:snap_split/src/core/errors/app_exception.dart';
import 'package:snap_split/src/core/utils/app_time.dart';
import 'package:snap_split/src/features/budget/data/budget_repository.dart';
import 'package:snap_split/src/features/ledger/data/ledger_repository.dart';
import 'package:snap_split/src/features/profile/data/user_repository.dart';
import 'package:snap_split/src/features/shopping/data/shopping_repository.dart';

/// T3-3：预算设置与进度（全局跨账本，只计付款账目，按发生月落月）。
void main() {
  late AppDatabase db;
  late UserRepository users;
  late LedgerRepository ledgers;
  late ShoppingRepository shopping;
  late BudgetRepository budgets;

  late User self;
  late User ming;

  setUp(() async {
    db = AppDatabase.memory();
    users = UserRepository(db);
    ledgers = LedgerRepository(db);
    shopping = ShoppingRepository(db);
    budgets = BudgetRepository(db);
    self = await users.ensureSelf();
    ming = await users.createVirtualMember(nickname: '小明');
  });

  tearDown(() async {
    await db.close();
  });

  test('设预算同月覆盖，进度跨账本累加付款账目', () async {
    final ({int month, int year}) now = yearMonthOf(nowUnixSeconds());
    final Ledger home = await ledgers.createLedger(
      name: '合租',
      ownerUserId: self.id,
    );
    final Ledger dinner = await ledgers.createLedger(
      name: '聚餐',
      ownerUserId: self.id,
    );
    await ledgers.addMember(ledgerId: home.id, userId: ming.id);
    await ledgers.addMember(ledgerId: dinner.id, userId: ming.id);

    // 我付 3000（合租）+ 我付 2000（聚餐）+ 小明付 9999（不计）。
    await shopping.createSingleItem(
      ledgerId: home.id,
      name: 'a',
      quantity: 1,
      unitPrice: 3000,
      finalAmount: 3000,
      payerId: self.id,
      participantIds: <String>[self.id, ming.id],
    );
    await shopping.createSingleItem(
      ledgerId: dinner.id,
      name: 'b',
      quantity: 1,
      unitPrice: 2000,
      finalAmount: 2000,
      payerId: self.id,
      participantIds: <String>[self.id],
    );
    await shopping.createSingleItem(
      ledgerId: home.id,
      name: 'c',
      quantity: 1,
      unitPrice: 9999,
      finalAmount: 9999,
      payerId: ming.id,
      participantIds: <String>[ming.id],
    );

    await budgets.setBudget(
      userId: self.id,
      year: now.year,
      month: now.month,
      amountCents: 10000,
    );
    BudgetProgress progress = await budgets.getProgress(
      userId: self.id,
      year: now.year,
      month: now.month,
    );
    expect((progress.budget, progress.spent, progress.overBudget), (
      10000,
      5000,
      false,
    ));

    // 同月覆盖为 4000 → 超支。
    await budgets.setBudget(
      userId: self.id,
      year: now.year,
      month: now.month,
      amountCents: 4000,
    );
    progress = await budgets.getProgress(
      userId: self.id,
      year: now.year,
      month: now.month,
    );
    expect((progress.budget, progress.spent, progress.overBudget), (
      4000,
      5000,
      true,
    ));
  });

  test('历史月不可设但可查，未设预算进度无上限', () async {
    final ({int month, int year}) now = yearMonthOf(nowUnixSeconds());
    final DateTime past = DateTime(now.year, now.month - 1, 10);
    await expectLater(
      budgets.setBudget(
        userId: self.id,
        year: past.year,
        month: past.month,
        amountCents: 100,
      ),
      throwsA(isA<ArchivedReadOnlyException>()),
    );
    await expectLater(
      budgets.setBudget(
        userId: self.id,
        year: now.year,
        month: 13,
        amountCents: 100,
      ),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      budgets.setBudget(
        userId: self.id,
        year: now.year,
        month: now.month,
        amountCents: -1,
      ),
      throwsA(isA<ValidationException>()),
    );
    final BudgetProgress progress = await budgets.getProgress(
      userId: self.id,
      year: past.year,
      month: past.month,
    );
    expect((progress.budget, progress.spent, progress.overBudget), (
      null,
      0,
      false,
    ));
  });
}
