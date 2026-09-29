import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../shopping/data/shopping_repository.dart';
import 'timeline_entries.dart';

/// 时间线 Repository：账本全量条目倒序聚合（只读）。
///
/// 口径：未软删的购物单 + 转账，按 `occurred_at` 倒序（同秒按 rowid 兜底）；
/// 单账目购物单降维，多账目返回全量子账目；多图批次不合并展示。
class TimelineRepository {
  TimelineRepository(this._db, this._shopping);

  final AppDatabase _db;
  final ShoppingRepository _shopping;

  Future<List<TimelineEntry>> listTimeline(String ledgerId) async {
    final List<ShoppingList> headers =
        await (_db.select(_db.shoppingLists)
              ..where(
                (ShoppingLists t) =>
                    t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
              )
              ..orderBy([
                (ShoppingLists t) => OrderingTerm.desc(t.occurredAt),
                (_) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
              ])).get();
    final List<Transfer> transfers =
        await (_db.select(_db.transfers)
              ..where(
                (Transfers t) =>
                    t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
              )
              ..orderBy([
                (Transfers t) => OrderingTerm.desc(t.occurredAt),
                (_) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
              ])).get();

    final List<TimelineEntry> entries = <TimelineEntry>[];
    for (final ShoppingList header in headers) {
      final ShoppingDetail detail = await _shopping.getDetail(header.id);
      if (detail.items.length == 1) {
        entries.add(SingleItemEntry(header, detail.items.single));
      } else {
        entries.add(ShoppingEntry(header, detail.items));
      }
    }
    for (final Transfer transfer in transfers) {
      entries.add(TransferEntry(transfer));
    }
    entries.sort((TimelineEntry a, TimelineEntry b) {
      final int byTime = b.occurredAt.compareTo(a.occurredAt);
      if (byTime != 0) {
        return byTime;
      }
      final int byKind = _kindRank(a).compareTo(_kindRank(b));
      if (byKind != 0) {
        return byKind;
      }
      return b.id.compareTo(a.id);
    });
    return entries;
  }

  /// 同秒确定性次序：转账优先于购物单，单账目优先于多账目。
  int _kindRank(TimelineEntry entry) => switch (entry) {
    TransferEntry() => 0,
    SingleItemEntry() => 1,
    ShoppingEntry() => 2,
  };
}
