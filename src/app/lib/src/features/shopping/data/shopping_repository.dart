import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/utils/app_time.dart';
import '../../../core/utils/ids.dart';
import '../domain/split_calculator.dart';

/// 新建账目入参：`shares` 为空时按参与人均摊。
typedef NewExpenseItem = ({
  String name,
  double quantity,
  int unitPrice,
  int finalAmount,
  String payerId,
  List<String> participantIds,
  Map<String, int>? shares,
  String? note,
  List<String> tagIds,
});

/// 账目明细：账目 + 分摊 + 标签。
typedef ExpenseDetail = ({
  ExpenseItem item,
  List<ItemParticipant> participants,
  List<Tag> tags,
});

/// 购物单明细：单头 + 全部子账目。
typedef ShoppingDetail = ({ShoppingList header, List<ExpenseDetail> items});

/// 购物单 Repository：购物单/账目/分摊/账目标签的唯一数据源。
///
/// - 单账目创建底层仍建购物单（标题取账目名，UI 降维展示）。
/// - 编辑按整单替换子账目集合（与统一录入/编辑页语义一致）。
/// - 删除级联：同事务软删单头 + 子账目 + 分摊，硬删账目-标签关联。
/// - 付款人/参与人须为账本活跃成员；仅当前周期可写。
class ShoppingRepository {
  ShoppingRepository(this._db);

  final AppDatabase _db;

  /// 建单账目（UI 降维为账目）。
  Future<ShoppingDetail> createSingleItem({
    required String ledgerId,
    required String name,
    required double quantity,
    required int unitPrice,
    required int finalAmount,
    required String payerId,
    required List<String> participantIds,
    String? note,
    List<String> tagIds = const <String>[],
    int? occurredAt,
  }) => createShoppingList(
    ledgerId: ledgerId,
    title: name,
    occurredAt: occurredAt ?? nowUnixSeconds(),
    items: <NewExpenseItem>[
      (
        name: name,
        quantity: quantity,
        unitPrice: unitPrice,
        finalAmount: finalAmount,
        payerId: payerId,
        participantIds: participantIds,
        shares: null,
        note: note,
        tagIds: tagIds,
      ),
    ],
  );

  /// 建多账目购物单。
  Future<ShoppingDetail> createShoppingList({
    required String ledgerId,
    String? title,
    String? merchant,
    String? note,
    String source = 'manual',
    int? occurredAt,
    required List<NewExpenseItem> items,
  }) => AppLogger.audit(
    action: 'shopping.createShoppingList',
    entity: 'shopping_list',
    run: () async {
      if (items.isEmpty) {
        throw ValidationException('购物单至少包含一个账目');
      }
    final int occurred = occurredAt ?? nowUnixSeconds();
    _requireCurrentPeriod(occurred);
    // 防直调去重：参与人/tagIds 统一去重后再校验落库。
    final List<NewExpenseItem> deduped = <NewExpenseItem>[
      for (final NewExpenseItem item in items) _dedupItem(item),
    ];
    for (final NewExpenseItem item in deduped) {
      if (item.participantIds.isEmpty) {
        throw ValidationException('账目参与人不能为空：${item.name}');
      }
      await _requireMembers(ledgerId, <String>{
        item.payerId,
        ...item.participantIds,
      });
      await _requireActiveTags(item.tagIds);
    }
    final int now = nowUnixSeconds();
    final String shoppingId = newId();
    final String firstPayer = deduped.first.payerId;
    await _db.transaction(() async {
      await _db
          .into(_db.shoppingLists)
          .insert(
            ShoppingListsCompanion.insert(
              id: shoppingId,
              ledgerId: ledgerId,
              title: Value(title),
              merchant: Value(merchant),
              occurredAt: occurred,
              defaultPayerId: Value(firstPayer),
              defaultParticipantIds: Value(
                _snapshotIds(deduped.expand((NewExpenseItem e) => e.participantIds)),
              ),
              note: Value(note),
              source: Value(source),
              createdAt: now,
              updatedAt: now,
            ),
          );
      for (final NewExpenseItem item in deduped) {
        await _insertItem(
          shoppingId: shoppingId,
          ledgerId: ledgerId,
          item: item,
          now: now,
        );
      }
    });
    return getDetail(shoppingId);
    },
  );

  /// 整单替换式编辑（仅当前周期；历史周期抛 [ArchivedReadOnlyException]）。
  Future<ShoppingDetail> updateShoppingList({
    required String shoppingId,
    String? title,
    String? merchant,
    String? note,
    int? occurredAt,
    List<NewExpenseItem>? items,
  }) => AppLogger.audit(
    action: 'shopping.updateShoppingList',
    entity: 'shopping_list',
    id: shoppingId,
    run: () async {
      final ShoppingDetail current = await getDetail(shoppingId);
    _requireCurrentPeriod(current.header.occurredAt);
    final int occurred = occurredAt ?? current.header.occurredAt;
    _requireCurrentPeriod(occurred);
    final int now = nowUnixSeconds();
    final List<NewExpenseItem> raw = items ?? _toNewItems(current.items);
    if (raw.isEmpty) {
      throw ValidationException('购物单至少包含一个账目');
    }
    final List<NewExpenseItem> next = <NewExpenseItem>[
      for (final NewExpenseItem item in raw) _dedupItem(item),
    ];
    for (final NewExpenseItem item in next) {
      if (item.participantIds.isEmpty) {
        throw ValidationException('账目参与人不能为空：${item.name}');
      }
      await _requireMembers(current.header.ledgerId, <String>{
        item.payerId,
        ...item.participantIds,
      });
      await _requireActiveTags(item.tagIds);
    }
    await _db.transaction(() async {
      await (_db.update(_db.shoppingLists)..where(
            (ShoppingLists t) => t.id.equals(shoppingId),
          )).write(
        ShoppingListsCompanion(
          title: title == null ? const Value.absent() : Value(title),
          merchant: merchant == null ? const Value.absent() : Value(merchant),
          note: note == null ? const Value.absent() : Value(note),
          occurredAt: Value(occurred),
          updatedAt: Value(now),
        ),
      );
      await _removeItems(shoppingId, now);
      for (final NewExpenseItem item in next) {
        await _insertItem(
          shoppingId: shoppingId,
          ledgerId: current.header.ledgerId,
          item: item,
          now: now,
        );
      }
    });
    return getDetail(shoppingId);
    },
  );

  /// 软删整单（仅当前周期），级联子账目/分摊，硬删标签关联。
  Future<void> softDeleteShoppingList(String shoppingId) => AppLogger.audit(
    action: 'shopping.softDeleteShoppingList',
    entity: 'shopping_list',
    id: shoppingId,
    run: () async {
      final ShoppingDetail current = await getDetail(shoppingId);
      _requireCurrentPeriod(current.header.occurredAt);
      await _db.transaction(() async {
        await _removeItems(shoppingId, nowUnixSeconds());
        await (_db.update(_db.shoppingLists)..where(
              (ShoppingLists t) => t.id.equals(shoppingId),
            )).write(
          ShoppingListsCompanion(
            deletedAt: Value(nowUnixSeconds()),
            updatedAt: Value(nowUnixSeconds()),
          ),
        );
      });
    },
  );

  /// 单加一件商品（仅当前周期）。
  Future<ShoppingDetail> addItemToShopping({
    required String shoppingId,
    required NewExpenseItem item,
  }) => AppLogger.audit(
    action: 'shopping.addItemToShopping',
    entity: 'expense_item',
    id: shoppingId,
    run: () async {
      final ShoppingDetail current = await getDetail(shoppingId);
      _requireCurrentPeriod(current.header.occurredAt);
      final NewExpenseItem deduped = _dedupItem(item);
      if (deduped.participantIds.isEmpty) {
        throw ValidationException('账目参与人不能为空：${deduped.name}');
      }
      await _requireMembers(current.header.ledgerId, <String>{
        deduped.payerId,
        ...deduped.participantIds,
      });
      await _requireActiveTags(deduped.tagIds);
      final int now = nowUnixSeconds();
      await _db.transaction(() async {
        await _insertItem(
          shoppingId: shoppingId,
          ledgerId: current.header.ledgerId,
          item: deduped,
          now: now,
        );
        await (_db.update(_db.shoppingLists)..where(
              (ShoppingLists t) => t.id.equals(shoppingId),
            )).write(ShoppingListsCompanion(updatedAt: Value(now)));
      });
      return getDetail(shoppingId);
    },
  );

  /// 单改一件商品（仅当前周期；分摊/标签按传入重算重写）。
  Future<ShoppingDetail> updateExpenseItem({
    required String itemId,
    String? name,
    double? quantity,
    int? unitPrice,
    int? finalAmount,
    String? payerId,
    List<String>? participantIds,
    Map<String, int>? shares,
    String? note,
    List<String>? tagIds,
  }) => AppLogger.audit(
    action: 'shopping.updateExpenseItem',
    entity: 'expense_item',
    id: itemId,
    run: () async {
      final ExpenseItem current =
          await (_db.select(_db.expenseItems)..where(
                (ExpenseItems t) =>
                    t.id.equals(itemId) & t.deletedAt.isNull(),
              )).getSingleOrNull() ??
              (throw NotFoundException('账目不存在：$itemId'));
      final ShoppingDetail parent = await getDetail(current.shoppingListId);
      _requireCurrentPeriod(parent.header.occurredAt);
      final String nextPayer = payerId ?? current.payerId;
      final int nextFinal = finalAmount ?? current.finalAmount;
      final List<String>? nextParticipants = participantIds?.toSet().toList();
      final List<String>? nextTagIds = tagIds?.toSet().toList();
      final bool splitTouched =
          nextParticipants != null || shares != null || payerId != null ||
          finalAmount != null;
      List<String> resolvedParticipants = nextParticipants ?? await _participantIdsOf(itemId);
      if (resolvedParticipants.isEmpty) {
        throw ValidationException('账目参与人不能为空：${name ?? current.name}');
      }
      await _requireMembers(parent.header.ledgerId, <String>{
        nextPayer,
        ...resolvedParticipants,
      });
      if (nextTagIds != null) {
        await _requireActiveTags(nextTagIds);
      }
      final int now = nowUnixSeconds();
      await _db.transaction(() async {
        await (_db.update(_db.expenseItems)..where(
              (ExpenseItems t) => t.id.equals(itemId),
            )).write(
          ExpenseItemsCompanion(
            name: name == null ? const Value.absent() : Value(name),
            quantity: quantity == null ? const Value.absent() : Value(quantity),
            unitPrice: unitPrice == null
                ? const Value.absent()
                : Value(unitPrice),
            finalAmount: finalAmount == null
                ? const Value.absent()
                : Value(finalAmount),
            payerId: payerId == null ? const Value.absent() : Value(payerId),
            note: note == null ? const Value.absent() : Value(note),
            updatedAt: Value(now),
          ),
        );
        if (splitTouched) {
          await (_db.update(_db.itemParticipants)..where(
                (ItemParticipants t) =>
                    t.expenseItemId.equals(itemId) & t.deletedAt.isNull(),
              )).write(
            ItemParticipantsCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
          final Map<String, int> nextShares =
              shares ??
              <String, int>{
                for (final SplitShare share in calcSplit(
                  finalAmount: nextFinal,
                  participantIds: resolvedParticipants,
                  payerId: nextPayer,
                ))
                  share.userId: share.shareAmount,
              };
          for (final MapEntry<String, int> share in nextShares.entries) {
            await _db
                .into(_db.itemParticipants)
                .insert(
                  ItemParticipantsCompanion.insert(
                    id: newId(),
                    expenseItemId: itemId,
                    userId: share.key,
                    shareAmount: share.value,
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
          }
        }
        if (tagIds != null) {
          await (_db.delete(_db.itemTags)..where(
                (ItemTags t) => t.expenseItemId.equals(itemId),
              )).go();
          for (final String tagId in nextTagIds!.toSet()) {
            await _db
                .into(_db.itemTags)
                .insert(
                  ItemTagsCompanion.insert(
                    id: newId(),
                    expenseItemId: itemId,
                    tagId: tagId,
                    createdAt: now,
                  ),
                );
          }
        }
        await (_db.update(_db.shoppingLists)..where(
              (ShoppingLists t) => t.id.equals(current.shoppingListId),
            )).write(ShoppingListsCompanion(updatedAt: Value(now)));
      });
      return getDetail(current.shoppingListId);
    },
  );

  /// 单删一件商品（仅当前周期；不允许删剩最后一件，请删整单）。
  Future<ShoppingDetail> removeExpenseItem(String itemId) => AppLogger.audit(
    action: 'shopping.removeExpenseItem',
    entity: 'expense_item',
    id: itemId,
    run: () async {
      final ExpenseItem current =
          await (_db.select(_db.expenseItems)..where(
                (ExpenseItems t) =>
                    t.id.equals(itemId) & t.deletedAt.isNull(),
              )).getSingleOrNull() ??
              (throw NotFoundException('账目不存在：$itemId'));
      final ShoppingDetail parent = await getDetail(current.shoppingListId);
      _requireCurrentPeriod(parent.header.occurredAt);
      if (parent.items.length <= 1) {
        throw ValidationException('购物单至少包含一个账目，请删除整单');
      }
      final int now = nowUnixSeconds();
      await _db.transaction(() async {
        await (_db.update(_db.expenseItems)..where(
              (ExpenseItems t) => t.id.equals(itemId),
            )).write(
          ExpenseItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
        await (_db.update(_db.itemParticipants)..where(
              (ItemParticipants t) =>
                  t.expenseItemId.equals(itemId) & t.deletedAt.isNull(),
            )).write(
          ItemParticipantsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        await (_db.delete(_db.itemTags)..where(
              (ItemTags t) => t.expenseItemId.equals(itemId),
            )).go();
        await (_db.update(_db.shoppingLists)..where(
              (ShoppingLists t) => t.id.equals(current.shoppingListId),
            )).write(ShoppingListsCompanion(updatedAt: Value(now)));
      });
      return getDetail(current.shoppingListId);
    },
  );

  /// 取整单明细（含已软删单头校验，不存在抛 [NotFoundException]）。
  Future<ShoppingDetail> getDetail(String shoppingId) async {
    final ShoppingList? header =
        await (_db.select(_db.shoppingLists)
              ..where(
                (ShoppingLists t) =>
                    t.id.equals(shoppingId) & t.deletedAt.isNull(),
              )).getSingleOrNull();
    if (header == null) {
      throw NotFoundException('购物单不存在：$shoppingId');
    }
    final List<ExpenseItem> items =
        await (_db.select(_db.expenseItems)
              ..where(
                (ExpenseItems t) =>
                    t.shoppingListId.equals(shoppingId) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([
                (ExpenseItems t) =>
                    OrderingTerm.asc(const CustomExpression<int>('rowid')),
              ])).get();
    final List<ExpenseDetail> details = <ExpenseDetail>[];
    for (final ExpenseItem item in items) {
      final List<ItemParticipant> participants =
          await (_db.select(_db.itemParticipants)
                ..where(
                  (ItemParticipants t) =>
                      t.expenseItemId.equals(item.id) &
                      t.deletedAt.isNull(),
                )).get();
      final List<TypedResult> tagRows =
          await (_db.select(_db.itemTags).join([
                innerJoin(
                  _db.tags,
                  _db.tags.id.equalsExp(_db.itemTags.tagId),
                ),
              ])
                ..where(_db.itemTags.expenseItemId.equals(item.id)))
              .get();
      details.add(
        (
          item: item,
          participants: participants,
          tags: <Tag>[
            for (final TypedResult row in tagRows) row.readTable(_db.tags),
          ],
        ),
      );
    }
    return (header: header, items: details);
  }

  /// 插入单个子账目（含分摊与标签），调用方须已开事务并校验周期。
  Future<void> _insertItem({
    required String shoppingId,
    required String ledgerId,
    required NewExpenseItem item,
    required int now,
  }) async {
    if (item.participantIds.isEmpty) {
      throw ValidationException('账目参与人不能为空：${item.name}');
    }
    await _requireActiveTags(item.tagIds);
    await _requireMembers(ledgerId, <String>{
      item.payerId,
      ...item.participantIds,
    });
    final String itemId = newId();
    await _db
        .into(_db.expenseItems)
        .insert(
          ExpenseItemsCompanion.insert(
            id: itemId,
            shoppingListId: shoppingId,
            ledgerId: ledgerId,
            name: item.name,
            quantity: Value(item.quantity),
            unitPrice: Value(item.unitPrice),
            finalAmount: item.finalAmount,
            payerId: item.payerId,
            note: Value(item.note),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final Map<String, int> shares = item.shares ?? <String, int>{
      for (final SplitShare share in calcSplit(
        finalAmount: item.finalAmount,
        participantIds: item.participantIds,
        payerId: item.payerId,
      ))
        share.userId: share.shareAmount,
    };
    for (final MapEntry<String, int> share in shares.entries) {
      await _db
          .into(_db.itemParticipants)
          .insert(
            ItemParticipantsCompanion.insert(
              id: newId(),
              expenseItemId: itemId,
              userId: share.key,
              shareAmount: share.value,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    for (final String tagId in item.tagIds.toSet()) {
      await _db
          .into(_db.itemTags)
          .insert(
            ItemTagsCompanion.insert(
              id: newId(),
              expenseItemId: itemId,
              tagId: tagId,
              createdAt: now,
            ),
          );
    }
  }

  /// 移除整单子账目：软删账目 + 分摊，硬删标签关联。
  Future<void> _removeItems(String shoppingId, int now) async {
    final List<ExpenseItem> items =
        await (_db.select(_db.expenseItems)..where(
              (ExpenseItems t) =>
                  t.shoppingListId.equals(shoppingId) &
                  t.deletedAt.isNull(),
            )).get();
    for (final ExpenseItem item in items) {
      await (_db.update(_db.expenseItems)..where(
            (ExpenseItems t) => t.id.equals(item.id),
          )).write(
        ExpenseItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (_db.update(_db.itemParticipants)..where(
            (ItemParticipants t) =>
                t.expenseItemId.equals(item.id) & t.deletedAt.isNull(),
          )).write(
        ItemParticipantsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (_db.delete(_db.itemTags)..where(
            (ItemTags t) => t.expenseItemId.equals(item.id),
          )).go();
    }
  }

  /// 校验用户集合均为账本活跃成员。
  /// 入参去重（防直调重复选择，静默合并）。
  NewExpenseItem _dedupItem(NewExpenseItem item) => (
    name: item.name,
    quantity: item.quantity,
    unitPrice: item.unitPrice,
    finalAmount: item.finalAmount,
    payerId: item.payerId,
    participantIds: item.participantIds.toSet().toList(),
    shares: item.shares,
    note: item.note,
    tagIds: item.tagIds.toSet().toList(),
  );

  /// 新账目仅可用活跃标签（已归档/已删/不存在一律拒写，历史引用展示不动）。
  Future<void> _requireActiveTags(List<String> tagIds) async {
    for (final String tagId in tagIds.toSet()) {
      final Tag? tag =
          await (_db.select(_db.tags)..where(
                (Tags t) =>
                    t.id.equals(tagId) &
                    t.archivedAt.isNull() &
                    t.deletedAt.isNull(),
              )).getSingleOrNull();
      if (tag == null) {
        throw ValidationException('标签已归档或不存在，请重新选择');
      }
    }
  }
  Future<List<String>> _participantIdsOf(String itemId) async {
    final List<ItemParticipant> rows =
        await (_db.select(_db.itemParticipants)..where(
              (ItemParticipants t) =>
                  t.expenseItemId.equals(itemId) & t.deletedAt.isNull(),
            )).get();
    return <String>[for (final ItemParticipant e in rows) e.userId];
  }

  Future<void> _requireMembers(String ledgerId, Set<String> userIds) async {
    final List<LedgerMember> members =
        await (_db.select(_db.ledgerMembers)..where(
              (LedgerMembers t) =>
                  t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
            )).get();
    final Set<String> memberIds = <String>{
      for (final LedgerMember member in members) member.userId,
    };
    for (final String userId in userIds) {
      if (!memberIds.contains(userId)) {
        throw ValidationException('非账本活跃成员：$userId');
      }
    }
  }

  void _requireCurrentPeriod(int occurredAt) {
    if (isArchivedPeriod(occurredAt)) {
      throw ArchivedReadOnlyException('历史周期数据只读，不可写入');
    }
  }

  /// 默认参与人快照：全单去重参与人 JSON 数组。
  String _snapshotIds(Iterable<String> ids) {
    final List<String> unique = ids.toSet().toList();
    return '[${unique.map((String id) => '"$id"').join(',')}]';
  }

  List<NewExpenseItem> _toNewItems(List<ExpenseDetail> details) =>
      <NewExpenseItem>[
        for (final ExpenseDetail detail in details)
          (
            name: detail.item.name,
            quantity: detail.item.quantity,
            unitPrice: detail.item.unitPrice,
            finalAmount: detail.item.finalAmount,
            payerId: detail.item.payerId,
            participantIds: <String>[
              for (final ItemParticipant participant in detail.participants)
                participant.userId,
            ],
            shares: <String, int>{
              for (final ItemParticipant participant in detail.participants)
                participant.userId: participant.shareAmount,
            },
            note: detail.item.note,
            tagIds: <String>[
              for (final Tag tag in detail.tags) tag.id,
            ],
          ),
      ];
}
