import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'package:snap_split/src/core/database/app_database.dart';

/// T7-2：v1（quantity INTEGER）→ v2（quantity REAL）迁移保数。
///
/// v1 建表语句按 drift v1 生成格式转录（仅 quantity 列不同）；
/// 其余 9 表与 v2 一致，迁移只重建 expense_item。
void main() {
  test('v1 存量迁移后数据保留且可写小数', () async {
    final Directory tmp = await Directory.systemTemp.createTemp('migrate');
    addTearDown(() => tmp.delete(recursive: true));
    final String path = p.join(tmp.path, 'v1.db');

    final dynamic raw = sqlite3.open(path);
    try {
      raw.execute('PRAGMA foreign_keys = OFF');
      raw.execute(
        'CREATE TABLE "user" ("id" TEXT NOT NULL PRIMARY KEY)',
      );
      raw.execute(
        'CREATE TABLE "ledger" ("id" TEXT NOT NULL PRIMARY KEY)',
      );
      raw.execute(
        'CREATE TABLE "shopping_list" ("id" TEXT NOT NULL PRIMARY KEY)',
      );
      raw.execute(
        'CREATE TABLE "expense_item" ("id" TEXT NOT NULL, '
        '"shopping_list_id" TEXT NOT NULL REFERENCES shopping_list (id), '
        '"ledger_id" TEXT NOT NULL REFERENCES ledger (id), '
        '"name" TEXT NOT NULL, '
        '"quantity" INTEGER NOT NULL DEFAULT 1, '
        '"unit_price" INTEGER NOT NULL DEFAULT 0, '
        '"final_amount" INTEGER NOT NULL, '
        '"payer_id" TEXT NOT NULL REFERENCES user (id), '
        '"note" TEXT NULL, '
        '"created_at" INTEGER NOT NULL, '
        '"updated_at" INTEGER NOT NULL, '
        '"deleted_at" INTEGER NULL, '
        'PRIMARY KEY ("id"))',
      );
      raw.execute(
        "INSERT INTO \"user\" (\"id\") VALUES ('u1'), ('u2')",
      );
      raw.execute("INSERT INTO \"ledger\" (\"id\") VALUES ('l1')");
      raw.execute(
        "INSERT INTO \"shopping_list\" (\"id\") VALUES ('sl1')",
      );
      raw.execute(
        'INSERT INTO "expense_item" ("id", "shopping_list_id", '
        '"ledger_id", "name", "quantity", "unit_price", "final_amount", '
        '"payer_id", "created_at", "updated_at") VALUES '
        "('ei-int', 'sl1', 'l1', '牛奶', 2, 1500, 3000, 'u1', 1, 1)",
      );
      raw.execute('PRAGMA user_version = 1');
    } finally {
      raw.dispose();
    }

    final AppDatabase db = AppDatabase.file(File(path));
    addTearDown(db.close);
    // 触发打开即跑迁移。
    final List<ExpenseItem> items = await db.select(db.expenseItems).get();
    expect(items, hasLength(1));
    // 整数存量自动转为 REAL。
    expect(items.single.quantity, 2.0);
    expect(items.single.finalAmount, 3000);

    // 迁移后表定义与全新库逐字一致。
    final QueryRow migrated = await db
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE name = 'expense_item'",
        )
        .getSingle();
    final AppDatabase fresh = AppDatabase.memory();
    addTearDown(fresh.close);
    await fresh.customSelect('SELECT 1').get();
    final QueryRow freshDdl = await fresh
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE name = 'expense_item'",
        )
        .getSingle();
    expect(
      migrated.read<String>('sql'),
      freshDdl.read<String>('sql'),
    );

    // 迁移后可写小数（c921 的 0.32）。
    await db
        .into(db.expenseItems)
        .insert(
          ExpenseItemsCompanion.insert(
            id: 'ei-float',
            shoppingListId: 'sl1',
            ledgerId: 'l1',
            name: '鲜云耳',
            quantity: const Value(0.32),
            unitPrice: const Value(1196),
            finalAmount: 385,
            payerId: 'u1',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    final ExpenseItem weighed =
        await (db.select(db.expenseItems)..where((t) => t.id.equals('ei-float')))
            .getSingle();
    expect(weighed.quantity, closeTo(0.32, 1e-9));
  });
}
