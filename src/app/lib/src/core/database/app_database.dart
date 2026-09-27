import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// 索引语句：从 `docs/database/schema.sql` 原文搬运（含 4 个 partial 唯一索引）。
///
/// drift 表类只表达列/主键/外键；索引无声明式写法，统一在此用原文执行，
/// 索引名与语义与 v1 快照完全一致，等价性测试锁定。
const List<String> kIndexStatements = <String>[
  'CREATE INDEX IF NOT EXISTS "idx_user_is_self" ON "user" ("is_self")',
  'CREATE INDEX IF NOT EXISTS "idx_user_deleted_at" ON "user" ("deleted_at")',
  'CREATE INDEX IF NOT EXISTS "idx_ledger_owner" ON "ledger" ("owner_user_id")',
  'CREATE INDEX IF NOT EXISTS "idx_ledger_deleted_at" ON "ledger" ("deleted_at")',
  'CREATE INDEX IF NOT EXISTS "idx_ledger_member_ledger" ON "ledger_member" ("ledger_id")',
  'CREATE INDEX IF NOT EXISTS "idx_ledger_member_user" ON "ledger_member" ("user_id")',
  'CREATE INDEX IF NOT EXISTS "idx_ledger_member_deleted_at" ON "ledger_member" ("deleted_at")',
  'CREATE UNIQUE INDEX IF NOT EXISTS "idx_ledger_member_unique" ON "ledger_member" ("ledger_id", "user_id") WHERE "deleted_at" IS NULL',
  'CREATE INDEX IF NOT EXISTS "idx_shopping_list_ledger" ON "shopping_list" ("ledger_id")',
  'CREATE INDEX IF NOT EXISTS "idx_shopping_list_occurred_at" ON "shopping_list" ("occurred_at")',
  'CREATE INDEX IF NOT EXISTS "idx_shopping_list_deleted_at" ON "shopping_list" ("deleted_at")',
  'CREATE INDEX IF NOT EXISTS "idx_expense_item_shopping_list" ON "expense_item" ("shopping_list_id")',
  'CREATE INDEX IF NOT EXISTS "idx_expense_item_ledger" ON "expense_item" ("ledger_id")',
  'CREATE INDEX IF NOT EXISTS "idx_expense_item_payer" ON "expense_item" ("payer_id")',
  'CREATE INDEX IF NOT EXISTS "idx_expense_item_deleted_at" ON "expense_item" ("deleted_at")',
  'CREATE INDEX IF NOT EXISTS "idx_item_participant_item" ON "item_participant" ("expense_item_id")',
  'CREATE INDEX IF NOT EXISTS "idx_item_participant_user" ON "item_participant" ("user_id")',
  'CREATE INDEX IF NOT EXISTS "idx_item_participant_deleted_at" ON "item_participant" ("deleted_at")',
  'CREATE UNIQUE INDEX IF NOT EXISTS "idx_item_participant_unique" ON "item_participant" ("expense_item_id", "user_id") WHERE "deleted_at" IS NULL',
  'CREATE INDEX IF NOT EXISTS "idx_transfer_ledger" ON "transfer" ("ledger_id")',
  'CREATE INDEX IF NOT EXISTS "idx_transfer_from_user" ON "transfer" ("from_user_id")',
  'CREATE INDEX IF NOT EXISTS "idx_transfer_to_user" ON "transfer" ("to_user_id")',
  'CREATE INDEX IF NOT EXISTS "idx_transfer_occurred_at" ON "transfer" ("occurred_at")',
  'CREATE INDEX IF NOT EXISTS "idx_transfer_deleted_at" ON "transfer" ("deleted_at")',
  'CREATE INDEX IF NOT EXISTS "idx_tag_archived_at" ON "tag" ("archived_at")',
  'CREATE INDEX IF NOT EXISTS "idx_tag_deleted_at" ON "tag" ("deleted_at")',
  'CREATE UNIQUE INDEX IF NOT EXISTS "idx_tag_name_unique" ON "tag" ("name") WHERE "deleted_at" IS NULL',
  'CREATE INDEX IF NOT EXISTS "idx_item_tag_item" ON "item_tag" ("expense_item_id")',
  'CREATE INDEX IF NOT EXISTS "idx_item_tag_tag" ON "item_tag" ("tag_id")',
  'CREATE UNIQUE INDEX IF NOT EXISTS "idx_item_tag_unique" ON "item_tag" ("expense_item_id", "tag_id")',
  'CREATE INDEX IF NOT EXISTS "idx_budget_user" ON "budget" ("user_id")',
  'CREATE INDEX IF NOT EXISTS "idx_budget_year_month" ON "budget" ("year", "month")',
  'CREATE INDEX IF NOT EXISTS "idx_budget_deleted_at" ON "budget" ("deleted_at")',
  'CREATE UNIQUE INDEX IF NOT EXISTS "idx_budget_unique" ON "budget" ("user_id", "year", "month") WHERE "deleted_at" IS NULL',
];

/// 应用数据库：Dart 直连本机 SQLite 的唯一出口。
///
/// 所有访问均为异步；外键约束每次打开强制启用。
@DriftDatabase(
  tables: [
    Users,
    Ledgers,
    LedgerMembers,
    ShoppingLists,
    ExpenseItems,
    ItemParticipants,
    Transfers,
    Tags,
    ItemTags,
    Budgets,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// 打开 App 沙盒库（真机默认入口）。
  AppDatabase.appFile({String name = 'snapsplit'})
    : super(driftDatabase(name: name));

  /// 打开指定文件库（桌面 test/dev 双库入口）。
  AppDatabase.file(File file) : super(NativeDatabase(file));

  /// 打开内存库（单测入口，每次全新）。
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      for (final String statement in kIndexStatements) {
        await customStatement(statement);
      }
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from == 1) {
        await _migrateV1ToV2();
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// v1→v2：`expense_item.quantity` INTEGER→REAL。
  ///
  /// SQLite 不支持 ALTER COLUMN，整表重建（DDL 与 drift 生成逐字一致，
  /// 迁移后库与全新库无差别）。整数存量自动转为 REAL（1 → 1.0）。
  Future<void> _migrateV1ToV2() async {
    const List<String> columns = <String>[
      '"id"',
      '"shopping_list_id"',
      '"ledger_id"',
      '"name"',
      '"quantity"',
      '"unit_price"',
      '"final_amount"',
      '"payer_id"',
      '"note"',
      '"created_at"',
      '"updated_at"',
      '"deleted_at"',
    ];
    final String columnList = columns.join(', ');
    await customStatement('PRAGMA foreign_keys = OFF');
    await customStatement(
      'CREATE TABLE "expense_item_new" '
      '("id" TEXT NOT NULL, '
      '"shopping_list_id" TEXT NOT NULL REFERENCES shopping_list (id), '
      '"ledger_id" TEXT NOT NULL REFERENCES ledger (id), '
      '"name" TEXT NOT NULL, '
      '"quantity" REAL NOT NULL DEFAULT 1.0, '
      '"unit_price" INTEGER NOT NULL DEFAULT 0, '
      '"final_amount" INTEGER NOT NULL, '
      '"payer_id" TEXT NOT NULL REFERENCES user (id), '
      '"note" TEXT NULL, '
      '"created_at" INTEGER NOT NULL, '
      '"updated_at" INTEGER NOT NULL, '
      '"deleted_at" INTEGER NULL, '
      'PRIMARY KEY ("id"))',
    );
    await customStatement(
      'INSERT INTO "expense_item_new" ($columnList) '
      'SELECT $columnList FROM "expense_item"',
    );
    await customStatement('DROP TABLE "expense_item"');
    await customStatement(
      'ALTER TABLE "expense_item_new" RENAME TO "expense_item"',
    );
    for (final String statement in kIndexStatements) {
      if (statement.contains('"expense_item"')) {
        await customStatement(statement);
      }
    }
    await customStatement('PRAGMA foreign_keys = ON');
  }
}
