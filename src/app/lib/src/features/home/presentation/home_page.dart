import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/entry_media_service.dart';
import '../providers/home_providers.dart';
import '../widgets/app_tab_bar.dart';
import '../widgets/budget_card.dart';
import '../widgets/entry_actions.dart';
import '../widgets/recent_section.dart';

/// 首页空壳：页面仅挂录入行，其余待后续指令逐项加。
///
/// 拍照/截图录入走系统相机/相册（含权限申请），拿到图后提示
/// （AI 链路下期）；手动录入页下期再做；底导见 [AppTabBar]。
class HomePage extends ConsumerStatefulWidget {
  /// 创建首页空壳。
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
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
    // 切换选中态，body 仅极简占位；真实页面下期再做。
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

  /// 拍照/截图录入：申请权限 + 系统选图，结果弹提示（AI 链路下期）。
  ///
  /// 系统相册/相机里按返回 = 取消，静默回首页，不打扰。
  Future<void> _handleMediaTap(EntryMediaSource source) async {
    final EntryMediaResult result = await ref
        .read(entryMediaServiceProvider)
        .pick(source);
    if (!mounted) {
      return;
    }
    if (result.file == null) {
      // 用户主动取消（未选择图片）：静默回；权限被拒才提示。
      if (result.notice != null && result.notice != '未选择图片') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.notice!)));
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.notice ?? '已选择图片'}：${result.file!.name}（AI 识别下期再接）',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 首页 body：标题 + 录入行 + 预算卡 + 最近卡，垂直自动布局；
      // 标题与录入行 gap 12（口径暂定，见样式文档 §2），卡间 gap 16；
      // 账本/我的 Tab 保持极简占位标题，真实页面属黑名单，下期再做。
      body: _currentIndex == 0
          ? SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    spacing: 16,
                    children: <Widget>[
                      Column(
                        spacing: 12,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('首页', style: AppTheme.pageTitle),
                          ),
                          EntryActions(
                            onScreenshotTap: () => _handleMediaTap(
                              EntryMediaSource.gallery,
                            ),
                            onPhotoTap: () => _handleMediaTap(
                              EntryMediaSource.camera,
                            ),
                            onManualTap: _handleEntryPlaceholder,
                          ),
                        ],
                      ),
                      const BudgetCard(),
                      const RecentSection(),
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
