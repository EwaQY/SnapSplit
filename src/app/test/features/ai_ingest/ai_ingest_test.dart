import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/logging/app_logger.dart';

import 'package:snap_split/src/core/database/app_database.dart';
import 'package:snap_split/src/core/errors/app_exception.dart';
import 'package:snap_split/src/features/ai_ingest/data/ai_ingest_repository.dart';
import 'package:snap_split/src/features/ai_ingest/domain/ai_ingest_service.dart';
import 'package:snap_split/src/features/ai_ingest/domain/ai_receipt_dto.dart';
import 'package:snap_split/src/features/ledger/data/ledger_repository.dart';
import 'package:snap_split/src/features/profile/data/user_repository.dart';
import 'package:snap_split/src/features/shopping/data/shopping_repository.dart';
import 'package:snap_split/src/features/tags/data/tag_repository.dart';

/// T5-1：AI DTO 解析 → 草稿 → 确认落库（纯解析，不调网络）。
void main() {
  late AppDatabase db;
  late UserRepository users;
  late LedgerRepository ledgers;
  late ShoppingRepository shopping;
  late TagRepository tags;
  late AiIngestRepository ingest;

  setUp(() {
    AppLogger.testMode();
    db = AppDatabase.memory();
    users = UserRepository(db);
    ledgers = LedgerRepository(db);
    shopping = ShoppingRepository(db);
    tags = TagRepository(db);
    ingest = AiIngestRepository(shopping, tags);
  });

  tearDown(() async {
    await db.close();
  });

  Map<String, dynamic> receiptJson() => <String, dynamic>{
    'source_image_index': 0,
    'merchant': '盒马鲜生',
    'date': '2026-09-21',
    'items': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': '牛奶',
        'quantity': 2,
        'unit_price': 15.00,
        'amount': 30.00,
        'tag': '餐饮',
      },
      <String, dynamic>{
        'name': '面包',
        'quantity': 1,
        'unit_price': 24.00,
        'amount': 24.00,
        'tag': '餐饮',
      },
    ],
    'surcharges': <Map<String, dynamic>>[
      <String, dynamic>{'name': '配送费', 'amount': 8.00},
    ],
    'discounts': <Map<String, dynamic>>[
      <String, dynamic>{'name': '满减红包', 'amount': -15.00},
    ],
  };

  test('DTO 解析与草稿金额（含附加费/折扣摊入）', () {
    final AiReceiptDto dto = AiReceiptDto.fromJson(receiptJson());
    expect(dto.items, hasLength(2));
    expect(dto.merchant, '盒马鲜生');
    // 净调整：800 - 1500 = -700 分。
    expect(dto.surchargeCents + dto.discountCents, -700);

    final DraftShopping draft = toDraftShopping(dto);
    expect(draft.items, hasLength(2));
    // 原始 3000/2400，按比例摊 -700：
    // 3000/5400*-700≈-388.9→-389；2400/5400*-700≈-311.1→-311；和 -700。
    expect(
      draft.items.map((DraftItem e) => e.finalAmount),
      <int>[2611, 2089],
    );
    expect(
      draft.items.fold(0, (int sum, DraftItem e) => sum + e.finalAmount),
      4700,
    );
    expect(draft.items.first.tagNames, <String>['餐饮']);
  });

  test('缺字段与空 items 抛 ValidationException', () {
    expect(
      () => AiReceiptDto.fromJson(<String, dynamic>{'items': const []}),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => AiReceiptDto.fromJson(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'x'},
        ],
      }),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => toDraftShopping(
        const AiReceiptDto(sourceImageIndex: 0, items: []),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('确认落库：source=ai，标签复用/新建', () async {
    final User self = await users.ensureSelf();
    final User ming = await users.createVirtualMember(nickname: '小明');
    final Ledger ledger = await ledgers.createLedger(
      name: '账本',
      ownerUserId: self.id,
    );
    await ledgers.addMember(ledgerId: ledger.id, userId: ming.id);
    final Tag existing = await tags.createTag(name: '餐饮');

    final DraftShopping draft = toDraftShopping(
      AiReceiptDto.fromJson(receiptJson()),
    );
    final ShoppingDetail detail = await ingest.confirmDraftShopping(
      ledgerId: ledger.id,
      draft: draft,
      payerId: self.id,
      participantIds: <String>[self.id, ming.id],
    );
    expect(detail.header.source, 'ai');
    expect(detail.header.title, '盒马鲜生');
    expect(detail.items, hasLength(2));
    // 均摊：2611 → 1306/1305（余 1 给垫付人）；2089 → 1045/1044。
    final ExpenseDetail milk = detail.items.firstWhere(
      (ExpenseDetail e) => e.item.name == '牛奶',
    );
    expect(
      milk.participants.map((ItemParticipant e) => e.shareAmount).toSet(),
      <int>{1306, 1305},
    );
    // “餐饮”复用现存 id，未新建。
    expect(
      milk.tags.map((Tag e) => e.id),
      <String>[existing.id],
    );
    expect(await tags.listAllTags(), hasLength(1));
  });
}
