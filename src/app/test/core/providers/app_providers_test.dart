import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/database/app_database.dart';
import 'package:snap_split/src/core/providers/app_providers.dart';
import 'package:snap_split/src/features/timeline/data/timeline_entries.dart';

/// T5-2：providers 可接线（覆盖注入 + 未覆盖抛错）。
void main() {
  test('覆盖 memory 库后 providers 可读', () async {
    final AppDatabase db = AppDatabase.memory();
    addTearDown(db.close);
    final ProviderContainer container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final List<Ledger> ledgers = await container.read(
      ledgerListProvider.future,
    );
    expect(ledgers, isEmpty);

    final List<TimelineEntry> timeline = await container.read(
      timelineProvider('no-such-ledger').future,
    );
    expect(timeline, isEmpty);
  });

  test('未覆盖读库抛 UnimplementedError', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    // 未覆盖的库抛 UnimplementedError（被 Riverpod 包一层 Provider 错误）。
    expect(
      () => container.read(appDatabaseProvider),
      throwsA(
        predicate(
          (Object e) => e.toString().contains('UnimplementedError'),
        ),
      ),
    );
  });
}
