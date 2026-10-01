import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 最近列表行：左列标题 + 副标题，右对金额。
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
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.grayButtonBackground,
        borderRadius: BorderRadius.all(
          Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryGray,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amountText,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
