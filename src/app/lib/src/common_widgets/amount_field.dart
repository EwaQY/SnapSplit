import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 金额行：左标签 + 右区间输入（66×26 灰药丸）+ 元。
class AmountRow extends StatelessWidget {
  /// 创建金额行。
  const AmountRow({
    super.key,
    required this.minController,
    required this.maxController,
  });

  /// 最小金额（元）控制器。
  final TextEditingController minController;

  /// 最大金额（元）控制器。
  final TextEditingController maxController;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('金额', style: AppTheme.formLabel),
        Row(
          spacing: 6,
          children: <Widget>[
            AmountField(controller: minController),
            Text('~', style: AppTheme.rowSubtitle),
            AmountField(controller: maxController),
            Text('元', style: AppTheme.rowSubtitle),
          ],
        ),
      ],
    );
  }
}

/// 金额输入框：66×26，圆角 8，底 `#E5E5EA`，数字键盘。
class AmountField extends StatelessWidget {
  /// 创建金额输入框。
  const AmountField({super.key, required this.controller});

  /// 输入控制器。
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 26,
      decoration: const BoxDecoration(
        color: AppTheme.trackGray,
        borderRadius: BorderRadius.all(
          Radius.circular(AppTheme.radiusField),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        // 撑满 66×26 盒子再双居中：isCollapsed 只收内容高，换 expands 才稳。
        expands: true,
        maxLines: null,
        minLines: null,
        style: AppTheme.rowTitle,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}
