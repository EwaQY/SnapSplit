import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_split/src/core/database/app_database.dart';
import 'package:snap_split/src/core/providers/app_providers.dart';
import 'package:snap_split/src/features/home/presentation/filter_sheet.dart';
import 'package:snap_split/src/features/home/presentation/home_page.dart';

/// 打开筛选弹窗的测试壳：内存库 + 入口按钮。
Future<void> pumpSheetOpener(WidgetTester tester) async {
  final AppDatabase db = AppDatabase.memory();
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () => showHomeFilterSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// 筛选弹窗 widget 单测：能打开、关键行齐、确定落值关闭。
void main() {
  testWidgets('筛选弹窗打开并确定关闭', (WidgetTester tester) async {
    await pumpSheetOpener(tester);

    expect(find.text('账目筛选'), findsOneWidget);
    expect(find.text('账本'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('支付人'), findsOneWidget);
    expect(find.text('参与人'), findsOneWidget);
    expect(find.text('金额'), findsOneWidget);
    expect(find.text('日期'), findsOneWidget);
    expect(find.text('账目标题'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('账目筛选'), findsNothing);
  });

  /// 回归：嵌套纵列默认 Hug 会被父列居中，标签块必须 stretch 铺满左对齐。
  testWidgets('标签块左对齐', (WidgetTester tester) async {
    await pumpSheetOpener(tester);

    final Rect ledger = tester.getRect(find.text('账本'));
    final Rect tag = tester.getRect(find.text('标签'));
    expect(tag.left, ledger.left);
  });

  /// 真链路：首页筛选键打开弹窗，再进支付人滚轮并确定返回。
  testWidgets('首页筛选键进滚轮', (WidgetTester tester) async {
    final AppDatabase db = AppDatabase.memory();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('筛选'));
    await tester.pumpAndSettle();
    expect(find.text('账目筛选'), findsOneWidget);

    await tester.tap(find.text('支付人'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '确定'));
    await tester.pumpAndSettle();
    expect(find.text('账目筛选'), findsOneWidget);
  });
}
