import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';

/// 应用日志：操作审计的唯一出口（文件落盘，不走网络）。
///
/// - 写操作经 [audit] 记录（actor/action/实体/行 id/耗时/结果），
///   成功记 info，失败记 error 后原样 rethrow，绝不吞异常；
/// - 单文件 `app.log`，行首 `[ISO8601]` 时间戳供清理；
/// - 初始化时清理 5 天前行 + 5MB 上限（见 [cleanupLogFile]）；
/// - 单测用 [testMode] 切静默/内存输出，不污染输出不碰文件。
class AppLogger {
  AppLogger._();

  static const int retainDays = 5;
  static const int maxBytes = 5 * 1024 * 1024;

  static Logger _log = Logger(
    printer: SimplePrinter(),
    filter: _AllowAllFilter(),
  );
  static IOSink? _sink;

  /// 生产初始化：打开日志文件、清理旧行。调用方在后台执行，不堵 UI。
  static Future<void> init({required Directory logDir}) async {
    final File file = File(
      '${logDir.path}${Platform.pathSeparator}app.log',
    );
    await file.parent.create(recursive: true);
    await cleanupLogFile(file);
    _sink = file.openWrite(mode: FileMode.append);
    _log = Logger(
      printer: SimplePrinter(),
      filter: _AllowAllFilter(),
      output: MultiOutput(<LogOutput>[
        ConsoleOutput(),
        _SinkOutput(() => _sink),
      ]),
    );
  }

  /// 单测模式：静默，可选注入内存输出断言。
  static void testMode({List<String>? memory}) {
    unawaited(_sink?.flush().catchError((Object _) {}));
    _sink = null;
    _log = Logger(
      printer: SimplePrinter(),
      filter: _TestFilter(memory == null),
      output: memory == null ? ConsoleOutput() : _MemoryOutput(memory),
    );
  }

  /// 审计写操作：计时 + 成功/失败日志，异常原样抛出。
  static Future<T> audit<T>({
    String actor = 'me',
    required String action,
    String entity = '',
    String? id,
    required Future<T> Function() run,
  }) async {
    final Stopwatch sw = Stopwatch()..start();
    try {
      final T result = await run();
      _log.i(
        '[${DateTime.now().toIso8601String()}] op=$action '
        'actor=$actor entity=$entity id=${id ?? '-'} '
        'elapsed=${sw.elapsedMilliseconds}ms ok=true',
      );
      return result;
    } catch (e, s) {
      _log.e(
        '[${DateTime.now().toIso8601String()}] op=$action '
        'actor=$actor entity=$entity id=${id ?? '-'} '
        'elapsed=${sw.elapsedMilliseconds}ms ok=false error=$e',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  /// 非审计普通日志（调试向）。
  static void info(String message) => _log.i(_stamped(message));

  /// 异常统一口（全局捕获调用）。
  static void err(Object error, StackTrace stack, {String tag = ''}) =>
      _log.e(
        '${_stamped('fatal tag=$tag')} $error',
        error: error,
        stackTrace: stack,
      );

  static String _stamped(String message) =>
      '[${DateTime.now().toIso8601String()}] $message';

  static Future<void> close() async {
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {
      // 日志关闭失败不影响业务。
    } finally {
      _sink = null;
    }
  }

  /// 清理日志文件：删 5 天前行，总量超 5MB 截尾。纯文件操作，可单测。
  static Future<void> cleanupLogFile(File file) async {
    if (!file.existsSync()) {
      return;
    }
    final DateTime cutoff = DateTime.now().subtract(
      const Duration(days: retainDays),
    );
    final List<String> kept = <String>[];
    for (final String line in await file.readAsLines()) {
      final DateTime? time = parseLogTime(line);
      if (time == null || !time.isBefore(cutoff)) {
        kept.add(line);
      }
    }
    String content = kept.join('\n');
    if (kept.isNotEmpty) {
      content += '\n';
    }
    final List<int> bytes = content.codeUnits;
    if (bytes.length > maxBytes) {
      final String tail = content.substring(content.length - maxBytes);
      final int newline = tail.indexOf('\n');
      await file.writeAsString(
        newline < 0 ? tail : tail.substring(newline + 1),
      );
      return;
    }
    await file.writeAsString(content);
  }

  /// 解析行首 `[ISO8601]`，无时间戳返回 null（保留该行）。
  static DateTime? parseLogTime(String line) {
    if (!line.startsWith('[')) {
      return null;
    }
    final int end = line.indexOf(']');
    if (end <= 1) {
      return null;
    }
    return DateTime.tryParse(line.substring(1, end));
  }
}

/// 文件输出（logger 同步接口，IOSink 缓冲，异常自吞）。
class _SinkOutput extends LogOutput {
  _SinkOutput(this._sinkOf);

  final IOSink? Function() _sinkOf;

  @override
  void output(OutputEvent event) {
    try {
      final IOSink? sink = _sinkOf();
      for (final String line in event.lines) {
        sink?.writeln(line);
      }
    } catch (_) {
      // 日志落盘失败不影响业务。
    }
  }
}

/// 内存输出（测试断言用）。
class _MemoryOutput extends LogOutput {
  _MemoryOutput(this.lines);

  final List<String> lines;

  @override
  void output(OutputEvent event) => lines.addAll(event.lines);
}

/// 全放行过滤器（测试过滤器见下）。
class _AllowAllFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => true;
}

/// 测试过滤器：静默或放行。
class _TestFilter extends LogFilter {
  _TestFilter(this.silent);

  final bool silent;

  @override
  bool shouldLog(LogEvent event) => !silent;
}
