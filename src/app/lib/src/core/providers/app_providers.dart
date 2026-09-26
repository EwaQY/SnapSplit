import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../../features/ai_ingest/data/ai_ingest_repository.dart';
import '../../features/budget/data/budget_repository.dart';
import '../../features/ledger/data/ledger_repository.dart';
import '../../features/profile/data/user_repository.dart';
import '../../features/settlement/data/settlement_repository.dart';
import '../../features/settlement/domain/settlement_calculator.dart';
import '../../features/shopping/data/shopping_repository.dart';
import '../../features/tags/data/tag_repository.dart';
import '../../features/timeline/data/timeline_entries.dart';
import '../../features/timeline/data/timeline_repository.dart';
import '../../features/transfer/data/transfer_repository.dart';

/// 应用 providers：UI 层唯一入口（Repository 经此注入，便于测试替换）。
///
/// 手写 providers（不用 riverpod_generator：其 codegen 与 drift 生成类型 /
/// sqlite3 导入存在已知不兼容 `InvalidTypeException`，官方无修复计划）。
/// 数据库默认未接线：App 启动时用 `overrideWithValue` 注入
/// `AppDatabase.appFile()`；测试注入 `AppDatabase.memory()`。

/// 数据库（默认未接线，启动/测试时覆盖）。
final appDatabaseProvider = Provider<AppDatabase>(
  (Ref ref) => throw UnimplementedError(
    'appDatabaseProvider 未覆盖：启动时注入 AppDatabase.appFile()',
  ),
);

final userRepositoryProvider = Provider<UserRepository>(
  (Ref ref) => UserRepository(ref.watch(appDatabaseProvider)),
);

final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (Ref ref) => LedgerRepository(ref.watch(appDatabaseProvider)),
);

final shoppingRepositoryProvider = Provider<ShoppingRepository>(
  (Ref ref) => ShoppingRepository(ref.watch(appDatabaseProvider)),
);

final transferRepositoryProvider = Provider<TransferRepository>(
  (Ref ref) => TransferRepository(ref.watch(appDatabaseProvider)),
);

final tagRepositoryProvider = Provider<TagRepository>(
  (Ref ref) => TagRepository(ref.watch(appDatabaseProvider)),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (Ref ref) => BudgetRepository(ref.watch(appDatabaseProvider)),
);

final settlementRepositoryProvider = Provider<SettlementRepository>(
  (Ref ref) => SettlementRepository(ref.watch(appDatabaseProvider)),
);

final timelineRepositoryProvider = Provider<TimelineRepository>(
  (Ref ref) => TimelineRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(shoppingRepositoryProvider),
  ),
);

final aiIngestRepositoryProvider = Provider<AiIngestRepository>(
  (Ref ref) => AiIngestRepository(
    ref.watch(shoppingRepositoryProvider),
    ref.watch(tagRepositoryProvider),
  ),
);

/// 账本列表。
class LedgerListNotifier extends AsyncNotifier<List<Ledger>> {
  @override
  Future<List<Ledger>> build() =>
      ref.watch(ledgerRepositoryProvider).listLedgers();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(ledgerRepositoryProvider).listLedgers(),
    );
  }
}

final ledgerListProvider =
    AsyncNotifierProvider<LedgerListNotifier, List<Ledger>>(
      LedgerListNotifier.new,
    );

/// 账本时间线。
class TimelineNotifier extends AsyncNotifier<List<TimelineEntry>> {
  TimelineNotifier(this.ledgerId);

  final String ledgerId;

  @override
  Future<List<TimelineEntry>> build() =>
      ref.watch(timelineRepositoryProvider).listTimeline(ledgerId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(timelineRepositoryProvider).listTimeline(ledgerId),
    );
  }
}

final timelineProvider =
    AsyncNotifierProvider.family<TimelineNotifier, List<TimelineEntry>, String>(
      TimelineNotifier.new,
    );

/// 结算板。
class SettlementBoardNotifier extends AsyncNotifier<SettlementBoard> {
  SettlementBoardNotifier(this.record);

  final (String, String) record;

  @override
  Future<SettlementBoard> build() => ref
      .watch(settlementRepositoryProvider)
      .calcBoard(ledgerId: record.$1, selfId: record.$2);
}

final settlementBoardProvider =
    AsyncNotifierProvider.family<
      SettlementBoardNotifier,
      SettlementBoard,
      (String, String)
    >(SettlementBoardNotifier.new);

/// 预算进度。
class BudgetProgressNotifier extends AsyncNotifier<BudgetProgress> {
  BudgetProgressNotifier(this.record);

  final (String, int, int) record;

  @override
  Future<BudgetProgress> build() => ref
      .watch(budgetRepositoryProvider)
      .getProgress(userId: record.$1, year: record.$2, month: record.$3);
}

final budgetProgressProvider =
    AsyncNotifierProvider.family<
      BudgetProgressNotifier,
      BudgetProgress,
      (String, int, int)
    >(BudgetProgressNotifier.new);
