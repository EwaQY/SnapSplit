import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 首页录入口：对照 Figma（390宽）手搓。
///
/// - 左“截图录入”194×108：主蓝底 + 白字 + 相机图标，纵贯右侧两行等高
///  （`IntrinsicHeight` + stretch）；
/// - 右 156×108：上“拍照录入”156×50（浅蓝底 + 蓝字），下“手动录入”
///   156×50（灰底 + 黑字），50 + 8 + 50 = 108；
/// - 行内间距 8，宽按 flex 194:156 走，高按绝对值走；
/// - 图标取 M3 标准 `Icons.*`，不导 SVG。
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
    final TextStyle? buttonText = Theme.of(context).textTheme.titleMedium;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            flex: 194,
            child: _EntryButton(
              background: AppTheme.primaryBlue,
              foreground: AppTheme.onPrimaryBlue,
              label: '截图录入',
              icon: Icons.photo_camera_outlined,
              textStyle: buttonText,
              onTap: onScreenshotTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 156,
            child: Column(
              children: <Widget>[
                _EntryButton(
                  background: AppTheme.lightBlueBackground,
                  foreground: AppTheme.primaryBlue,
                  label: '拍照录入',
                  textStyle: buttonText,
                  height: 50,
                  onTap: onPhotoTap,
                ),
                const SizedBox(height: 8),
                _EntryButton(
                  background: AppTheme.grayButtonBackground,
                  foreground: Colors.black,
                  label: '手动录入',
                  textStyle: buttonText,
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

/// 录入单按钮：底色 + 居中内容（可选前置图标），圆角 16。
class _EntryButton extends StatelessWidget {
  /// 创建录入单按钮。
  const _EntryButton({
    required this.background,
    required this.foreground,
    required this.label,
    required this.onTap,
    this.icon,
    this.height,
    this.textStyle,
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

  /// 文字样式基底（颜色由 [foreground] 覆盖）。
  final TextStyle? textStyle;

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
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (iconData != null) ...<Widget>[
              Icon(iconData, color: foreground),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: textStyle?.copyWith(
                color: foreground,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
