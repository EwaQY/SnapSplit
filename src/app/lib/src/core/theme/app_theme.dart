import 'package:flutter/material.dart';

/// 首页主题：亮主题先行，对照 `figma/SnapSplit-首页.png` 取色。
///
/// 约定：色值只落在此文件，业务 Widget 一律经 [AppTheme] 取用，
/// 禁止在业务 Widget 里硬编码色值与文本样式。
class AppTheme {
  AppTheme._();

  /// 主蓝（大蓝按钮 / 选中态 / 进度条 <50%）。
  static const Color primaryBlue = Color(0xFF1E7CFF);

  /// 主蓝上的文字（白）。
  static const Color onPrimaryBlue = Colors.white;

  /// 浅蓝底（“拍照录入”按钮底）。
  static const Color lightBlueBackground = Color(0xFFE2EFFF);

  /// 灰按钮底（“手动录入”按钮底 / 最近列表行底）。
  static const Color grayButtonBackground = Color(0xFFF0F1F5);

  /// 页面底灰。
  static const Color pageBackground = Color(0xFFF4F5F7);

  /// 未选中 Tab / 次级文字灰。
  static const Color secondaryGray = Color(0xFF9AA0AA);

  /// 警告橙（预算 50–90%）。
  static const Color warnOrange = Color(0xFFF59E0B);

  /// 危险红（预算 ≥90% / 超支）。
  static const Color dangerRed = Color(0xFFEF4444);

  /// 统一圆角（卡片 / 按钮 / 列表行）。
  static const double radiusLarge = 16;

  /// 亮主题（M3，`useMaterial3` 显式开启）。
  static ThemeData get light {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: pageBackground,
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLarge)),
        ),
      ),
    );
  }
}
