import 'package:flutter/material.dart';

import '../widgets/app_tab_bar.dart';

/// 首页空壳（验收底导专用）：页面留空，只挂自画 [AppTabBar]。
///
/// 地基验收通过前不加标题/录入口/占位卡；ephemeral 底导状态用 `setState`。
class HomePage extends StatefulWidget {
  /// 创建首页空壳。
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  void _handleHomeTap() {
    setState(() {
      _currentIndex = 0;
    });
  }

  void _handlePlaceholderTap(int index) {
    if (!mounted) {
      return;
    }
    // 切换选中态（对照 Figma 三选中态），body 仅极简占位，
    // 账本详情/我的真实页面属黑名单，下期再做。
    setState(() {
      _currentIndex = index;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('该页面下期再做，先看切换效果')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 首页 body 留空待后续挂件；账本/我的仅极简占位标题，
      // 真实页面属黑名单，下期再做。
      body: _currentIndex == 0
          ? const SizedBox.expand()
          : _PlaceholderBody(index: _currentIndex),
      bottomNavigationBar: AppTabBar(
        currentIndex: _currentIndex,
        onHomeTap: _handleHomeTap,
        onPlaceholderTap: _handlePlaceholderTap,
      ),
    );
  }
}

/// 占位 body：仅标题文字，证明 Tab 切换链路，不做真实页面。
class _PlaceholderBody extends StatelessWidget {
  /// 创建占位 body。
  const _PlaceholderBody({required this.index});

  /// Tab 序号（1 = 账本，2 = 我的）。
  final int index;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        index == 1 ? '账本（占位）' : '我的（占位）',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}
