import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/app_time.dart';
import '../../budget/data/budget_repository.dart';
import '../../timeline/data/timeline_entries.dart';
import '../data/entry_media_service.dart';
import 'home_filter.dart';

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

/// 首页最近数据：跨账本条目（倒序）+ 账本名映射，只读聚合不碰后端。
typedef HomeRecentData = ({
  List<TimelineEntry> entries,
  Map<String, String> ledgerNames,
});

/// 首页筛选条件（内存过滤，变更后最近列表自动重刷）。
class HomeFilterNotifier extends Notifier<HomeFilter> {
  @override
  HomeFilter build() => const HomeFilter();

  /// 应用新条件（列表自动重刷）。
  void apply(HomeFilter filter) {
    state = filter;
  }
}

/// 首页筛选条件 provider。
final homeFilterProvider =
    NotifierProvider<HomeFilterNotifier, HomeFilter>(
      HomeFilterNotifier.new,
    );

/// 首页最近：跨所有账本扇出后按发生时间倒序合并，默认只留近 7 天。
///
/// 只读聚合放 UI 侧，不污染后端 Repository；渲染侧懒加载；
/// 日期条件为空时按默认窗口，有起止日期则按整天展开替代窗口。
class HomeRecentNotifier extends AsyncNotifier<HomeRecentData> {
  /// 默认窗口：近 7 天（秒）。
  static const int defaultWindowSeconds = 7 * 24 * 3600;

  @override
  Future<HomeRecentData> build() => _fetch();

  /// 重试入口（首错直抛由 UI 重试）。
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<HomeRecentData> _fetch() async {
    final HomeFilter filter = ref.watch(homeFilterProvider);
    final List<Ledger> ledgers = await ref.watch(
      ledgerListProvider.future,
    );
    final Map<String, String> names = <String, String>{
      for (final Ledger ledger in ledgers) ledger.id: ledger.name,
    };
    final List<TimelineEntry> merged = <TimelineEntry>[];
    for (final Ledger ledger in ledgers) {
      merged.addAll(
        await ref
            .watch(timelineRepositoryProvider)
            .listTimeline(ledger.id),
      );
    }
    merged.sort(
      (TimelineEntry a, TimelineEntry b) =>
          b.occurredAt.compareTo(a.occurredAt),
    );
    final int now = nowUnixSeconds();
    final int windowStart = filter.startDate != null
        ? _dayStartSeconds(filter.startDate!)
        : now - defaultWindowSeconds;
    final int? windowEnd = filter.endDate != null
        ? _dayEndSeconds(filter.endDate!)
        : null;
    return (
      entries: <TimelineEntry>[
        for (final TimelineEntry entry in merged)
          if (matchesHomeFilter(
            entry,
            filter,
            windowStartSeconds: windowStart,
            windowEndSeconds: windowEnd,
          ))
            entry,
      ],
      ledgerNames: names,
    );
  }

  /// 当天 00:00:00（本地时区，Unix 秒）。
  int _dayStartSeconds(DateTime date) {
    return DateTime(date.year, date.month, date.day).millisecondsSinceEpoch ~/
        1000;
  }

  /// 当天 23:59:59（本地时区，Unix 秒）。
  int _dayEndSeconds(DateTime date) {
    return DateTime(
          date.year,
          date.month,
          date.day,
          23,
          59,
          59,
        ).millisecondsSinceEpoch ~/
        1000;
  }
}

/// 首页最近 provider。
final homeRecentProvider =
    AsyncNotifierProvider<HomeRecentNotifier, HomeRecentData>(
      HomeRecentNotifier.new,
    );

/// 录入选图服务：拍照/相册权限 + 系统选图（AI 链路下期）。
final entryMediaServiceProvider = Provider<EntryMediaService>(
  (Ref ref) => EntryMediaService(),
);
