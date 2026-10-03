import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 搜索行：左标签 + 搜索框（高 26，圆角 8，底 `#E5E5EA`）。
class SearchField extends StatelessWidget {
  /// 创建搜索行。
  const SearchField({super.key, required this.controller});

  /// 输入控制器。
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      children: <Widget>[
        Text('账目标题', style: AppTheme.formLabel),
        Expanded(
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              color: AppTheme.trackGray,
              borderRadius: BorderRadius.all(
                Radius.circular(AppTheme.radiusField),
              ),
            ),
            child: Row(
              spacing: 4,
              children: <Widget>[
                const Icon(
                  Icons.search_outlined,
                  size: 16,
                  color: AppTheme.secondaryGray,
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: AppTheme.rowTitle,
                    textAlignVertical: TextAlignVertical.center,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
