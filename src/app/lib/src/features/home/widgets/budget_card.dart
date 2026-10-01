import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../providers/home_providers.dart';

/// 首页预算卡：标题 + 金额 + 三色进度条 + 百分比；超支仅警告不阻断。
///
/// 自动布局：垂直 gap 8，内边距 `14/16/14/16`，高 Hug 不写死；
/// 进度条轨道宽 Fill（`double.infinity`）、高 6、圆角 3；
/// - 标题 17/700 黑 + 金额 22/900 黑 + 进度条 + 百分比 13/400 灰；
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
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
      height: 97,
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
      height: 97,
      child: Center(
        child: Column(
          spacing: 8,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('预算加载失败', style: AppTheme.rowTitle),
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
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('$month月预算', style: AppTheme.sectionTitle),
        Text(
          budgetCents == null
              ? '¥${formatCents(spent)} / 未设置'
              : '¥${formatCents(spent)} / ¥${formatCents(budgetCents)}',
          style: AppTheme.budgetAmount,
        ),
        ClipRRect(
          borderRadius: const BorderRadius.all(
            Radius.circular(AppTheme.radiusTrack),
          ),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppTheme.trackGray,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        Text(
          percent,
          style: AppTheme.rowSubtitle.copyWith(color: percentColor),
        ),
      ],
    );
  }
}
