import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 最近列表行：左列标题 + 副标题，右对金额。
///
/// 自动布局：水平 space-between，外边距 `10/12/10/12`，圆角 9，底 `#F2F2F7`；
/// 左列 Fill（标题 13/400 黑 + 副标题 13/400 灰，垂直 gap 4），右金额 16/700 黑。
class RecentItemCard extends StatelessWidget {
  /// 创建最近列表行。
  const RecentItemCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amountText,
  });

  /// 标题（账目名 / 购物单标题 / 转账）。
  final String title;

  /// 副标题（账本名 · 日期）。
  final String subtitle;

  /// 金额文本（已含 ¥）。
  final String amountText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: AppTheme.rowBackground,
        borderRadius: BorderRadius.all(
          Radius.circular(AppTheme.radiusSmall),
        ),
      ),
      child: Row(
        spacing: 12,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Column(
              spacing: 4,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTheme.rowTitle),
                Text(subtitle, style: AppTheme.rowSubtitle),
              ],
            ),
          ),
          Text(amountText, style: AppTheme.rowAmount),
        ],
      ),
    );
  }
}
