import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 滚轮选项（单选/多选共用）。
class WheelOption<T> {
  /// 创建滚轮选项。
  const WheelOption({required this.value, required this.label});

  /// 选项值。
  final T value;

  /// 展示文字。
  final String label;
}

/// iOS 滚轮单选弹窗；取消返回 null。
Future<T?> showWheelOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<WheelOption<T>> options,
  T? initialValue,
}) {
  int initialIndex = 0;
  for (int i = 0; i < options.length; i++) {
    if (options[i].value == initialValue) {
      initialIndex = i;
    }
  }
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (BuildContext context) => _WheelPopup<T>(
      title: title,
      options: options,
      initialIndex: initialIndex,
    ),
  );
}

/// iOS 滚轮日期弹窗（年月日三轮，只取年月日）；取消返回 null。
Future<DateTime?> showWheelDateSheet(
  BuildContext context, {
  DateTime? initialDate,
}) {
  final DateTime now = DateTime.now();
  final DateTime initial =
      initialDate ?? DateTime(now.year, now.month, now.day);
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (BuildContext context) => _WheelDatePopup(initial: initial),
  );
}

/// iOS 多选表（check 行 + 蓝确定键）；取消返回 null。
Future<Set<String>?> showCheckOptionSheet(
  BuildContext context, {
  required String title,
  required List<WheelOption<String>> options,
  required Set<String> initial,
}) {
  return showCupertinoModalPopup<Set<String>>(
    context: context,
    builder: (BuildContext context) => _CheckPopup(
      title: title,
      options: options,
      initial: initial,
    ),
  );
}

/// 滚轮弹窗壳：白底顶圆角 14 + 工具条 + 内容。
class _WheelShell extends StatelessWidget {
  /// 创建弹窗壳。
  const _WheelShell({
    required this.title,
    required this.onCancel,
    required this.onConfirm,
    required this.child,
  });

  /// 标题。
  final String title;

  /// 取消回调。
  final VoidCallback onCancel;

  /// 确定回调。
  final VoidCallback onConfirm;

  /// 内容（滚轮/列表）。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusSheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  TextButton(
                    onPressed: onCancel,
                    child: Text(
                      '取消',
                      style: AppTheme.formLabel.copyWith(
                        color: AppTheme.secondaryGray,
                      ),
                    ),
                  ),
                  Text(
                    title,
                    style: AppTheme.sectionTitle,
                  ),
                  TextButton(
                    onPressed: onConfirm,
                    child: Text(
                      '确定',
                      style: AppTheme.formLabel.copyWith(
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// 滚轮单选体。
class _WheelPopup<T> extends StatefulWidget {
  /// 创建滚轮单选体。
  const _WheelPopup({
    required this.title,
    required this.options,
    required this.initialIndex,
  });

  /// 标题。
  final String title;

  /// 选项。
  final List<WheelOption<T>> options;

  /// 初始下标。
  final int initialIndex;

  @override
  State<_WheelPopup<T>> createState() => _WheelPopupState<T>();
}

class _WheelPopupState<T> extends State<_WheelPopup<T>> {
  late int _index;
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = FixedExtentScrollController(initialItem: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _WheelShell(
      title: widget.title,
      onCancel: () => Navigator.pop(context),
      onConfirm: () => Navigator.pop(context, widget.options[_index].value),
      child: SizedBox(
        height: 216,
        child: CupertinoPicker(
          magnification: 1.1,
          itemExtent: 36,
          scrollController: _controller,
          onSelectedItemChanged: (int index) {
            setState(() {
              _index = index;
            });
          },
          children: <Widget>[
            for (final WheelOption<T> option in widget.options)
              Center(
                child: Text(option.label, style: AppTheme.formLabel),
              ),
          ],
        ),
      ),
    );
  }
}

/// 滚轮日期体：年/月/日三轮，月份数字 `M月`（原生中文 locale 会渲染成十月，不可配，只能手组）。
class _WheelDatePopup extends StatefulWidget {
  /// 创建滚轮日期体。
  const _WheelDatePopup({required this.initial});

  /// 初始日期。
  final DateTime initial;

  @override
  State<_WheelDatePopup> createState() => _WheelDatePopupState();
}

class _WheelDatePopupState extends State<_WheelDatePopup> {
  static const int _minYear = 2000;
  static const int _maxYear = 2031;

  late int _year;
  late int _month;
  late int _day;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year.clamp(_minYear, _maxYear);
    _month = widget.initial.month.clamp(1, 12);
    _day = widget.initial.day.clamp(1, _dayCount(_year, _month));
    _yearController = FixedExtentScrollController(
      initialItem: _year - _minYear,
    );
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
    _dayController = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _WheelShell(
      title: '选择日期',
      onCancel: () => Navigator.pop(context),
      onConfirm: () => Navigator.pop(
        context,
        DateTime(_year, _month, _day),
      ),
      child: SizedBox(
        height: 216,
        child: Row(
          children: <Widget>[
            Expanded(
              child: CupertinoPicker(
                magnification: 1.1,
                itemExtent: 36,
                scrollController: _yearController,
                onSelectedItemChanged: (int index) {
                  _onYearMonthChanged(
                    _minYear + index,
                    _month,
                  );
                },
                children: <Widget>[
                  for (int y = _minYear; y <= _maxYear; y++)
                    Center(
                      child: Text('$y年', style: AppTheme.formLabel),
                    ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                magnification: 1.1,
                itemExtent: 36,
                scrollController: _monthController,
                onSelectedItemChanged: (int index) {
                  _onYearMonthChanged(_year, index + 1);
                },
                children: <Widget>[
                  for (int m = 1; m <= 12; m++)
                    Center(
                      child: Text('$m月', style: AppTheme.formLabel),
                    ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                magnification: 1.1,
                itemExtent: 36,
                scrollController: _dayController,
                onSelectedItemChanged: (int index) {
                  setState(() {
                    _day = index + 1;
                  });
                },
                children: <Widget>[
                  for (int d = 1; d <= _dayCount(_year, _month); d++)
                    Center(
                      child: Text('$d日', style: AppTheme.formLabel),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 年/月变化：天数按月重算并钳位。
  void _onYearMonthChanged(int year, int month) {
    setState(() {
      _year = year;
      _month = month;
      _day = _day.clamp(1, _dayCount(year, month));
    });
    _dayController.jumpToItem(_day - 1);
  }

  /// 当月天数。
  int _dayCount(int year, int month) => DateTime(year, month + 1, 0).day;
}

/// iOS 多选体：check 行 + 蓝确定键。
class _CheckPopup extends StatefulWidget {
  /// 创建多选体。
  const _CheckPopup({
    required this.title,
    required this.options,
    required this.initial,
  });

  /// 标题。
  final String title;

  /// 选项。
  final List<WheelOption<String>> options;

  /// 初始已选。
  final Set<String> initial;

  @override
  State<_CheckPopup> createState() => _CheckPopupState();
}

class _CheckPopupState extends State<_CheckPopup> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.of(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    return _WheelShell(
      title: widget.title,
      onCancel: () => Navigator.pop(context),
      onConfirm: () => Navigator.pop(context, _selected),
      child: widget.options.isEmpty
          ? SizedBox(
              height: 216,
              child: Center(
                child: Text('暂无成员', style: AppTheme.rowSubtitle),
              ),
            )
          : Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final WheelOption<String> option in widget.options)
                      _CheckRow(
                        label: option.label,
                        selected: _selected.contains(option.value),
                        onTap: () {
                          setState(() {
                            if (_selected.contains(option.value)) {
                              _selected.remove(option.value);
                            } else {
                              _selected.add(option.value);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// iOS check 行：左文 + 右蓝勾。
class _CheckRow extends StatelessWidget {
  /// 创建 check 行。
  const _CheckRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// 选项文字。
  final String label;

  /// 是否选中。
  final bool selected;

  /// 点击回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Cupertino 弹窗路由下无 Material，InkWell 会断言失败，用手势探测。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label, style: AppTheme.formLabel),
            if (selected)
              const Icon(
                Icons.check_outlined,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
