import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'bill_row.dart';

/// 账单行数据：由调用方（如 home）从业务条目转换传入。
typedef BillRowData = ({String title, String subtitle, String amountText});

/// 账单列表：懒加载 + 空态 + 到底标记，行间 gap 8。
class BillList extends StatelessWidget {
  /// 创建账单列表。
  const BillList({super.key, required this.rows});

  /// 行数据（调用方传入，已排好序）。
  final List<BillRowData> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('暂无最近记录', style: AppTheme.filterSummary),
        ),
      );
    }
    return Column(
      spacing: 8,
      children: <Widget>[
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          itemBuilder: (BuildContext context, int index) {
            final BillRowData row = rows[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == rows.length - 1 ? 0 : 8,
              ),
              child: BillRow(
                title: row.title,
                subtitle: row.subtitle,
                amountText: row.amountText,
              ),
            );
          },
        ),
        Center(
          child: Text('没有更多了', style: AppTheme.moreLabel),
        ),
      ],
    );
  }
}
