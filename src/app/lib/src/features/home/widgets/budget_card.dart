import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../providers/home_providers.dart';

/// 首页预算卡：对照 Figma 356×125 Hug 手搓。
///
/// - 标题“{M}月预算” + 金额“¥已消费 / ¥预算” + 进度条 + “已用 N%”；
/// - 进度色：<50% 蓝 / 50–90% 橙 / ≥90% 红；超支仅红字警告，不阻断；
/// - 未设预算：金额分母显示“未设置”，进度条置灰；
/// - 三态：loading 转圈占位 / error 展示 + 重试 / data 渲染。
class BudgetCard extends ConsumerWidget {
  /// 创建预算卡。
  const BudgetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<({int? budget, int spent, bool overBudget})> progress =
        ref.watch(currentBudgetProgressProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: progress.when(
          loading: () => const _BudgetLoading(),
          error: (Object error, StackTrace stack) => _BudgetError(
            onRetry: () =>
                ref.read(currentBudgetProgressProvider.notifier).refresh(),
          ),
          data: (({int? budget, int spent, bool overBudget}) data) =>
              _BudgetBody(
                spent: data.spent,
                budget: data.budget,
                overBudget: data.overBudget,
              ),
        ),
      ),
    );
  }
}

/// 预算加载态：固定高度占位 + 居中进度条，避免布局跳动。
class _BudgetLoading extends StatelessWidget {
  /// 创建加载态。
  const _BudgetLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 93,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// 预算失败态：错误提示 + 重试（首错直抛由 UI 重试）。
class _BudgetError extends StatelessWidget {
  /// 创建失败态。
  const _BudgetError({required this.onRetry});

  /// 重试回调。
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 93,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('预算加载失败', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

/// 预算数据体：标题 + 金额 + 三色进度条 + 百分比。
class _BudgetBody extends StatelessWidget {
  /// 创建数据体。
  const _BudgetBody({
    required this.spent,
    required this.budget,
    required this.overBudget,
  });

  /// 已消费（分）。
  final int spent;

  /// 预算（分，未设置则 null）。
  final int? budget;

  /// 是否超支。
  final bool overBudget;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final int month = DateTime.now().month;
    final int? budgetCents = budget;
    final double ratio = budgetCents == null || budgetCents <= 0
        ? 0
        : (spent / budgetCents).clamp(0.0, 1.0);
    final Color barColor = budgetCents == null
        ? AppTheme.secondaryGray
        : ratio < 0.5
        ? AppTheme.primaryBlue
        : ratio < 0.9
        ? AppTheme.warnOrange
        : AppTheme.dangerRed;
    final String percent = budgetCents == null || budgetCents <= 0
        ? '未设置预算'
        : overBudget
        ? '已用 ${(spent / budgetCents * 100).round()}%（已超支）'
        : '已用 ${(spent / budgetCents * 100).round()}%';
    final Color percentColor = overBudget
        ? AppTheme.dangerRed
        : AppTheme.secondaryGray;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$month月预算',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          budgetCents == null
              ? '¥${formatCents(spent)} / 未设置'
              : '¥${formatCents(spent)} / ¥${formatCents(budgetCents)}',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: AppTheme.grayButtonBackground,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          percent,
          style: textTheme.bodySmall?.copyWith(color: percentColor),
        ),
      ],
    );
  }
}
