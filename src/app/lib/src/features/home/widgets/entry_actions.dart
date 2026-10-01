import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 首页录入口：左大蓝块 + 右两小按钮；图标取 M3 标准 `Icons.*`。
///
/// 自动布局：左 `194×108` + gap 8 + 右列 `156×108（50+8+50）`；
/// 左块纵贯右两行等高（`IntrinsicHeight` + stretch），右列垂直 gap 8。
/// 本期均为占位回调（AI 链路下期），点击行为由调用方传入。
class EntryActions extends StatelessWidget {
  /// 创建录入口。
  const EntryActions({
    super.key,
    required this.onScreenshotTap,
    required this.onPhotoTap,
    required this.onManualTap,
  });

  /// 点击“截图录入”回调。
  final VoidCallback onScreenshotTap;

  /// 点击“拍照录入”回调。
  final VoidCallback onPhotoTap;

  /// 点击“手动录入”回调。
  final VoidCallback onManualTap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            flex: 194,
            child: _EntryButton(
              background: AppTheme.primaryBlue,
              foreground: AppTheme.onPrimaryBlue,
              label: '截图录入',
              icon: Icons.photo_camera_outlined,
              onTap: onScreenshotTap,
            ),
          ),
          Expanded(
            flex: 156,
            child: Column(
              spacing: 8,
              children: <Widget>[
                _EntryButton(
                  background: AppTheme.lightBlueBackground,
                  foreground: AppTheme.primaryBlue,
                  label: '拍照录入',
                  height: 50,
                  onTap: onPhotoTap,
                ),
                _EntryButton(
                  background: AppTheme.grayButtonBackground,
                  foreground: Colors.black,
                  label: '手动录入',
                  height: 50,
                  onTap: onManualTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 录入单按钮：底色 + 居中内容（可选前置图标），圆角 12，字 17/700。
class _EntryButton extends StatelessWidget {
  /// 创建录入单按钮。
  const _EntryButton({
    required this.background,
    required this.foreground,
    required this.label,
    required this.onTap,
    this.icon,
    this.height,
  });

  /// 底色（经 [AppTheme] 取用，不硬编码）。
  final Color background;

  /// 前景色（文字 + 图标）。
  final Color foreground;

  /// 按钮文字。
  final String label;

  /// 点击回调。
  final VoidCallback onTap;

  /// 前置图标（可空，大蓝块带相机图标）。
  final IconData? icon;

  /// 固定高度（可空：为空时由父级 stretch 撑满，用于左侧大蓝块）。
  final double? height;

  @override
  Widget build(BuildContext context) {
    final IconData? iconData = icon;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(
          Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(
          Radius.circular(AppTheme.radiusLarge),
        ),
        child: Row(
          spacing: 5,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (iconData != null) Icon(iconData, color: foreground),
            Text(label, style: AppTheme.entryLabel(foreground)),
          ],
        ),
      ),
    );
  }
}
