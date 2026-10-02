import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_split/src/features/home/widgets/wheel_sheets.dart';
/// 滚轮弹窗单测：日期滚轮确定回值。
void main() {
  testWidgets('滚轮日期确定返回当天', (WidgetTester tester) async {
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              result = await showWheelDateSheet(
                context,
                initialDate: DateTime(2026, 10, 1),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 自组三轮（年/月/日），月份为数字 M月。
    expect(find.byType(CupertinoPicker), findsNWidgets(3));
    expect(find.text('10月'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '确定'));
    await tester.pumpAndSettle();

    expect(result, DateTime(2026, 10, 1));
  });

  testWidgets('滚轮单选确定回值', (WidgetTester tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              result = await showWheelOptionSheet<String>(
                context,
                title: '账本',
                options: const <WheelOption<String>>[
                  WheelOption<String>(value: '', label: '所有账本'),
                  WheelOption<String>(value: 'l1', label: '我的账本'),
                ],
                initialValue: '',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPicker), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '确定'));
    await tester.pumpAndSettle();

    expect(result, '');
  });

  testWidgets('多选表勾选后确定回值', (WidgetTester tester) async {
    Set<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              result = await showCheckOptionSheet(
                context,
                title: '参与人',
                options: const <WheelOption<String>>[
                  WheelOption<String>(value: 'u1', label: '张三'),
                  WheelOption<String>(value: 'u2', label: '李四'),
                ],
                initial: const <String>{},
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('李四'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '确定'));
    await tester.pumpAndSettle();

    expect(result, <String>{'u2'});
  });

  testWidgets('多选表空列表占位', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () {
              showCheckOptionSheet(
                context,
                title: '参与人',
                options: const <WheelOption<String>>[],
                initial: const <String>{},
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('暂无成员'), findsOneWidget);
  });
}
