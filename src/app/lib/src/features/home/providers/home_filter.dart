import 'package:flutter/foundation.dart';

import '../../timeline/data/timeline_entries.dart';

/// 首页筛选条件：全部内存过滤，不动 DB/索引。
///
/// - 全空 = 不筛（日期空时由调用方按默认近 7 天窗口过滤）；
/// - 金额单位为分（UI 输入元，打开弹窗时 ×100 转入）；
/// - 日期只取年月日（时分秒由匹配时按整天展开）。
@immutable
class HomeFilter {
  /// 创建筛选条件。
  const HomeFilter({
    this.ledgerId,
    this.tagIds = const <String>{},
    this.payerId,
    this.participantIds = const <String>{},
    this.minAmountCents,
    this.maxAmountCents,
    this.startDate,
    this.endDate,
    this.keyword = '',
  });

  /// 账本 id（null = 所有账本）。
  final String? ledgerId;

  /// 标签 ids（空 = 不限，多选为或关系）。
  final Set<String> tagIds;

  /// 付款人 userId（null = 不限）。
  final String? payerId;

  /// 参与人 userIds（空 = 不限，命中任一即算）。
  final Set<String> participantIds;

  /// 最小金额（分，null = 不限）。
  final int? minAmountCents;

  /// 最大金额（分，null = 不限）。
  final int? maxAmountCents;

  /// 开始日期（null = 不限，匹配时按当天 00:00:00 展开）。
  final DateTime? startDate;

  /// 结束日期（null = 不限，匹配时按当天 23:59:59 展开）。
  final DateTime? endDate;

  /// 关键字（去空格后空串 = 不限，匹配账目名/单标题/转账备注）。
  final String keyword;

  /// 是否无任何条件。
  bool get isEmpty =>
      ledgerId == null &&
      tagIds.isEmpty &&
      payerId == null &&
      participantIds.isEmpty &&
      minAmountCents == null &&
      maxAmountCents == null &&
      startDate == null &&
      endDate == null &&
      keyword.trim().isEmpty;

  @override
  bool operator ==(Object other) {
    return other is HomeFilter &&
        other.ledgerId == ledgerId &&
        setEquals(other.tagIds, tagIds) &&
        other.payerId == payerId &&
        setEquals(other.participantIds, participantIds) &&
        other.minAmountCents == minAmountCents &&
        other.maxAmountCents == maxAmountCents &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.keyword == keyword;
  }

  @override
  int get hashCode => Object.hash(
    ledgerId,
    Object.hashAllUnordered(tagIds),
    payerId,
    Object.hashAllUnordered(participantIds),
    minAmountCents,
    maxAmountCents,
    startDate,
    endDate,
    keyword,
  );
}

/// 条目所属账本 id。
String entryLedgerId(TimelineEntry entry) {
  switch (entry) {
    case SingleItemEntry(header: final header):
      return header.ledgerId;
    case ShoppingEntry(header: final header):
      return header.ledgerId;
    case TransferEntry(transfer: final transfer):
      return transfer.ledgerId;
  }
}

/// 条目展示金额（分）：单账目取账目金额，多账目取合计，转账取转账金额。
int entryAmountCents(TimelineEntry entry) {
  switch (entry) {
    case SingleItemEntry(detail: final detail):
      return detail.item.finalAmount;
    case ShoppingEntry(items: final items):
      return items.fold(0, (int sum, item) => sum + item.item.finalAmount);
    case TransferEntry(transfer: final transfer):
      return transfer.amount;
  }
}

/// 条目是否命中筛选（日期窗口由调用方按整天展开后传入秒时间戳）。
///
/// 转账无标签/付款人/参与人：这三项任一设条件即不同转账。
bool matchesHomeFilter(
  TimelineEntry entry,
  HomeFilter filter, {
  required int windowStartSeconds,
  int? windowEndSeconds,
}) {
  if (filter.ledgerId != null && entryLedgerId(entry) != filter.ledgerId) {
    return false;
  }
  if (entry.occurredAt < windowStartSeconds) {
    return false;
  }
  final int? windowEnd = windowEndSeconds;
  if (windowEnd != null && entry.occurredAt > windowEnd) {
    return false;
  }
  final int? min = filter.minAmountCents;
  if (min != null && entryAmountCents(entry) < min) {
    return false;
  }
  final int? max = filter.maxAmountCents;
  if (max != null && entryAmountCents(entry) > max) {
    return false;
  }
  final String keyword = filter.keyword.trim();
  if (keyword.isNotEmpty && !_matchesKeyword(entry, keyword)) {
    return false;
  }
  if (filter.tagIds.isEmpty &&
      filter.payerId == null &&
      filter.participantIds.isEmpty) {
    return true;
  }
  switch (entry) {
    case SingleItemEntry(detail: final detail):
      return _matchesDetail(
        tagIds: detail.tags.map((tag) => tag.id),
        payerId: detail.item.payerId,
        participantIds: detail.participants.map((p) => p.userId),
        filter: filter,
      );
    case ShoppingEntry(items: final items):
      return items.any(
        (item) => _matchesDetail(
          tagIds: item.tags.map((tag) => tag.id),
          payerId: item.item.payerId,
          participantIds: item.participants.map((p) => p.userId),
          filter: filter,
        ),
      );
    case TransferEntry():
      return false;
  }
}

/// 单账目维度命中：标签/付款人/参与人均为且关系（标签与参与人内部为或）。
bool _matchesDetail({
  required Iterable<String> tagIds,
  required String payerId,
  required Iterable<String> participantIds,
  required HomeFilter filter,
}) {
  if (filter.tagIds.isNotEmpty &&
      !tagIds.any(filter.tagIds.contains)) {
    return false;
  }
  if (filter.payerId != null && payerId != filter.payerId) {
    return false;
  }
  if (filter.participantIds.isNotEmpty &&
      !participantIds.any(filter.participantIds.contains)) {
    return false;
  }
  return true;
}

/// 关键字命中：账目名 / 单标题 / 转账备注任一包含。
bool _matchesKeyword(TimelineEntry entry, String keyword) {
  switch (entry) {
    case SingleItemEntry(header: final header, detail: final detail):
      return detail.item.name.contains(keyword) ||
          (header.title?.contains(keyword) ?? false);
    case ShoppingEntry(header: final header, items: final items):
      return (header.title?.contains(keyword) ?? false) ||
          items.any((item) => item.item.name.contains(keyword));
    case TransferEntry(transfer: final transfer):
      return '转账'.contains(keyword) ||
          (transfer.note?.contains(keyword) ?? false);
  }
}
