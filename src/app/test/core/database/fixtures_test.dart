import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/database/app_database.dart';
import 'package:snap_split/src/features/tags/data/tag_repository.dart';

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
    expect(await count(db.tags), 11);
    expect(await count(db.ledgers), 2);
    expect(await count(db.ledgerMembers), 7);
    expect(await count(db.shoppingLists), 4);
    expect(await count(db.expenseItems), 9);
    expect(await count(db.itemTags), 10);
    expect(await count(db.itemParticipants), 28);
    expect(await count(db.transfers), 1);
    expect(await count(db.budgets), 2);
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

    // 当月预算：年月恒为执行时当月（首页预算卡有数）。
    final DateTime now = DateTime.now();
    final Budget current = await (db.select(
      db.budgets,
    )..where((t) => t.id.equals('budget-002'))).getSingle();
    expect(
      (current.year, current.month, current.amount),
      (now.year, now.month, 500000),
    );
  });

  test('首页相关动态真数', () async {
    final int nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    const int daySec = 24 * 3600;
    final DateTime now = DateTime.now();

    // 窗内三单 + 转账相对 now 落在近 7 天里。
    Future<int> occurredOf(String id) => (db.select(
      db.shoppingLists,
    )..where((t) => t.id.equals(id))).getSingle().then(
      (ShoppingList e) => e.occurredAt,
    );
    expect(await occurredOf('sl-001'), greaterThan(nowSec - 7 * daySec));
    expect(await occurredOf('sl-003'), greaterThan(nowSec - 7 * daySec));
    final Transfer transfer = await (db.select(
      db.transfers,
    )..where((t) => t.id.equals('tr-001'))).getSingle();
    expect(transfer.occurredAt, greaterThan(nowSec - 7 * daySec));

    // sl-004 窗外旧账：早于 7 天窗口。
    expect(await occurredOf('sl-004'), lessThan(nowSec - 7 * daySec));

    // sl-001 恒在当月（首页预算卡恒有数）。
    final int monthStart =
        DateTime(now.year, now.month, 1).millisecondsSinceEpoch ~/ 1000;
    expect(await occurredOf('sl-001'), greaterThanOrEqualTo(monthStart));

    // 归档标签不在活跃列表（筛选器不可见）。
    final List<Tag> active = await TagRepository(db).listActiveTags();
    expect(active.length, 10);
    expect(active.map((Tag e) => e.id), isNot(contains('tag-011')));
  });
}
