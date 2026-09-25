import 'package:drift/drift.dart';

import 'package:snap_split/src/core/database/app_database.dart';

/// 自插 fixtures：对标 `docs/database/seed.sql` 的确定性测试数据。
///
/// seed.sql 本身不再被执行（仅作行数/真数参考），此处用 companions 重写，
/// 与 drift 强类型绑定，抄错会在编译期或断言中暴露。
///
/// 对标值：user 4 / tag 10 / ledger 2 / ledger_member 7 / shopping_list 3 /
/// expense_item 8 / item_tag 9 / item_participant 26 / transfer 1 / budget 1。
Future<void> insertSeedFixtures(AppDatabase db) async {
  await db.batch((Batch b) {
    // 1. 用户：1 本地账户 + 3 虚拟成员。
    b.insertAll(db.users, <UsersCompanion>[
      UsersCompanion.insert(
        id: 'user-001',
        nickname: '我',
        isSelf: const Value(1),
        createdAt: 1790000000,
        updatedAt: 1790000000,
      ),
      for (final (String id, String name) in <(String, String)>[
        ('user-002', '小明'),
        ('user-003', '小红'),
        ('user-004', '小李'),
      ])
        UsersCompanion.insert(
          id: id,
          nickname: name,
          createdAt: 1790000000,
          updatedAt: 1790000000,
        ),
    ]);

    // 2. 全局共享标签 10 个。
    const List<(String, String, String)> tags = <(String, String, String)>[
      ('tag-001', '餐饮', '🍽️'),
      ('tag-002', '交通', '🚗'),
      ('tag-003', '购物', '🛒'),
      ('tag-004', '娱乐', '🎮'),
      ('tag-005', '居住', '🏠'),
      ('tag-006', '医疗', '💊'),
      ('tag-007', '教育', '📚'),
      ('tag-008', '通讯', '📱'),
      ('tag-009', '服饰', '👕'),
      ('tag-010', '其他', '📦'),
    ];
    b.insertAll(
      db.tags,
      <TagsCompanion>[
        for (final tag in tags)
          TagsCompanion.insert(
            id: tag.$1,
            name: tag.$2,
            icon: Value(tag.$3),
            createdAt: 1790000000,
            updatedAt: 1790000000,
          ),
      ],
    );

    // 3. 账本 2 个。
    b.insertAll(db.ledgers, <LedgersCompanion>[
      LedgersCompanion.insert(
        id: 'ledger-001',
        name: '室友合租',
        ownerUserId: 'user-001',
        createdAt: 1790000000,
        updatedAt: 1790000000,
      ),
      LedgersCompanion.insert(
        id: 'ledger-002',
        name: '朋友聚餐',
        ownerUserId: 'user-001',
        createdAt: 1790000000,
        updatedAt: 1790000000,
      ),
    ]);

    // 4. 账本成员 7 条。
    const List<(String, String, String)> members = <(String, String, String)>[
      ('lm-001', 'ledger-001', 'user-001'),
      ('lm-002', 'ledger-001', 'user-002'),
      ('lm-003', 'ledger-001', 'user-003'),
      ('lm-004', 'ledger-002', 'user-001'),
      ('lm-005', 'ledger-002', 'user-002'),
      ('lm-006', 'ledger-002', 'user-003'),
      ('lm-007', 'ledger-002', 'user-004'),
    ];
    b.insertAll(
      db.ledgerMembers,
      <LedgerMembersCompanion>[
        for (final member in members)
          LedgerMembersCompanion.insert(
            id: member.$1,
            ledgerId: member.$2,
            userId: member.$3,
            joinedAt: 1790000000,
            createdAt: 1790000000,
            updatedAt: 1790000000,
          ),
      ],
    );

    // 5. 购物单 3 个（含 sl-002 的默认参与人子集快照）。
    b.insertAll(db.shoppingLists, <ShoppingListsCompanion>[
      ShoppingListsCompanion.insert(
        id: 'sl-001',
        ledgerId: 'ledger-001',
        title: const Value('超市采购'),
        merchant: const Value('盒马鲜生'),
        occurredAt: 1789900000,
        defaultPayerId: const Value('user-001'),
        defaultParticipantIds: const Value(
          '["user-001","user-002","user-003"]',
        ),
        note: const Value('周末采购日用品'),
        source: const Value('manual'),
        createdAt: 1790000000,
        updatedAt: 1790000000,
      ),
      ShoppingListsCompanion.insert(
        id: 'sl-002',
        ledgerId: 'ledger-001',
        title: const Value('午餐外卖'),
        merchant: const Value('美团外卖'),
        occurredAt: 1789800000,
        defaultPayerId: const Value('user-002'),
        defaultParticipantIds: const Value('["user-002"]'),
        source: const Value('ai'),
        createdAt: 1790000000,
        updatedAt: 1790000000,
      ),
      ShoppingListsCompanion.insert(
        id: 'sl-003',
        ledgerId: 'ledger-002',
        title: const Value('周五聚餐'),
        merchant: const Value('海底捞'),
        occurredAt: 1789700000,
        defaultPayerId: const Value('user-001'),
        defaultParticipantIds: const Value(
          '["user-001","user-002","user-003","user-004"]',
        ),
        note: const Value('四人聚餐'),
        source: const Value('manual'),
        createdAt: 1790000000,
        updatedAt: 1790000000,
      ),
    ]);

    // 6. 账目 8 条。
    const List<(String, String, String, String, int, int, int, String)>
    items = <(String, String, String, String, int, int, int, String)>[
      // (id, shoppingListId, ledgerId, name, qty, unitPrice, final, payer)
      ('ei-001', 'sl-001', 'ledger-001', '牛奶', 2, 1500, 3000, 'user-001'),
      ('ei-002', 'sl-001', 'ledger-001', '面包', 3, 800, 2400, 'user-001'),
      ('ei-003', 'sl-001', 'ledger-001', '洗发水', 1, 4500, 4500, 'user-001'),
      ('ei-004', 'sl-002', 'ledger-001', '黄焖鸡米饭', 1, 2500, 2500, 'user-002'),
      ('ei-005', 'sl-003', 'ledger-002', '锅底', 1, 8000, 8000, 'user-001'),
      ('ei-006', 'sl-003', 'ledger-002', '肥牛卷', 2, 6000, 12000, 'user-001'),
      ('ei-007', 'sl-003', 'ledger-002', '蔬菜拼盘', 1, 3500, 3500, 'user-001'),
      ('ei-008', 'sl-003', 'ledger-002', '饮料', 4, 800, 3200, 'user-001'),
    ];
    b.insertAll(
      db.expenseItems,
      <ExpenseItemsCompanion>[
        for (final item in items)
          ExpenseItemsCompanion.insert(
            id: item.$1,
            shoppingListId: item.$2,
            ledgerId: item.$3,
            name: item.$4,
            quantity: Value(item.$5),
            unitPrice: Value(item.$6),
            finalAmount: item.$7,
            payerId: item.$8,
            createdAt: 1790000000,
            updatedAt: 1790000000,
          ),
      ],
    );

    // 7. 账目-标签关联 9 条（含洗发水多标签）。
    const List<(String, String, String)> itemTags = <(String, String, String)>[
      ('it-001', 'ei-001', 'tag-001'),
      ('it-002', 'ei-002', 'tag-001'),
      ('it-003', 'ei-003', 'tag-010'),
      ('it-004', 'ei-003', 'tag-003'),
      ('it-005', 'ei-004', 'tag-001'),
      ('it-006', 'ei-005', 'tag-001'),
      ('it-007', 'ei-006', 'tag-001'),
      ('it-008', 'ei-007', 'tag-001'),
      ('it-009', 'ei-008', 'tag-001'),
    ];
    b.insertAll(
      db.itemTags,
      <ItemTagsCompanion>[
        for (final itemTag in itemTags)
          ItemTagsCompanion.insert(
            id: itemTag.$1,
            expenseItemId: itemTag.$2,
            tagId: itemTag.$3,
            createdAt: 1790000000,
          ),
      ],
    );

    // 8. 账目参与人 26 条。
    final List<(String, String, int)> participants =
        <(String, String, int)>[
          for (final (String itemId, int share, List<String> users) in <
            (String, int, List<String>)
          >[
            ('ei-001', 1000, <String>['user-001', 'user-002', 'user-003']),
            ('ei-002', 800, <String>['user-001', 'user-002', 'user-003']),
            ('ei-003', 1500, <String>['user-001', 'user-002', 'user-003']),
            ('ei-004', 2500, <String>['user-002']),
            ('ei-005', 2000, <String>[
              'user-001',
              'user-002',
              'user-003',
              'user-004',
            ]),
            ('ei-006', 3000, <String>[
              'user-001',
              'user-002',
              'user-003',
              'user-004',
            ]),
            ('ei-007', 875, <String>[
              'user-001',
              'user-002',
              'user-003',
              'user-004',
            ]),
            ('ei-008', 800, <String>[
              'user-001',
              'user-002',
              'user-003',
              'user-004',
            ]),
          ])
            for (final user in users) (itemId, user, share),
        ];
    int seq = 0;
    b.insertAll(
      db.itemParticipants,
      <ItemParticipantsCompanion>[
        for (final participant in participants)
          ItemParticipantsCompanion.insert(
            id: 'ip-${(++seq).toString().padLeft(3, '0')}',
            expenseItemId: participant.$1,
            userId: participant.$2,
            shareAmount: participant.$3,
            createdAt: 1790000000,
            updatedAt: 1790000000,
          ),
      ],
    );

    // 9. 转账 1 条。
    b.insert(
      db.transfers,
      TransfersCompanion.insert(
        id: 'tr-001',
        ledgerId: 'ledger-001',
        fromUserId: 'user-002',
        toUserId: 'user-001',
        amount: 1500,
        occurredAt: 1789600000,
        note: const Value('还上次垫付的饭钱'),
        createdAt: 1790000000,
        updatedAt: 1790000000,
      ),
    );

    // 10. 预算 1 条（2026-09，5000 元）。
    b.insert(
      db.budgets,
      BudgetsCompanion.insert(
        id: 'budget-001',
        userId: 'user-001',
        amount: 500000,
        year: 2026,
        month: 9,
        createdAt: 1790000000,
        updatedAt: 1790000000,
      ),
    );
  });
}
