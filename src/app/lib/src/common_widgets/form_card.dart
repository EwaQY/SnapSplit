import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 表单白卡：白底圆角 12，内边距 `12/20/12/20`（横向 20 使行宽 318）。
class FormCard extends StatelessWidget {
  /// 创建表单白卡。
  const FormCard({super.key, required this.child});

  /// 卡内行列。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(
          Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: child,
    );
  }
}
