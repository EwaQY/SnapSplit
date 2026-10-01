import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../timeline/data/timeline_entries.dart';
import '../providers/home_providers.dart';
import 'recent_item_card.dart';

/// 首页最近分区：白卡标题 + 筛选行 + 跨账本倒序列表。
///
/// - 白卡：标题“最近” + 筛选行（所有账本 / 近7天 / 筛选按钮）；
/// - 列表跨账本倒序，默认近 7 天（provider 内过滤）；
/// - 三态：loading 占位 / error + 重试 / 空（暂无记录）/ 到底（没有更多了）；
/// - “筛选”按钮本期占位（P-UI3 接筛选弹窗）。
class RecentSection extends ConsumerWidget {
  /// 创建最近分区。
  const RecentSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeRecentData> recent = ref.watch(homeRecentProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '最近',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _FilterRow(
              onFilterTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('筛选弹窗下期再做')),
                );
              },
            ),
            const SizedBox(height: 12),
            recent.when(
              loading: () => const _RecentLoading(),
              error: (Object error, StackTrace stack) => _RecentError(
                onRetry: () =>
                    ref.read(homeRecentProvider.notifier).refresh(),
              ),
              data: (HomeRecentData data) => _RecentList(data: data),
            ),
          ],
        ),
      ),
    );
  }
}

/// 筛选行：当前范围摘要（默认所有账本 / 近7天）+ 筛选按钮。
class _FilterRow extends StatelessWidget {
  /// 创建筛选行。
  const _FilterRow({required this.onFilterTap});

  /// 点击筛选按钮回调。
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    final TextStyle? summaryStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(
      fontSize: 13,
      color: AppTheme.secondaryGray,
    );
    return Row(
      children: <Widget>[
        const Icon(
          Icons.receipt_long_outlined,
          size: 16,
          color: AppTheme.secondaryGray,
        ),
        const SizedBox(width: 4),
        Text('所有账本', style: summaryStyle),
        const SizedBox(width: 12),
        const Icon(
          Icons.date_range_outlined,
          size: 16,
          color: AppTheme.secondaryGray,
        ),
        const SizedBox(width: 4),
        Text('近7天', style: summaryStyle),
        const Spacer(),
        InkWell(
          onTap: onFilterTap,
          borderRadius: const BorderRadius.all(
            Radius.circular(AppTheme.radiusLarge),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.lightBlueBackground,
              borderRadius: BorderRadius.all(
                Radius.circular(AppTheme.radiusLarge),
              ),
            ),
            child: Text(
              '筛选',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 13,
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 最近加载态。
class _RecentLoading extends StatelessWidget {
  /// 创建加载态。
  const _RecentLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// 最近失败态 + 重试。
class _RecentError extends StatelessWidget {
  /// 创建失败态。
  const _RecentError({required this.onRetry});

  /// 重试回调。
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('最近列表加载失败', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

/// 最近列表：懒加载 + 空态 + 到底标记。
class _RecentList extends StatelessWidget {
  /// 创建最近列表。
  const _RecentList({required this.data});

  /// 聚合数据。
  final HomeRecentData data;

  @override
  Widget build(BuildContext context) {
    if (data.entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '暂无最近记录',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.secondaryGray,
            ),
          ),
        ),
      );
    }
    return Column(
      children: <Widget>[
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.entries.length,
          itemBuilder: (BuildContext context, int index) {
            final TimelineEntry entry = data.entries[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == data.entries.length - 1 ? 0 : 12,
              ),
              child: _rowFor(entry, data.ledgerNames),
            );
          },
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '没有更多了',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: AppTheme.secondaryGray,
            ),
          ),
        ),
      ],
    );
  }

  /// 条目转行：单账目降维为账目，多账目取标题 + 合计，转账独立行。
  RecentItemCard _rowFor(
    TimelineEntry entry,
    Map<String, String> ledgerNames,
  ) {
    switch (entry) {
      case SingleItemEntry(header: final ShoppingList header, detail: final detail):
        return RecentItemCard(
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
        return RecentItemCard(
          title: header.title ?? '购物单',
          subtitle:
              '${ledgerNames[header.ledgerId] ?? '未知账本'} · ${_date(header.occurredAt)}',
          amountText: '¥${formatCents(total)}',
        );
      case TransferEntry(transfer: final Transfer transfer):
        return RecentItemCard(
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
}
