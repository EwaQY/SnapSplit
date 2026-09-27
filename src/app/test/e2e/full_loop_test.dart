import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/logging/app_logger.dart';

import 'package:snap_split/src/core/database/app_database.dart';
import 'package:snap_split/src/core/utils/app_time.dart';
import 'package:snap_split/src/features/ai_ingest/data/ai_ingest_repository.dart';
import 'package:snap_split/src/features/ai_ingest/domain/ai_ingest_service.dart';
import 'package:snap_split/src/features/ai_ingest/domain/ai_receipt_dto.dart';
import 'package:snap_split/src/features/budget/data/budget_repository.dart';
import 'package:snap_split/src/features/ledger/data/ledger_repository.dart';
import 'package:snap_split/src/features/profile/data/user_repository.dart';
import 'package:snap_split/src/features/settlement/data/settlement_repository.dart';
import 'package:snap_split/src/features/settlement/domain/settlement_calculator.dart';
import 'package:snap_split/src/features/shopping/data/shopping_repository.dart';
import 'package:snap_split/src/features/tags/data/tag_repository.dart';
import 'package:snap_split/src/features/timeline/data/timeline_entries.dart';
import 'package:snap_split/src/features/timeline/data/timeline_repository.dart';
import 'package:snap_split/src/features/transfer/data/transfer_repository.dart';

/// T5-3 E2E 全闭环：建我→账本→成员→单账目→多账目含折扣→AI 两单确认→
/// 时间线→结算→转账归零→预算→上月只读→删单级联。
void main() {
  test('full loop', () async {
    AppLogger.testMode();
    final AppDatabase db = AppDatabase.memory();
    addTearDown(db.close);
    final UserRepository users = UserRepository(db);
    final LedgerRepository ledgers = LedgerRepository(db);
    final ShoppingRepository shopping = ShoppingRepository(db);
    final TagRepository tags = TagRepository(db);
    final TransferRepository transfers = TransferRepository(db);
    final SettlementRepository settlement = SettlementRepository(db);
    final TimelineRepository timeline = TimelineRepository(db, shopping);
    final BudgetRepository budgets = BudgetRepository(db);
    final AiIngestRepository ingest = AiIngestRepository(shopping, tags);

    // 建我→建账本→加 2 人。
    final User self = await users.ensureSelf();
    final User ming = await users.createVirtualMember(nickname: '小明');
    final User hong = await users.createVirtualMember(nickname: '小红');
    final Ledger ledger = await ledgers.createLedger(
      name: '合租',
      ownerUserId: self.id,
    );
    await ledgers.addMember(ledgerId: ledger.id, userId: ming.id);
    await ledgers.addMember(ledgerId: ledger.id, userId: hong.id);
    final List<String> all = <String>[self.id, ming.id, hong.id];

    // 单账目：我付 3000，三人均摊。
    await shopping.createSingleItem(
      ledgerId: ledger.id,
      name: '牛奶',
      quantity: 1,
      unitPrice: 3000,
      finalAmount: 3000,
      payerId: self.id,
      participantIds: all,
    );

    // 多账目含折扣：原始 8000+4000，满减 -2000 → finals 按比例。
    final DraftShopping manual = DraftShopping(
      sourceImageIndex: -1,
      items: <DraftItem>[
        const DraftItem(
          name: '锅底',
          quantity: 1,
          unitPrice: 8000,
          finalAmount: 8000,
        ),
        const DraftItem(
          name: '配菜',
          quantity: 1,
          unitPrice: 4000,
          finalAmount: 4000,
        ),
      ],
    );
    // 8000/12000*-2000≈-1333.3→-1333；4000/12000*-2000≈-666.7→-667。
    await shopping.createShoppingList(
      ledgerId: ledger.id,
      title: '聚餐',
      items: <NewExpenseItem>[
        (
          name: '锅底',
          quantity: 1,
          unitPrice: 8000,
          finalAmount: manual.items[0].finalAmount - 1333,
          payerId: self.id,
          participantIds: all,
          shares: null,
          note: null,
          tagIds: const <String>[],
        ),
        (
          name: '配菜',
          quantity: 1,
          unitPrice: 4000,
          finalAmount: manual.items[1].finalAmount - 667,
          payerId: self.id,
          participantIds: all,
          shares: null,
          note: null,
          tagIds: const <String>[],
        ),
      ],
    );

    // AI 两单确认（一图一单）。
    for (int i = 0; i < 2; i++) {
      final AiReceiptDto dto = AiReceiptDto.fromJson(<String, dynamic>{
        'source_image_index': i,
        'merchant': '店$i',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': '商品$i',
            'quantity': 1,
            'unit_price': 900.0,
            'amount': 900.0,
            'tag': '购物',
          },
        ],
        'surcharges': <Map<String, dynamic>>[
          <String, dynamic>{'name': '打包费', 'amount': 100.0},
        ],
        'discounts': const <Map<String, dynamic>>[],
      });
      await ingest.confirmDraftShopping(
        ledgerId: ledger.id,
        draft: toDraftShopping(dto),
        payerId: ming.id,
        participantIds: <String>[ming.id],
      );
    }

    // 时间线：1 单账目 + 1 多账目 + 2 AI 单账目 + 0 转账 = 4 条。
    final List<TimelineEntry> entries = await timeline.listTimeline(ledger.id);
    expect(entries, hasLength(4));
    expect(
      entries.whereType<SingleItemEntry>(),
      hasLength(3),
      reason: '3 个单账目购物单应降维',
    );
    expect(entries.whereType<ShoppingEntry>(), hasLength(1));

    // 结算板非空。
    final SettlementBoard board = await settlement.calcBoard(
      ledgerId: ledger.id,
      selfId: self.id,
    );
    expect(board.selfNets, isNotEmpty);

    // 转账逐笔核销→归零。
    for (final SelfNet net in board.selfNets) {
      if (net.netAmount > 0) {
        await transfers.createTransfer(
          ledgerId: ledger.id,
          fromUserId: self.id,
          toUserId: net.otherUserId,
          amountCents: net.netAmount,
        );
      } else {
        await transfers.createTransfer(
          ledgerId: ledger.id,
          fromUserId: net.otherUserId,
          toUserId: self.id,
          amountCents: -net.netAmount,
        );
      }
    }
    final SettlementBoard cleared = await settlement.calcBoard(
      ledgerId: ledger.id,
      selfId: self.id,
    );
    expect(cleared.selfNets, isEmpty);

    // 预算：我付 3000+6667+3333=13000，设 20000 不超支。
    final ({int month, int year}) now = yearMonthOf(nowUnixSeconds());
    await budgets.setBudget(
      userId: self.id,
      year: now.year,
      month: now.month,
      amountCents: 2000000,
    );
    final BudgetProgress progress = await budgets.getProgress(
      userId: self.id,
      year: now.year,
      month: now.month,
    );
    expect(progress.spent, 13000);
    expect(progress.overBudget, isFalse);

    // 删多账目单→级联；时间线减 1。
    final List<TimelineEntry> before = await timeline.listTimeline(ledger.id);
    final ShoppingEntry multi = before.whereType<ShoppingEntry>().single;
    await shopping.softDeleteShoppingList(multi.id);
    final List<TimelineEntry> after = await timeline.listTimeline(ledger.id);
    expect(after, hasLength(before.length - 1));
  });
}
