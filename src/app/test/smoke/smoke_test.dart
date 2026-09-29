import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/database/app_database.dart';
import 'package:snap_split/src/core/errors/app_exception.dart';
import 'package:snap_split/src/core/logging/app_logger.dart';
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

/// 冒烟（计划 §3）：双库可建连 + 全表 CRUD 走通 + 时间线/结算最小链路。
///
/// 文件库落系统临时目录（每次全新），内存库验证第二路可建连。
void main() {
  test('smoke 全链路', () async {
    AppLogger.testMode();
    final Directory dir = await Directory.systemTemp.createTemp('smoke');
    addTearDown(() => dir.delete(recursive: true));

    // 双库建连：文件库 + 内存库。
    final AppDatabase dev = AppDatabase.file(File('${dir.path}/smoke.db'));
    addTearDown(dev.close);
    final AppDatabase mem = AppDatabase.memory();
    await mem.close();

    final UserRepository users = UserRepository(dev);
    final LedgerRepository ledgers = LedgerRepository(dev);
    final ShoppingRepository shopping = ShoppingRepository(dev);
    final TagRepository tags = TagRepository(dev);
    final TransferRepository transfers = TransferRepository(dev);
    final SettlementRepository settlement = SettlementRepository(dev);
    final TimelineRepository timeline = TimelineRepository(dev, shopping);
    final BudgetRepository budgets = BudgetRepository(dev);
    final AiIngestRepository ingest = AiIngestRepository(shopping);

    // 首次启动建我 + 改资料 + 虚拟成员。
    final User self = await users.ensureSelf();
    await users.updateProfile(self.id, nickname: '我');
    final User ming = await users.createVirtualMember(nickname: '小明');
    final User hong = await users.createVirtualMember(nickname: '小红');

    // 建账本进成员。
    final Ledger ledger = await ledgers.createLedger(
      name: '冒烟账本',
      ownerUserId: self.id,
    );
    await ledgers.addMember(ledgerId: ledger.id, userId: ming.id);
    await ledgers.addMember(ledgerId: ledger.id, userId: hong.id);
    expect(await ledgers.listMembers(ledger.id), hasLength(3));

    // 标签建/改。
    final Tag food = await tags.createTag(name: '餐饮');
    await tags.renameTag(food.id, name: '美食');
    expect(await tags.listActiveTags(), isNotEmpty);

    // 单账目 + 多账目建单。
    final List<String> all = <String>[self.id, ming.id, hong.id];
    await shopping.createSingleItem(
      ledgerId: ledger.id,
      name: '牛奶',
      quantity: 1,
      unitPrice: 3000,
      finalAmount: 3000,
      payerId: self.id,
      participantIds: all,
      tagIds: <String>[food.id],
    );
    final ShoppingDetail lunch = await shopping.createShoppingList(
      ledgerId: ledger.id,
      title: '午餐',
      items: <NewExpenseItem>[
        (
          name: '盖饭',
          quantity: 1,
          unitPrice: 2000,
          finalAmount: 2000,
          payerId: self.id,
          participantIds: <String>[self.id, ming.id],
          shares: null,
          note: null,
          tagIds: const <String>[],
        ),
        (
          name: '饮料',
          quantity: 1,
          unitPrice: 1000,
          finalAmount: 1000,
          payerId: self.id,
          participantIds: all,
          shares: null,
          note: null,
          tagIds: const <String>[],
        ),
      ],
    );
    expect(
      (await shopping.getDetail(lunch.header.id)).items,
      hasLength(2),
    );

    // 单件增改删。
    final ShoppingDetail added = await shopping.addItemToShopping(
      shoppingId: lunch.header.id,
      item: (
        name: '纸巾',
        quantity: 1,
        unitPrice: 300,
        finalAmount: 300,
        payerId: self.id,
        participantIds: <String>[self.id],
        shares: null,
        note: null,
        tagIds: const <String>[],
      ),
    );
    final String towelId = added.items
        .firstWhere((ExpenseDetail e) => e.item.name == '纸巾')
        .item
        .id;
    await shopping.updateExpenseItem(itemId: towelId, finalAmount: 400);
    final ShoppingDetail afterRemove = await shopping.removeExpenseItem(
      towelId,
    );
    expect(afterRemove.items, hasLength(2));

    // AI 离线确认（一图一单，不调网络）。
    const AiReceiptDto dto = AiReceiptDto(
      sourceImageIndex: 0,
      merchant: '小店',
      items: <AiReceiptItem>[
        AiReceiptItem(name: '面包', quantity: 1, unitPrice: 10, amount: 10),
      ],
    );
    final DraftShopping draft = toDraftShopping(dto);
    final ShoppingDetail ai = await ingest.confirmDraftShopping(
      ledgerId: ledger.id,
      draft: draft,
      items: <ConfirmedItem>[
        (
          name: draft.items.single.name,
          quantity: draft.items.single.quantity,
          unitPrice: draft.items.single.unitPrice,
          finalAmount: draft.items.single.finalAmount,
          payerId: self.id,
          participantIds: <String>[self.id, ming.id],
          shares: null,
          note: null,
          tagIds: <String>[food.id],
        ),
      ],
    );
    expect(ai.header.source, 'ai');

    // 时间线最小链路：1 单账目 + 1 多账目 + 1 AI 单账目 + 0 转账 = 3 条。
    final List<TimelineEntry> entries = await timeline.listTimeline(ledger.id);
    expect(entries, hasLength(3));

    // 结算 + 转账归零。
    final SettlementBoard board = await settlement.calcBoard(
      ledgerId: ledger.id,
      selfId: self.id,
    );
    expect(board.selfNets, isNotEmpty);
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

    // 预算进度。
    final ({int month, int year}) now = yearMonthOf(nowUnixSeconds());
    await budgets.setBudget(
      userId: self.id,
      year: now.year,
      month: now.month,
      amountCents: 1000000,
    );
    final BudgetProgress progress = await budgets.getProgress(
      userId: self.id,
      year: now.year,
      month: now.month,
    );
    expect(progress.spent, greaterThan(0));
    expect(progress.overBudget, isFalse);

    // 有账本拒删 + 归档标签拒写。
    await expectLater(
      ledgers.softDeleteLedger(ledger.id),
      throwsA(isA<ValidationException>()),
    );
    await tags.archiveTag(food.id);
    await expectLater(
      shopping.createSingleItem(
        ledgerId: ledger.id,
        name: '坏账',
        quantity: 1,
        unitPrice: 1,
        finalAmount: 1,
        payerId: self.id,
        participantIds: <String>[self.id],
        tagIds: <String>[food.id],
      ),
      throwsA(isA<ValidationException>()),
    );
  });
}
