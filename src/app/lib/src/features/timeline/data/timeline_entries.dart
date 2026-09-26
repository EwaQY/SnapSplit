import '../../../core/database/app_database.dart';
import '../../shopping/data/shopping_repository.dart';

/// 时间线条目：账本内按发生时间倒序的统一视图。
///
/// - 单账目购物单降维为 [SingleItemEntry]（仍携带单头，发生时间取单头）；
/// - 多账目购物单为 [ShoppingEntry]（后端返回全量子账目，
///   `>5 折叠` 由 UI 层按 `items.length` 处理）；
/// - 转账记录为 [TransferEntry]，与消费同层独立展示；
/// - 归档判断由调用方用 `isArchivedPeriod(entry.occurredAt)`（历史仅查看）。
sealed class TimelineEntry {
  const TimelineEntry();

  int get occurredAt;

  String get id;
}

/// 单账目条目（UI 直接展示为账目）。
final class SingleItemEntry extends TimelineEntry {
  const SingleItemEntry(this.header, this.detail);

  final ShoppingList header;
  final ExpenseDetail detail;

  @override
  int get occurredAt => header.occurredAt;

  @override
  String get id => header.id;
}

/// 多商品购物单条目。
final class ShoppingEntry extends TimelineEntry {
  const ShoppingEntry(this.header, this.items);

  final ShoppingList header;
  final List<ExpenseDetail> items;

  @override
  int get occurredAt => header.occurredAt;

  @override
  String get id => header.id;
}

/// 转账条目。
final class TransferEntry extends TimelineEntry {
  const TransferEntry(this.transfer);

  final Transfer transfer;

  @override
  int get occurredAt => transfer.occurredAt;

  @override
  String get id => transfer.id;
}
