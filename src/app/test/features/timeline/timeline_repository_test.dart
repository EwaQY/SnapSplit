import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/logging/app_logger.dart';

import 'package:snap_split/src/core/database/app_database.dart';
import 'package:snap_split/src/features/ledger/data/ledger_repository.dart';
import 'package:snap_split/src/features/profile/data/user_repository.dart';
import 'package:snap_split/src/features/shopping/data/shopping_repository.dart';
import 'package:snap_split/src/features/timeline/data/timeline_repository.dart';
import 'package:snap_split/src/features/timeline/data/timeline_entries.dart';
import 'package:snap_split/src/features/transfer/data/transfer_repository.dart';

/// T4-3：时间线聚合（降维/展开/转账独立/倒序/软删）。
void main() {
  late AppDatabase db;
  late UserRepository users;
  late LedgerRepository ledgers;
  late ShoppingRepository shopping;
  late TransferRepository transfers;
  late TimelineRepository timeline;

  late User self;
  late User ming;
  late Ledger ledger;

  setUp(() async {
    AppLogger.testMode();
    db = AppDatabase.memory();
    users = UserRepository(db);
    ledgers = LedgerRepository(db);
    shopping = ShoppingRepository(db);
    transfers = TransferRepository(db);
    timeline = TimelineRepository(db, shopping);
    self = await users.ensureSelf();
    ming = await users.createVirtualMember(nickname: '小明');
    ledger = await ledgers.createLedger(
      name: '账本',
      ownerUserId: self.id,
    );
    await ledgers.addMember(ledgerId: ledger.id, userId: ming.id);
  });

  tearDown(() async {
    await db.close();
  });

  test('三态条目与倒序', () async {
    // 单账目（降维）→ 多账目（展开）→ 转账。
    await shopping.createSingleItem(
      ledgerId: ledger.id,
      name: '早餐',
      quantity: 1,
      unitPrice: 1000,
      finalAmount: 1000,
      payerId: self.id,
      participantIds: <String>[self.id],
    );
    await shopping.createShoppingList(
      ledgerId: ledger.id,
      title: '采购',
      items: <NewExpenseItem>[
        (
          name: 'a',
          quantity: 1,
          unitPrice: 100,
          finalAmount: 100,
          payerId: self.id,
          participantIds: <String>[self.id],
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
    await transfers.createTransfer(
      ledgerId: ledger.id,
      fromUserId: ming.id,
      toUserId: self.id,
      amountCents: 500,
    );

    final List<TimelineEntry> entries = await timeline.listTimeline(ledger.id);
    expect(entries, hasLength(3));
    // 同秒创建：转账排首，其次单账目，最后多账目（确定性次序）。
    expect(entries[0], isA<TransferEntry>());
    expect(entries[1], isA<SingleItemEntry>());
    expect(entries[2], isA<ShoppingEntry>());
    final SingleItemEntry single = entries[1] as SingleItemEntry;
    expect(single.detail.item.name, '早餐');
    final ShoppingEntry multi = entries[2] as ShoppingEntry;
    expect(multi.items, hasLength(2));
  });

  test('软删购物单不出现在时间线', () async {
    final ShoppingDetail created = await shopping.createSingleItem(
      ledgerId: ledger.id,
      name: '待删',
      quantity: 1,
      unitPrice: 100,
      finalAmount: 100,
      payerId: self.id,
      participantIds: <String>[self.id],
    );
    expect(await timeline.listTimeline(ledger.id), hasLength(1));
    await shopping.softDeleteShoppingList(created.header.id);
    expect(await timeline.listTimeline(ledger.id), isEmpty);
  });
}
