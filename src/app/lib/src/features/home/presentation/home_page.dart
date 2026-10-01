import 'package:flutter/material.dart';

import '../widgets/app_tab_bar.dart';
import '../widgets/budget_card.dart';
import '../widgets/entry_actions.dart';

/// 首页空壳：页面仅挂录入行，其余待后续指令逐项加。
///
/// 录入口点击本期均为占位提示（AI 链路下期）；底导见 [AppTabBar]。
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

  void _handleEntryPlaceholder() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('录入页下期再做，本期先看样式')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 首页 body 挂录入行（页面水平边距 16）；
      // 账本/我的 Tab 保持极简占位标题，真实页面属黑名单，下期再做。
      body: _currentIndex == 0
          ? SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    children: <Widget>[
                      EntryActions(
                        onScreenshotTap: _handleEntryPlaceholder,
                        onPhotoTap: _handleEntryPlaceholder,
                        onManualTap: _handleEntryPlaceholder,
                      ),
                      const SizedBox(height: 16),
                      const BudgetCard(),
                    ],
                  ),
                ),
              ),
            )
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
