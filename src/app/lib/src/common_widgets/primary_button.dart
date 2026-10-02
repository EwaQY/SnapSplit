import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 确定键：全宽高 50，主蓝圆角 12，白字 17/700。
class PrimaryButton extends StatelessWidget {
  /// 创建确定键。
  const PrimaryButton({super.key, required this.label, required this.onTap});

  /// 按钮文字。
  final String label;

  /// 点击回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(AppTheme.radiusLarge),
            ),
          ),
        ),
        child: Text(label, style: AppTheme.entryLabel(Colors.white)),
      ),
    );
  }
}
