import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 卡片内分割线：1px 轨道灰，紧凑高度（内容宽，不出卡片内边距）。
class SheetDivider extends StatelessWidget {
  /// 创建分割线。
  const SheetDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.trackGray,
    );
  }
}
