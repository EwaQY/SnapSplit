import 'package:flutter_test/flutter_test.dart';
import 'package:snap_split/src/core/database/app_database.dart';
import 'package:snap_split/src/features/home/providers/home_filter.dart';
import 'package:snap_split/src/features/timeline/data/timeline_entries.dart';

/// 筛选匹配单测：纯内存谓词，锁定账本/标签/人/金额/日期/关键字语义。
void main() {
  const int base = 1758000000;

  ShoppingList header({String ledgerId = 'l1', String? title}) =>
      ShoppingList(
        id: 's1',
        ledgerId: ledgerId,
        title: title,
        merchant: null,
        occurredAt: base,
        defaultPayerId: null,
        defaultParticipantIds: null,
        note: null,
        source: 'manual',
        createdAt: base,
        updatedAt: base,
      );

  ExpenseItem item({
    String name = '山姆采购',
    int finalAmount = 19360,
    String payerId = 'u1',
  }) => ExpenseItem(
    id: 'i1',
    shoppingListId: 's1',
    ledgerId: 'l1',
    name: name,
    quantity: 1,
    unitPrice: finalAmount,
    finalAmount: finalAmount,
    payerId: payerId,
    createdAt: base,
    updatedAt: base,
  );

  ItemParticipant participant(String userId) => ItemParticipant(
    id: 'p-$userId',
    expenseItemId: 'i1',
    userId: userId,
    shareAmount: 9680,
    createdAt: base,
    updatedAt: base,
  );

  Tag tag(String id) => Tag(
    id: id,
    name: id,
    createdAt: base,
    updatedAt: base,
  );

  SingleItemEntry single({
    String ledgerId = 'l1',
    String name = '山姆采购',
    int finalAmount = 19360,
    String payerId = 'u1',
    List<String> participantIds = const <String>['u1', 'u2'],
    List<String> tagIds = const <String>['t1'],
    String? title,
  }) => SingleItemEntry(
    header(ledgerId: ledgerId, title: title),
    (
      item: item(name: name, finalAmount: finalAmount, payerId: payerId),
      participants: <ItemParticipant>[
        for (final String id in participantIds) participant(id),
      ],
      tags: <Tag>[for (final String id in tagIds) tag(id)],
    ),
  );

  TransferEntry transfer() => TransferEntry(
    Transfer(
      id: 'tr1',
      ledgerId: 'l1',
      fromUserId: 'u1',
      toUserId: 'u2',
      amount: 5000,
      occurredAt: base,
      createdAt: base,
      updatedAt: base,
    ),
  );

  bool matches(TimelineEntry entry, HomeFilter filter) =>
      matchesHomeFilter(
        entry,
        filter,
        windowStartSeconds: base - 7 * 24 * 3600,
      );

  group('空条件', () {
    test('全空不过滤，账目与转账均命中', () {
      expect(matches(single(), const HomeFilter()), isTrue);
      expect(matches(transfer(), const HomeFilter()), isTrue);
    });
  });

  group('账本与窗口', () {
    test('账本不同则过滤', () {
      expect(
        matches(single(), const HomeFilter(ledgerId: 'l2')),
        isFalse,
      );
    });

    test('窗口外发生时间被过滤', () {
      expect(
        matchesHomeFilter(
          single(),
          const HomeFilter(),
          windowStartSeconds: base + 1,
        ),
        isFalse,
      );
    });
  });

  group('金额与关键字', () {
    test('金额区间含端点', () {
      expect(
        matches(
          single(),
          const HomeFilter(minAmountCents: 19360, maxAmountCents: 19360),
        ),
        isTrue,
      );
      expect(
        matches(single(), const HomeFilter(minAmountCents: 19361)),
        isFalse,
      );
    });

    test('关键字命中账目名', () {
      expect(
        matches(single(), const HomeFilter(keyword: '山姆')),
        isTrue,
      );
      expect(
        matches(single(), const HomeFilter(keyword: '火锅')),
        isFalse,
      );
    });
  });

  group('标签与人', () {
    test('标签命中任一即过，不过滤无交集', () {
      expect(
        matches(single(), const HomeFilter(tagIds: {'t2', 't1'})),
        isTrue,
      );
      expect(
        matches(single(), const HomeFilter(tagIds: {'t9'})),
        isFalse,
      );
    });

    test('付款人必须相等', () {
      expect(
        matches(single(), const HomeFilter(payerId: 'u1')),
        isTrue,
      );
      expect(
        matches(single(), const HomeFilter(payerId: 'u2')),
        isFalse,
      );
    });

    test('参与人命中任一即过', () {
      expect(
        matches(single(), const HomeFilter(participantIds: {'u2'})),
        isTrue,
      );
      expect(
        matches(single(), const HomeFilter(participantIds: {'u9'})),
        isFalse,
      );
    });

    test('转账无标签与人维度，设条件即不同转账', () {
      expect(
        matches(transfer(), const HomeFilter(tagIds: {'t1'})),
        isFalse,
      );
      expect(
        matches(transfer(), const HomeFilter(payerId: 'u1')),
        isFalse,
      );
      expect(
        matches(
          transfer(),
          const HomeFilter(participantIds: {'u1'}),
        ),
        isFalse,
      );
    });
  });
}
