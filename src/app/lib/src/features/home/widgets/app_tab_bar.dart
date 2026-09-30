import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 首页底部导航：对照 `figma/TabBar.png` 手搓，不用 M3 `NavigationBar`。
///
/// 设计（`docs/plans/frontend-home-plan.md` §1.5）：
/// - 整条 390 Fill × 64，白底 + 顶部细线（不含系统手势区，另由 `SafeArea` 垫）；
/// - 单项 100 × 38 Hug：图标 22 + 间距 2 + 字 12（行高 1.0）+ 上下 padding 各 1；
/// - 余下 (64 - 38) / 2 = 13 为上下留白；
/// - 选中整项走主蓝，未选中走灰；图标取 M3 标准 `Icons.*`，不导 SVG。
/// 本期仅首页可点，其余两项为占位：点击经 [onPlaceholderTap] 轻提示，
/// 不做页面跳转（账本详情/我的页属黑名单，下期再做）。
class AppTabBar extends StatelessWidget {
  /// 创建底部导航。
  const AppTabBar({
    super.key,
    required this.currentIndex,
    required this.onHomeTap,
    required this.onPlaceholderTap,
  });

  /// 当前选中项（本期恒为 0）。
  final int currentIndex;

  /// 点击“首页”回调用。
  final VoidCallback onHomeTap;

  /// 点击占位项（账本/我的）回调用，参数为目标 index。
  final ValueChanged<int> onPlaceholderTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.grayButtonBackground),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              _TabItem(
                label: '首页',
                icon: Icons.home_outlined,
                selected: currentIndex == 0,
                onTap: onHomeTap,
              ),
              _TabItem(
                label: '账本',
                icon: Icons.receipt_long_outlined,
                selected: currentIndex == 1,
                onTap: () => onPlaceholderTap(1),
              ),
              _TabItem(
                label: '我的',
                icon: Icons.person_outline,
                selected: currentIndex == 2,
                onTap: () => onPlaceholderTap(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底导单项：图标 + 文字竖排，内容总高 38，选中仅变蓝、不换实心图标。
class _TabItem extends StatelessWidget {
  /// 创建底导单项。
  const _TabItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  /// 文字标签。
  final String label;

  /// 图标（M3 outlined，选中未选同形、仅颜色不同）。
  final IconData icon;

  /// 是否选中。
  final bool selected;

  /// 点击回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color =
        selected ? AppTheme.primaryBlue : AppTheme.secondaryGray;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // 内容总高 38 = 1 + 22图标 + 2 + 12文字 + 1。
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                color: color,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontSize: 12,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
