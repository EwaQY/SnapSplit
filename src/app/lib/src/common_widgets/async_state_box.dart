import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 加载占位：固定高度 + 居中进度条，避免布局跳动。
class LoadingBox extends StatelessWidget {
  /// 创建加载占位。
  const LoadingBox({super.key, this.height = 120});

  /// 占位高度。
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

/// 失败态 + 重试：错误提示 + 重试键。
class ErrorRetryBox extends StatelessWidget {
  /// 创建失败态。
  const ErrorRetryBox({
    super.key,
    required this.message,
    required this.onRetry,
    this.height = 120,
  });

  /// 错误文案。
  final String message;

  /// 重试回调。
  final VoidCallback onRetry;

  /// 占位高度。
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          spacing: 8,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, style: AppTheme.rowTitle),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
