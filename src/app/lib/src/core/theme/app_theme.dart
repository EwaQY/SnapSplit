import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 首页主题：设计口径见 `docs/design/home-styles.md`，色值与字号只落在此文件。
///
/// 约定：业务 Widget 一律经 [AppTheme] 取色与取字，禁止硬编码；
/// 全部自动布局（Row/Column + spacing + Padding + Expanded/Hug），禁止 Stack 定位；
/// 全站唯一字体 Noto Sans SC（`google_fonts`），行高一律 1.0。
class AppTheme {
  AppTheme._();

  /// 主蓝（大蓝按钮 / 选中态 / 进度条 <50% / 拍照录入字 / 筛选字 / 胶囊选中底）。
  static const Color primaryBlue = Color(0xFF007AFF);

  /// 主蓝上的文字（白）。
  static const Color onPrimaryBlue = Colors.white;

  /// 浅蓝底（拍照录入区 / 筛选按键底）：主蓝 12% 透明度写法，不写死 hex。
  static Color get lightBlueBackground =>
      primaryBlue.withValues(alpha: 0.12);

  /// 灰按钮底（手动录入区底）#E9E9EE。
  static const Color grayButtonBackground = Color(0xFFE9E9EE);

  /// 账单行底 / 弹窗底 #F2F2F7。
  static const Color rowBackground = Color(0xFFF2F2F7);

  /// 进度条轨道 / 输入框底 / 单区间圆角底 #E5E5EA。
  static const Color trackGray = Color(0xFFE5E5EA);

  /// 页面底灰（新口径未给定，暂沿用旧值）。
  static const Color pageBackground = Color(0xFFF4F5F7);

  /// 次级文字灰 #8E8E93（使用占比 / 账单副标题 / 表单右值）。
  static const Color secondaryGray = Color(0xFF8E8E93);

  /// 筛选摘要灰 #808080（所有账本 / 近7天 / 没有更多了）。
  static const Color filterGray = Color(0xFF808080);

  /// 警告橙（预算 50–90%）。
  static const Color warnOrange = Color(0xFFFF8D28);

  /// 危险红（预算 ≥90% / 超支）。
  static const Color dangerRed = Color(0xFFFF383C);

  /// 统一圆角（卡片 / 大按钮）。
  static const double radiusLarge = 12;

  /// 小圆角（筛选按键 / 账单行 / 胶囊）。
  static const double radiusSmall = 9;

  /// 弹窗顶圆角。
  static const double radiusSheet = 14;

  /// 进度条圆角。
  static const double radiusTrack = 3;

  /// 输入框圆角（金额 / 日期单区间）。
  static const double radiusField = 8;

  /// Noto Sans SC 基底（行高 1.0 对应设计 line-height 100%）。
  static TextStyle _base({
    required double size,
    required FontWeight weight,
    required Color color,
  }) {
    return GoogleFonts.notoSansSc(
      fontSize: size,
      fontWeight: weight,
      height: 1.0,
      letterSpacing: 0,
      color: color,
    );
  }

  /// 首页标题「首页」34/700 黑。
  static TextStyle get pageTitle =>
      _base(size: 34, weight: FontWeight.w700, color: Colors.black);

  /// 弹窗标题「账目筛选」24/700 黑。
  static TextStyle get sheetTitle =>
      _base(size: 24, weight: FontWeight.w700, color: Colors.black);

  /// 预算金额 22/900 黑。
  static TextStyle get budgetAmount =>
      _base(size: 22, weight: FontWeight.w900, color: Colors.black);

  /// 区块标题 17/700 黑（预算标题 / 最近标题）。
  static TextStyle get sectionTitle =>
      _base(size: 17, weight: FontWeight.w700, color: Colors.black);

  /// 表单标签 17/400 黑（账本 / 标签 / 支付人 / 金额 / 日期 / 账目标题）。
  static TextStyle get formLabel =>
      _base(size: 17, weight: FontWeight.w400, color: Colors.black);

  /// 录入按钮字 17/700（颜色调用方按底色传）。
  static TextStyle entryLabel(Color color) =>
      _base(size: 17, weight: FontWeight.w700, color: color);

  /// 账单金额 16/700 黑。
  static TextStyle get rowAmount =>
      _base(size: 16, weight: FontWeight.w700, color: Colors.black);

  /// 筛选摘要 14/400 灰（所有账本 / 近7天）。
  static TextStyle get filterSummary =>
      _base(size: 14, weight: FontWeight.w400, color: filterGray);

  /// 账单标题 13/400 黑。
  static TextStyle get rowTitle =>
      _base(size: 13, weight: FontWeight.w400, color: Colors.black);

  /// 账单副标题 13/400 次灰。
  static TextStyle get rowSubtitle =>
      _base(size: 13, weight: FontWeight.w400, color: secondaryGray);

  /// 筛选键字 13/700 主蓝。
  static TextStyle get filterLabel =>
      _base(size: 13, weight: FontWeight.w700, color: primaryBlue);

  /// 胶囊字 13/400（颜色随选中态传）。
  static TextStyle tagLabel(Color color) =>
      _base(size: 13, weight: FontWeight.w400, color: color);

  /// 到底占位 12/400 灰。
  static TextStyle get moreLabel =>
      _base(size: 12, weight: FontWeight.w400, color: filterGray);

  /// 表单右值 17/400 次灰（我的账本 / 我 / 参与人）。
  static TextStyle get formValue =>
      _base(size: 17, weight: FontWeight.w400, color: secondaryGray);

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
      textTheme: GoogleFonts.notoSansScTextTheme(),
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
