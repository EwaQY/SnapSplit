import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 选择行：左标签 + 右值 + ^v，整行可点。
class SelectRow extends StatelessWidget {
  /// 创建选择行。
  const SelectRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  /// 左标签。
  final String label;

  /// 右值摘要。
  final String value;

  /// 点击回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: AppTheme.formLabel),
          Row(
            spacing: 4,
            children: <Widget>[
              Text(value, style: AppTheme.formValue),
              const Icon(
                Icons.unfold_more_outlined,
                size: 16,
                color: AppTheme.secondaryGray,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
