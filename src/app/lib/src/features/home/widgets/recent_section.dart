import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../common_widgets/async_state_box.dart';
import '../../../common_widgets/bill_list.dart';
import '../../timeline/data/timeline_entries.dart';
import '../presentation/filter_sheet.dart';
import '../providers/home_filter.dart';
import '../providers/home_providers.dart';

/// 首页最近分区：白卡标题 + 筛选行 + 跨账本倒序列表。
///
/// 自动布局：垂直 gap 8，内边距 `14/16/14/16`，高 Hug 不写死；
/// - 白卡：标题“最近”17/700 黑 + 筛选行 + 列表；
/// - 列表跨账本倒序，默认近 7 天（provider 内过滤）；
/// - 三态：loading 占位 / error + 重试 / 空（暂无记录）/ 到底（没有更多了 12/400 灰居中）；
/// - “筛选”按钮打开筛选弹窗，确定后回刷列表（内存过滤）。
class RecentSection extends ConsumerWidget {
  /// 创建最近分区。
  const RecentSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeRecentData> recent = ref.watch(homeRecentProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('最近', style: AppTheme.sectionTitle),
            _FilterRow(
              onFilterTap: () => showHomeFilterSheet(context),
            ),
            recent.when(
              loading: () => const LoadingBox(height: 120),
              error: (Object error, StackTrace stack) => ErrorRetryBox(
                message: '最近列表加载失败',
                onRetry: () =>
                    ref.read(homeRecentProvider.notifier).refresh(),
              ),
              data: (HomeRecentData data) => BillList(
                rows: <BillRowData>[
                  for (final TimelineEntry entry in data.entries)
                    _rowFor(entry, data.ledgerNames),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 筛选行：左摘要（账本范围 / 日期范围 14/400 灰 + 16 灰图标），右筛选键。
///
/// 摘要随 [homeFilterProvider] 实时变化：未设日期显示“近7天”，
/// 已设则显示起止 MM-dd。
class _FilterRow extends ConsumerWidget {
  /// 创建筛选行。
  const _FilterRow({required this.onFilterTap});

  /// 点击筛选按钮回调。
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HomeFilter filter = ref.watch(homeFilterProvider);
    final Map<String, String> names =
        ref.watch(homeRecentProvider).value?.ledgerNames ??
        <String, String>{};
    final String ledgerText = filter.ledgerId == null
        ? '所有账本'
        : names[filter.ledgerId] ?? '所有账本';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          spacing: 4,
          children: <Widget>[
            const Icon(
              Icons.receipt_long_outlined,
              size: 16,
              color: AppTheme.filterGray,
            ),
            Text(ledgerText, style: AppTheme.filterSummary),
            const SizedBox(width: 12),
            const Icon(
              Icons.date_range_outlined,
              size: 16,
              color: AppTheme.filterGray,
            ),
            Text(_dateText(filter), style: AppTheme.filterSummary),
          ],
        ),
        InkWell(
          onTap: onFilterTap,
          borderRadius: const BorderRadius.all(
            Radius.circular(AppTheme.radiusSmall),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: BoxDecoration(
              color: AppTheme.lightBlueBackground,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppTheme.radiusSmall),
              ),
            ),
            child: Text('筛选', style: AppTheme.filterLabel),
          ),
        ),
      ],
    );
  }

  /// 日期摘要：未设为“近7天”，已设显示起止 MM-dd（半开区间只显示已设端）。
  String _dateText(HomeFilter filter) {
    final DateTime? start = filter.startDate;
    final DateTime? end = filter.endDate;
    if (start == null && end == null) {
      return '近7天';
    }
    String part(DateTime? date) => date == null
        ? ''
        : '${date.month.toString().padLeft(2, '0')}-'
              '${date.day.toString().padLeft(2, '0')}';
    return '${part(start)}~${part(end)}';
  }
}

/// 条目转行数据：单账目降维为账目，多账目取标题 + 合计，转账独立行。
BillRowData _rowFor(
  TimelineEntry entry,
  Map<String, String> ledgerNames,
) {
  switch (entry) {
    case SingleItemEntry(header: final ShoppingList header, detail: final detail):
      return (
        title: detail.item.name,
        subtitle:
            '${ledgerNames[header.ledgerId] ?? '未知账本'} · ${_date(header.occurredAt)}',
        amountText: '¥${formatCents(detail.item.finalAmount)}',
      );
    case ShoppingEntry(header: final ShoppingList header, items: final items):
      final int total = items.fold(
        0,
        (int sum, item) => sum + item.item.finalAmount,
      );
      return (
        title: header.title ?? '购物单',
        subtitle:
            '${ledgerNames[header.ledgerId] ?? '未知账本'} · ${_date(header.occurredAt)}',
        amountText: '¥${formatCents(total)}',
      );
    case TransferEntry(transfer: final Transfer transfer):
      return (
        title: '转账',
        subtitle:
            '${ledgerNames[transfer.ledgerId] ?? '未知账本'} · ${_date(transfer.occurredAt)}',
        amountText: '¥${formatCents(transfer.amount)}',
      );
  }
}

/// 秒时间戳转 yyyy-MM-dd。
String _date(int seconds) {
  final DateTime date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}
