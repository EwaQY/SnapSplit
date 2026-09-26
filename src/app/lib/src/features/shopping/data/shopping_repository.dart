import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/app_time.dart';
import '../../../core/utils/ids.dart';
import '../domain/split_calculator.dart';

/// 新建账目入参：`shares` 为空时按参与人均摊。
typedef NewExpenseItem = ({
  String name,
  int quantity,
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
    required int quantity,
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
  }) async {
    if (items.isEmpty) {
      throw ValidationException('购物单至少包含一个账目');
    }
    final int occurred = occurredAt ?? nowUnixSeconds();
    _requireCurrentPeriod(occurred);
    for (final NewExpenseItem item in items) {
      if (item.participantIds.isEmpty) {
        throw ValidationException('账目参与人不能为空：${item.name}');
      }
      await _requireMembers(ledgerId, <String>{
        item.payerId,
        ...item.participantIds,
      });
    }
    final int now = nowUnixSeconds();
    final String shoppingId = newId();
    final String firstPayer = items.first.payerId;
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
                _snapshotIds(items.expand((NewExpenseItem e) => e.participantIds)),
              ),
              note: Value(note),
              source: Value(source),
              createdAt: now,
              updatedAt: now,
            ),
          );
      for (final NewExpenseItem item in items) {
        await _insertItem(
          shoppingId: shoppingId,
          ledgerId: ledgerId,
          item: item,
          now: now,
        );
      }
    });
    return getDetail(shoppingId);
  }

  /// 整单替换式编辑（仅当前周期；历史周期抛 [ArchivedReadOnlyException]）。
  Future<ShoppingDetail> updateShoppingList({
    required String shoppingId,
    String? title,
    String? merchant,
    String? note,
    int? occurredAt,
    List<NewExpenseItem>? items,
  }) async {
    final ShoppingDetail current = await getDetail(shoppingId);
    _requireCurrentPeriod(current.header.occurredAt);
    final int occurred = occurredAt ?? current.header.occurredAt;
    _requireCurrentPeriod(occurred);
    final int now = nowUnixSeconds();
    final List<NewExpenseItem> next = items ?? _toNewItems(current.items);
    if (next.isEmpty) {
      throw ValidationException('购物单至少包含一个账目');
    }
    for (final NewExpenseItem item in next) {
      if (item.participantIds.isEmpty) {
        throw ValidationException('账目参与人不能为空：${item.name}');
      }
      await _requireMembers(current.header.ledgerId, <String>{
        item.payerId,
        ...item.participantIds,
      });
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
  }

  /// 软删整单（仅当前周期），级联子账目/分摊，硬删标签关联。
  Future<void> softDeleteShoppingList(String shoppingId) async {
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
  }

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
