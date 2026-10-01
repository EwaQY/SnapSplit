import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// iOS 风格日历弹窗：年月头 + 中文周头 + 日格（选中红圆）+ 底部日期条 + 确定。
///
/// 只选日期不要时间；确认返回当天（年月日），取消/点遮罩返回 null。
Future<DateTime?> showCalendarDialog(
  BuildContext context, {
  DateTime? initialDate,
}) {
  final DateTime now = DateTime.now();
  final DateTime initial =
      initialDate ?? DateTime(now.year, now.month, now.day);
  return showDialog<DateTime>(
    context: context,
    builder: (BuildContext context) => _CalendarDialog(initial: initial),
  );
}

/// 日历弹窗体：白卡圆角 12，垂直 gap 12。
class _CalendarDialog extends StatefulWidget {
  /// 创建日历弹窗体。
  const _CalendarDialog({required this.initial});

  /// 初始选中日期。
  final DateTime initial;

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  static const List<String> _weekdays = <String>[
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  late DateTime _month;
  late DateTime _selected;

  /// 日视图 / 年月快选视图。
  bool _pickingYearMonth = false;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initial.year, widget.initial.month);
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final int year = _month.year;
    final int month = _month.month;
    final int leading =
        DateTime(year, month).weekday - 1;
    final int dayCount = DateTime(year, month + 1, 0).day;
    final List<Widget> cells = <Widget>[
      for (int i = 0; i < leading; i++) const SizedBox(height: 40),
      for (int day = 1; day <= dayCount; day++) _dayCell(year, month, day),
    ];
    final List<Widget> rows = <Widget>[
      for (int i = 0; i < cells.length; i += 7)
        Row(
          children: <Widget>[
            for (int j = i; j < i + 7 && j < cells.length; j++)
              Expanded(child: cells[j]),
            // 末行不足 7 格时补齐，保持各列等宽。
            for (int j = cells.length - i; j < 7 && i + 7 > cells.length; j++)
              const Expanded(child: SizedBox(height: 40)),
          ],
        ),
    ];
    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          spacing: 12,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                if (_pickingYearMonth)
                  Text('$year年', style: AppTheme.sectionTitle)
                else
                  _TitleJump(
                    label: '$year年$month月',
                    onTap: () {
                      setState(() {
                        _pickingYearMonth = true;
                      });
                    },
                  ),
                Row(
                  children: <Widget>[
                    _MonthButton(
                      icon: Icons.chevron_left_outlined,
                      onTap: () => _pickingYearMonth
                          ? _shiftYear(-1)
                          : _shiftMonth(-1),
                    ),
                    _MonthButton(
                      icon: Icons.chevron_right_outlined,
                      onTap: () => _pickingYearMonth
                          ? _shiftYear(1)
                          : _shiftMonth(1),
                    ),
                  ],
                ),
              ],
            ),
            if (_pickingYearMonth)
              ..._monthGrid(year, month)
            else ...<Widget>[
              Row(
                children: <Widget>[
                  for (final String name in _weekdays)
                    Expanded(
                      child: Center(
                        child: Text(name, style: AppTheme.rowSubtitle),
                      ),
                    ),
                ],
              ),
              ...rows,
            ],
            Center(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: const BoxDecoration(
                  color: AppTheme.trackGray,
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppTheme.radiusField),
                  ),
                ),
                child: Text(
                  '${_selected.year}年${_selected.month}月${_selected.day}日',
                  style: AppTheme.filterLabel.copyWith(
                    color: AppTheme.dangerRed,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _selected),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppTheme.radiusLarge),
                    ),
                  ),
                ),
                child: Text(
                  '确定',
                  style: AppTheme.entryLabel(Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 单日格：选中红圆白字，未选中黑字。
  Widget _dayCell(int year, int month, int day) {
    final bool selected =
        _selected.year == year &&
        _selected.month == month &&
        _selected.day == day;
    return InkWell(
      onTap: () {
        setState(() {
          _selected = DateTime(year, month, day);
        });
      },
      child: SizedBox(
        height: 40,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: selected
                ? const BoxDecoration(
                    color: AppTheme.dangerRed,
                    shape: BoxShape.circle,
                  )
                : null,
            child: Center(
              child: Text(
                '$day',
                style: selected
                    ? AppTheme.formLabel.copyWith(color: Colors.white)
                    : AppTheme.formLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 年月快选宫格：3 列 × 4 行，选中红底圆角白字，点中回日视图。
  List<Widget> _monthGrid(int year, int month) {
    return <Widget>[
      for (int row = 0; row < 4; row++)
        Row(
          children: <Widget>[
            for (int col = 0; col < 3; col++)
              Expanded(child: _monthCell(year, row * 3 + col + 1, month)),
          ],
        ),
    ];
  }

  /// 单月格。
  Widget _monthCell(int year, int value, int current) {
    final bool selected = value == current;
    return InkWell(
      onTap: () {
        _goMonth(year, value);
        setState(() {
          _pickingYearMonth = false;
        });
      },
      child: SizedBox(
        height: 48,
        child: Center(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: selected
                ? const BoxDecoration(
                    color: AppTheme.dangerRed,
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppTheme.radiusSmall),
                    ),
                  )
                : null,
            child: Text(
              '$value月',
              style: selected
                  ? AppTheme.formLabel.copyWith(color: Colors.white)
                  : AppTheme.formLabel,
            ),
          ),
        ),
      ),
    );
  }

  /// 切月份：选中日按同号跟随（月底钳位），避免看9月却确定回10月。
  void _goMonth(int year, int month) {
    final int dayCount = DateTime(year, month + 1, 0).day;
    final int day = _selected.day.clamp(1, dayCount);
    setState(() {
      _month = DateTime(year, month);
      _selected = DateTime(year, month, day);
    });
  }

  /// 月份前后翻。
  void _shiftMonth(int delta) {
    _goMonth(_month.year, _month.month + delta);
  }

  /// 年份前后翻（年月快选视图）。
  void _shiftYear(int delta) {
    _goMonth(_month.year + delta, _month.month);
  }
}

/// 标题快跳：年月文字 + 红 ›，点进年月快选视图。
class _TitleJump extends StatelessWidget {
  /// 创建标题快跳。
  const _TitleJump({required this.label, required this.onTap});

  /// 年月文字。
  final String label;

  /// 点击回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          spacing: 2,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, style: AppTheme.sectionTitle),
            const Icon(
              Icons.chevron_right_outlined,
              color: AppTheme.dangerRed,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// 翻月键：红 chevron，44 触区。
class _MonthButton extends StatelessWidget {
  /// 创建翻月键。
  const _MonthButton({required this.icon, required this.onTap});

  /// 图标。
  final IconData icon;

  /// 点击回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: AppTheme.dangerRed, size: 24),
      ),
    );
  }
}
