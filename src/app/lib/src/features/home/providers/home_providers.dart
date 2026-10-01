import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/app_providers.dart';
import '../../budget/data/budget_repository.dart';

/// 首页预算进度：当前“我” + 自然当月的 [BudgetProgress] 只读聚合。
///
/// - 身份经 `ensureSelf` 幂等取得（bootstrap 已建，这里复用，无副作用）；
/// - 月份取设备本地自然月；后端 `getProgress` 历史月只读、当月可写，
///   本卡只读，不污染后端 Repository；
/// - 显式三态由调用方按 `AsyncValue` 展开，不用空值糊弄 UI。
class CurrentBudgetProgressNotifier extends AsyncNotifier<BudgetProgress> {
  @override
  Future<BudgetProgress> build() => _fetch();

  /// 下拉/按钮重试入口（首错直抛由 UI 重试，后端不自动重试）。
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<BudgetProgress> _fetch() async {
    final User self = await ref.watch(userRepositoryProvider).ensureSelf();
    final DateTime now = DateTime.now();
    return ref
        .watch(budgetRepositoryProvider)
        .getProgress(userId: self.id, year: now.year, month: now.month);
  }
}

/// 首页预算进度 provider。
final currentBudgetProgressProvider =
    AsyncNotifierProvider<CurrentBudgetProgressNotifier, BudgetProgress>(
      CurrentBudgetProgressNotifier.new,
    );
