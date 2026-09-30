import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'src/core/database/app_database.dart';
import 'src/core/logging/app_logger.dart';
import 'src/core/providers/app_providers.dart';
import 'src/core/theme/app_theme.dart';
import 'src/features/home/presentation/home_page.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // 日志目录准备与旧日志清理在后台做，不堵首帧。
      unawaited(_initLogging());
      final AppDatabase db = AppDatabase.appFile();
      runApp(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const SnapSplitApp(),
        ),
      );
    },
    (Object error, StackTrace stack) {
      AppLogger.err(error, stack, tag: 'zone');
    },
  );
}

/// 日志初始化（失败不影响启动）。
Future<void> _initLogging() async {
  try {
    final Directory support = await getApplicationSupportDirectory();
    await AppLogger.init(
      logDir: Directory(
        '${support.path}${Platform.pathSeparator}logs',
      ),
    );
  } catch (_) {
    // 取不到目录时退化为控制台日志。
    debugPrint('AppLogger.init skipped: no support dir');
  }
}

/// 应用根 Widget：主题 + 首屏 bootstrap。
class SnapSplitApp extends StatelessWidget {
  /// 创建应用根。
  const SnapSplitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapSplit',
      theme: AppTheme.light,
      home: const AppBootstrap(),
    );
  }
}

/// 首屏 bootstrap：`ensureSelf` 幂等建“我”，成功后进首页占位页。
///
/// loading / error 显式表达（`AsyncValue` 思想，不用空值糊弄 UI）。
class AppBootstrap extends ConsumerStatefulWidget {
  /// 创建 bootstrap。
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  late Future<User> _selfFuture;

  @override
  void initState() {
    super.initState();
    _selfFuture = ref.read(userRepositoryProvider).ensureSelf();
  }

  void _retry() {
    setState(() {
      _selfFuture = ref.read(userRepositoryProvider).ensureSelf();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User>(
      future: _selfFuture,
      builder: (BuildContext context, AsyncSnapshot<User> snapshot) {
        if (snapshot.hasError) {
          return _BootstrapErrorView(onRetry: _retry);
        }
        if (snapshot.hasData) {
          return const HomePage();
        }
        return const _BootstrapLoadingView();
      },
    );
  }
}

/// bootstrap 加载态：全屏居中进度条。
class _BootstrapLoadingView extends StatelessWidget {
  /// 创建加载态。
  const _BootstrapLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// bootstrap 失败态：展示错误 + 重试（首错直抛由 UI 重试，后端不自动重试）。
class _BootstrapErrorView extends StatelessWidget {
  /// 创建失败态。
  const _BootstrapErrorView({required this.onRetry});

  /// 重试回调。
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('本地数据初始化失败', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '请重试，仍失败可重启应用。',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      ),
    );
  }
}
