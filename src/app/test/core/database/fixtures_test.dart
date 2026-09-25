import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/database/app_database.dart';

import '../../fixtures/seed_fixtures.dart';

/// T0-4：自插 fixtures 对标 seed 参考值。
///
/// 行数与关键真数必须与 `docs/database/seed.sql` 一致，
/// 否则 fixtures 与基线分叉。
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await insertSeedFixtures(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> count(TableInfo<Table, dynamic> table) =>
      db.customSelect('SELECT COUNT(*) AS c FROM "${table.actualTableName}"')
          .getSingle()
          .then((QueryRow row) => row.read<int>('c'));

  test('各表行数对标', () async {
    expect(await count(db.users), 4);
    expect(await count(db.tags), 10);
    expect(await count(db.ledgers), 2);
    expect(await count(db.ledgerMembers), 7);
    expect(await count(db.shoppingLists), 3);
    expect(await count(db.expenseItems), 8);
    expect(await count(db.itemTags), 9);
    expect(await count(db.itemParticipants), 26);
    expect(await count(db.transfers), 1);
    expect(await count(db.budgets), 1);
  });

  test('关键真数', () async {
    // ei-007 蔬菜拼盘 3500 分，4 人各 875。
    final ExpenseItem veg = await (db.select(
      db.expenseItems,
    )..where((t) => t.id.equals('ei-007'))).getSingle();
    expect(veg.finalAmount, 3500);
    final List<ItemParticipant> shares =
        await (db.select(db.itemParticipants)
              ..where(
                (t) => t.expenseItemId.equals('ei-007'),
              )
              ..orderBy([
                (t) => OrderingTerm.asc(t.userId),
              ]))
            .get();
    expect(shares.map((ItemParticipant e) => e.shareAmount), <int>[
      875,
      875,
      875,
      875,
    ]);

    // 洗发水多标签：同时属于其他 + 购物。
    final List<ItemTag> ei003Tags = await (db.select(
      db.itemTags,
    )..where((t) => t.expenseItemId.equals('ei-003'))).get();
    expect(
      ei003Tags.map((ItemTag e) => e.tagId).toSet(),
      <String>{'tag-010', 'tag-003'},
    );

    // sl-002 默认参与人快照为子集（仅 user-002）。
    final ShoppingList takeout = await (db.select(
      db.shoppingLists,
    )..where((t) => t.id.equals('sl-002'))).getSingle();
    expect(takeout.defaultParticipantIds, '["user-002"]');
    expect(takeout.source, 'ai');

    // 预算 2026-09，5000 元。
    final Budget budget = await (db.select(
      db.budgets,
    )..where((t) => t.id.equals('budget-001'))).getSingle();
    expect((budget.year, budget.month, budget.amount), (2026, 9, 500000));
  });
}
