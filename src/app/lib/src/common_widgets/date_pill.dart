import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 日期行：左标签 + 日历图标 + 区间药丸（未选为空药丸，已选 MM-dd）。
class DateRow extends StatelessWidget {
  /// 创建日期行。
  const DateRow({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onPickStart,
    required this.onPickEnd,
  });

  /// 开始日期。
  final DateTime? startDate;

  /// 结束日期。
  final DateTime? endDate;

  /// 选开始日期回调。
  final VoidCallback onPickStart;

  /// 选结束日期回调。
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('日期', style: AppTheme.formLabel),
        Row(
          spacing: 6,
          children: <Widget>[
            const Icon(
              Icons.date_range_outlined,
              size: 20,
              color: AppTheme.secondaryGray,
            ),
            DatePill(date: startDate, onTap: onPickStart),
            Text('~', style: AppTheme.rowSubtitle),
            DatePill(date: endDate, onTap: onPickEnd),
          ],
        ),
      ],
    );
  }
}

/// 日期药丸：66×26，圆角 8，底 `#E5E5EA`；已选显示 MM-dd。
class DatePill extends StatelessWidget {
  /// 创建日期药丸。
  const DatePill({super.key, required this.date, required this.onTap});

  /// 已选日期（null = 未选）。
  final DateTime? date;

  /// 点击回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DateTime? date = this.date;
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(
        Radius.circular(AppTheme.radiusField),
      ),
      child: Container(
        width: 66,
        height: 26,
        decoration: const BoxDecoration(
          color: AppTheme.trackGray,
          borderRadius: BorderRadius.all(
            Radius.circular(AppTheme.radiusField),
          ),
        ),
        child: Center(
          child: Text(
            date == null
                ? ''
                : '${date.month.toString().padLeft(2, '0')}-'
                      '${date.day.toString().padLeft(2, '0')}',
            style: AppTheme.rowTitle,
          ),
        ),
      ),
    );
  }
}
