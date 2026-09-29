import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  group('T0-2 companions 增删改查与默认值', () {
    test('用户增改软删往返', () async {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: 'u-1',
              nickname: '我',
              createdAt: 1700000000,
              updatedAt: 1700000000,
            ),
          );
      final User user = await (db.select(
        db.users,
      )..where((t) => t.id.equals('u-1'))).getSingle();
      // is_self 未显式赋值，走列默认值 0。
      expect(user.isSelf, 0);
      expect(user.deletedAt, isNull);

      await (db.update(
        db.users,
      )..where((t) => t.id.equals('u-1'))).write(
        const UsersCompanion(nickname: Value('我改名了')),
      );
      final User renamed = await (db.select(
        db.users,
      )..where((t) => t.id.equals('u-1'))).getSingle();
      expect(renamed.nickname, '我改名了');

      await (db.update(
        db.users,
      )..where((t) => t.id.equals('u-1'))).write(
        const UsersCompanion(deletedAt: Value(1700000001)),
      );
      final List<User> alive = await (db.select(
        db.users,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(alive, isEmpty);
      final User tombstone = await (db.select(
        db.users,
      )..where((t) => t.id.equals('u-1'))).getSingle();
      expect(tombstone.deletedAt, 1700000001);
    });

    test('账目默认值生效（quantity/unit_price/source）', () async {
      await db.into(db.users).insert(
        UsersCompanion.insert(
          id: 'u-1',
          nickname: '我',
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      await db.into(db.ledgers).insert(
        LedgersCompanion.insert(
          id: 'l-1',
          name: '账本',
          ownerUserId: 'u-1',
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      await db.into(db.shoppingLists).insert(
        ShoppingListsCompanion.insert(
          id: 'sl-1',
          ledgerId: 'l-1',
          occurredAt: 1,
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      final ShoppingList list = await (db.select(
        db.shoppingLists,
      )..where((t) => t.id.equals('sl-1'))).getSingle();
      expect(list.source, 'manual');

      await db.into(db.expenseItems).insert(
        ExpenseItemsCompanion.insert(
          id: 'ei-1',
          shoppingListId: 'sl-1',
          ledgerId: 'l-1',
          name: '商品',
          finalAmount: 100,
          payerId: 'u-1',
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      final ExpenseItem item = await (db.select(
        db.expenseItems,
      )..where((t) => t.id.equals('ei-1'))).getSingle();
      expect(item.quantity, 1);
      expect(item.unitPrice, 0);
    });

    test('item_tag 无软删字段，硬删', () async {
      await db.into(db.users).insert(
        UsersCompanion.insert(
          id: 'u-1',
          nickname: '我',
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      await db.into(db.tags).insert(
        TagsCompanion.insert(id: 't-1', name: '餐饮', createdAt: 1, updatedAt: 1),
      );
      await db.into(db.ledgers).insert(
        LedgersCompanion.insert(
          id: 'l-1',
          name: '账本',
          ownerUserId: 'u-1',
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      await db.into(db.shoppingLists).insert(
        ShoppingListsCompanion.insert(
          id: 'sl-1',
          ledgerId: 'l-1',
          occurredAt: 1,
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      await db.into(db.expenseItems).insert(
        ExpenseItemsCompanion.insert(
          id: 'ei-1',
          shoppingListId: 'sl-1',
          ledgerId: 'l-1',
          name: '商品',
          finalAmount: 100,
          payerId: 'u-1',
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      await db.into(db.itemTags).insert(
        ItemTagsCompanion.insert(
          id: 'it-1',
          expenseItemId: 'ei-1',
          tagId: 't-1',
          createdAt: 1,
        ),
      );
      expect(await db.select(db.itemTags).get(), hasLength(1));
      await (db.delete(
        db.itemTags,
      )..where((t) => t.id.equals('it-1'))).go();
      expect(await db.select(db.itemTags).get(), isEmpty);
    });
  });

  group('T0-3 外键与事务', () {
    test('非法付款人违反外键抛错', () async {
      await db.into(db.users).insert(
        UsersCompanion.insert(
          id: 'u-1',
          nickname: '我',
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      await db.into(db.ledgers).insert(
        LedgersCompanion.insert(
          id: 'l-1',
          name: '账本',
          ownerUserId: 'u-1',
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      await db.into(db.shoppingLists).insert(
        ShoppingListsCompanion.insert(
          id: 'sl-1',
          ledgerId: 'l-1',
          occurredAt: 1,
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      await expectLater(
        db.into(db.expenseItems).insert(
          ExpenseItemsCompanion.insert(
            id: 'ei-bad',
            shoppingListId: 'sl-1',
            ledgerId: 'l-1',
            name: '坏账',
            finalAmount: 1,
            payerId: 'ghost',
            createdAt: 1,
            updatedAt: 1,
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('事务内抛错整体回滚', () async {
      await expectLater(
        db.transaction(() async {
          await db.into(db.users).insert(
            UsersCompanion.insert(
              id: 'tx-u',
              nickname: '回滚我',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
          throw StateError('boom');
        }),
        throwsStateError,
      );
      final List<User> rows = await (db.select(
        db.users,
      )..where((t) => t.id.equals('tx-u'))).get();
      expect(rows, isEmpty);
    });
  });
}
