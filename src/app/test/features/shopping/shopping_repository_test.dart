import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/database/app_database.dart';
import 'package:snap_split/src/core/errors/app_exception.dart';
import 'package:snap_split/src/features/ledger/data/ledger_repository.dart';
import 'package:snap_split/src/features/profile/data/user_repository.dart';
import 'package:snap_split/src/features/shopping/data/shopping_repository.dart';

/// T2-2~T2-5：购物单建/改/删与周期只读。
void main() {
  late AppDatabase db;
  late UserRepository users;
  late LedgerRepository ledgers;
  late ShoppingRepository shopping;

  late User self;
  late User ming;
  late User hong;
  late Ledger ledger;

  setUp(() async {
    db = AppDatabase.memory();
    users = UserRepository(db);
    ledgers = LedgerRepository(db);
    shopping = ShoppingRepository(db);
    self = await users.ensureSelf();
    ming = await users.createVirtualMember(nickname: '小明');
    hong = await users.createVirtualMember(nickname: '小红');
    ledger = await ledgers.createLedger(
      name: '账本',
      ownerUserId: self.id,
    );
    await ledgers.addMember(ledgerId: ledger.id, userId: ming.id);
    await ledgers.addMember(ledgerId: ledger.id, userId: hong.id);
  });

  tearDown(() async {
    await db.close();
  });

  group('T2-2 单账目降维建单', () {
    test('底层购物单 1 + 账目 1 + 均摊分摊', () async {
      final ShoppingDetail detail = await shopping.createSingleItem(
        ledgerId: ledger.id,
        name: '牛奶',
        quantity: 2,
        unitPrice: 1500,
        finalAmount: 3000,
        payerId: self.id,
        participantIds: <String>[self.id, ming.id, hong.id],
      );
      expect(detail.header.title, '牛奶');
      expect(detail.items, hasLength(1));
      final ExpenseDetail line = detail.items.single;
      expect(line.item.finalAmount, 3000);
      expect(
        line.participants.map((ItemParticipant e) => e.shareAmount).toSet(),
        <int>{1000},
      );
      // 默认参与人快照覆盖全单去重参与人。
      expect(
        detail.header.defaultParticipantIds,
        '["${self.id}","${ming.id}","${hong.id}"]',
      );
      expect(detail.header.defaultPayerId, self.id);
    });
  });

  group('T2-3 多账目建单与成员校验', () {
    test('3 账目单行数与标签正确', () async {
      final Tag tag = await db
          .into(db.tags)
          .insertReturning(
            TagsCompanion.insert(
              id: 'tag-1',
              name: '餐饮',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      final ShoppingDetail detail = await shopping.createShoppingList(
        ledgerId: ledger.id,
        title: '超市采购',
        items: <NewExpenseItem>[
          (
            name: '牛奶',
            quantity: 2,
            unitPrice: 1500,
            finalAmount: 3000,
            payerId: self.id,
            participantIds: <String>[self.id, ming.id],
            shares: null,
            note: null,
            tagIds: <String>[tag.id],
          ),
          (
            name: '面包',
            quantity: 1,
            unitPrice: 800,
            finalAmount: 800,
            payerId: ming.id,
            participantIds: <String>[ming.id],
            shares: null,
            note: null,
            tagIds: const <String>[],
          ),
        ],
      );
      expect(detail.items, hasLength(2));
      final ExpenseDetail milk = detail.items.firstWhere(
        (ExpenseDetail e) => e.item.name == '牛奶',
      );
      expect(
        milk.participants.map((ItemParticipant e) => e.shareAmount).toSet(),
        <int>{1500},
      );
      expect(milk.tags.map((Tag e) => e.name), <String>['餐饮']);
      final ExpenseDetail bread = detail.items.firstWhere(
        (ExpenseDetail e) => e.item.name == '面包',
      );
      expect(bread.participants.single.shareAmount, 800);
    });

    test('非成员付款或参与抛错', () async {
      await expectLater(
        shopping.createSingleItem(
          ledgerId: ledger.id,
          name: '坏账',
          quantity: 1,
          unitPrice: 1,
          finalAmount: 1,
          payerId: 'ghost',
          participantIds: <String>[self.id],
        ),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        shopping.createSingleItem(
          ledgerId: ledger.id,
          name: '坏账',
          quantity: 1,
          unitPrice: 1,
          finalAmount: 1,
          payerId: self.id,
          participantIds: const <String>[],
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('T2-4 整单替换编辑与级联软删', () {
    test('编辑替换子账目，旧标签关联硬删', () async {
      final Tag tag = await db
          .into(db.tags)
          .insertReturning(
            TagsCompanion.insert(
              id: 'tag-1',
              name: '餐饮',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      final ShoppingDetail created = await shopping.createSingleItem(
        ledgerId: ledger.id,
        name: '旧商品',
        quantity: 1,
        unitPrice: 100,
        finalAmount: 100,
        payerId: self.id,
        participantIds: <String>[self.id],
        tagIds: <String>[tag.id],
      );
      final ShoppingDetail updated = await shopping.updateShoppingList(
        shoppingId: created.header.id,
        title: '新标题',
        items: <NewExpenseItem>[
          (
            name: '新商品',
            quantity: 1,
            unitPrice: 200,
            finalAmount: 200,
            payerId: ming.id,
            participantIds: <String>[ming.id, hong.id],
            shares: null,
            note: null,
            tagIds: const <String>[],
          ),
        ],
      );
      expect(updated.header.title, '新标题');
      expect(updated.items.single.item.name, '新商品');
      expect(
        updated.items.single.participants
            .map((ItemParticipant e) => e.shareAmount)
            .toSet(),
        <int>{100},
      );
      // 旧账目标签关联已硬删，全库无残留。
      expect(await db.select(db.itemTags).get(), isEmpty);
    });

    test('删整单级联软删，明细不可见', () async {
      final ShoppingDetail created = await shopping.createShoppingList(
        ledgerId: ledger.id,
        title: '待删单',
        items: <NewExpenseItem>[
          (
            name: 'a',
            quantity: 1,
            unitPrice: 100,
            finalAmount: 100,
            payerId: self.id,
            participantIds: <String>[self.id, ming.id],
            shares: null,
            note: null,
            tagIds: const <String>[],
          ),
          (
            name: 'b',
            quantity: 1,
            unitPrice: 200,
            finalAmount: 200,
            payerId: self.id,
            participantIds: <String>[self.id],
            shares: null,
            note: null,
            tagIds: const <String>[],
          ),
        ],
      );
      await shopping.softDeleteShoppingList(created.header.id);
      await expectLater(
        shopping.getDetail(created.header.id),
        throwsA(isA<NotFoundException>()),
      );
      // 子账目与分摊均软删（按 id 查原始行验证标记）。
      final List<ExpenseItem> items = await db.select(db.expenseItems).get();
      expect(items, hasLength(2));
      expect(
        items.every((ExpenseItem e) => e.deletedAt != null),
        isTrue,
      );
      final List<ItemParticipant> parts = await db
          .select(db.itemParticipants)
          .get();
      expect(parts, hasLength(3));
      expect(
        parts.every((ItemParticipant e) => e.deletedAt != null),
        isTrue,
      );
    });
  });

  group('T2-5 周期只读', () {
    test('写/改/删历史周期单抛 ArchivedReadOnlyException', () async {
      final DateTime now = DateTime.now();
      final DateTime lastMonth = DateTime(now.year, now.month - 1, 15);
      final int occurred =
          lastMonth.millisecondsSinceEpoch ~/ 1000;
      await expectLater(
        shopping.createSingleItem(
          ledgerId: ledger.id,
          name: '上月账',
          quantity: 1,
          unitPrice: 100,
          finalAmount: 100,
          payerId: self.id,
          participantIds: <String>[self.id],
          occurredAt: occurred,
        ),
        throwsA(isA<ArchivedReadOnlyException>()),
      );
      // 直接插一条历史单头，改/删同样被拒。
      final String id = 'sl-old';
      await db
          .into(db.shoppingLists)
          .insert(
            ShoppingListsCompanion.insert(
              id: id,
              ledgerId: ledger.id,
              occurredAt: occurred,
              createdAt: occurred,
              updatedAt: occurred,
            ),
          );
      await expectLater(
        shopping.updateShoppingList(shoppingId: id, title: 'x'),
        throwsA(isA<ArchivedReadOnlyException>()),
      );
      await expectLater(
        shopping.softDeleteShoppingList(id),
        throwsA(isA<ArchivedReadOnlyException>()),
      );
    });
  });
}
