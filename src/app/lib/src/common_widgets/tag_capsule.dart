import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 标签胶囊：选中蓝底白字，未选中灰底黑字；字 13/400。
///
/// 自动布局：内容包裹（Hug），圆角 9，内边距 `8/12/8/12`。
class TagCapsule extends StatelessWidget {
  /// 创建标签胶囊。
  const TagCapsule({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// 胶囊文字。
  final String label;

  /// 是否选中。
  final bool selected;

  /// 点击回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = selected
        ? AppTheme.primaryBlue
        : AppTheme.grayButtonBackground;
    final Color foreground = selected ? Colors.white : Colors.black;
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(
        Radius.circular(AppTheme.radiusSmall),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.all(
            Radius.circular(AppTheme.radiusSmall),
          ),
        ),
        child: Text(label, style: AppTheme.tagLabel(foreground)),
      ),
    );
  }
}
