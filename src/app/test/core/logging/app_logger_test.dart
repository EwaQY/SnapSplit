import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/database/app_database.dart';
import 'package:snap_split/src/core/errors/app_exception.dart';
import 'package:snap_split/src/core/logging/app_logger.dart';
import 'package:snap_split/src/features/profile/data/user_repository.dart';

/// T8：日志审计（落盘/清理/埋点/全局口）。
void main() {
  group('T8-1 时间戳解析与保留过滤', () {
    test('parseLogTime 只认行首 ISO 时间', () {
      expect(
        AppLogger.parseLogTime('[2026-09-26T10:00:00.000] op=x'),
        DateTime(2026, 9, 26, 10, 0, 0),
      );
      expect(AppLogger.parseLogTime('无时间戳行'), isNull);
      expect(AppLogger.parseLogTime('[not-a-date] op=x'), isNull);
    });

    test('cleanupLogFile 删 5 天前行并截超量', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('logtest');
      addTearDown(() => tmp.delete(recursive: true));
      final File file = File('${tmp.path}/app.log');
      final DateTime now = DateTime.now();
      String stamp(DateTime t) => '[${t.toIso8601String()}]';
      final String old = '${stamp(now.subtract(const Duration(days: 6)))} op=old';
      final String fresh =
          '${stamp(now.subtract(const Duration(days: 1)))} op=new';
      await file.writeAsString('$old\n$fresh\n无戳行\n');
      await AppLogger.cleanupLogFile(file);
      final String kept = await file.readAsString();
      expect(kept, isNot(contains('op=old')));
      expect(kept, contains('op=new'));
      expect(kept, contains('无戳行'));
    });
  });

  group('T8-2 Repository 埋点', () {
    test('写操作记 op 行，失败记 error 行且原样抛', () async {
      final List<String> memory = <String>[];
      AppLogger.testMode(memory: memory);
      final AppDatabase db = AppDatabase.memory();
      addTearDown(db.close);
      final UserRepository users = UserRepository(db);

      final User self = await users.ensureSelf();
      expect(
        memory.any(
          (String line) =>
              line.contains('op=user.ensureSelf') && line.contains('ok=true'),
        ),
        isTrue,
      );

      await expectLater(
        users.updateProfile(self.id, nickname: '  '),
        throwsA(isA<ValidationException>()),
      );
      expect(
        memory.any(
          (String line) =>
              line.contains('op=user.updateProfile') &&
              line.contains('ok=false'),
        ),
        isTrue,
      );
      AppLogger.testMode(memory: <String>[]);
    });
  });

  group('T8-3 文件落盘', () {
    test('init 写文件且含审计行', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('logfile');
      addTearDown(() async {
        await AppLogger.close();
        AppLogger.testMode(memory: <String>[]);
        await tmp.delete(recursive: true);
      });
      await AppLogger.init(logDir: tmp);
      final AppDatabase db = AppDatabase.memory();
      addTearDown(db.close);
      await UserRepository(db).ensureSelf();
      await AppLogger.close();
      final File file = File('${tmp.path}/app.log');
      expect(file.existsSync(), isTrue);
      expect(
        (await file.readAsString()).contains('op=user.ensureSelf'),
        isTrue,
      );
      AppLogger.testMode(memory: <String>[]);
    });
  });

  group('T8-4 测试日志文件', () {
    test('cleanupTestLogs 只删 5 天前文件', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('testlogs');
      addTearDown(() => tmp.delete(recursive: true));
      final File old = File('${tmp.path}/old_test.log')..writeAsStringSync('x');
      final File fresh = File('${tmp.path}/new_test.log')
        ..writeAsStringSync('y');
      old.setLastModifiedSync(
        DateTime.now().subtract(const Duration(days: 6)),
      );
      AppLogger.cleanupTestLogs(tmp);
      expect(old.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue);
    });

    test('testMode 文件追加保留历史行', () async {
      final Directory backup = Directory.current;
      final Directory tmp = await Directory.systemTemp.createTemp('testmode');
      addTearDown(() async {
        await AppLogger.close();
        AppLogger.testMode(memory: <String>[]);
        await tmp.delete(recursive: true);
      });
      // 切到临时目录，避免污染仓库 test_logs。
      Directory.current = tmp;
      try {
        AppLogger.testMode();
        await AppLogger.audit(
          action: 'probe.one',
          run: () async => 1,
        );
        await AppLogger.close();
        AppLogger.testMode();
        await AppLogger.audit(
          action: 'probe.two',
          run: () async => 2,
        );
        await AppLogger.close();
        final List<FileSystemEntity> logs =
            tmp
                .listSync()
                .whereType<Directory>()
                .expand((Directory d) => d.listSync())
                .toList();
        final File log = logs.whereType<File>().singleWhere(
          (File f) => f.path.endsWith('.log'),
        );
        final String content = await log.readAsString();
        expect(content, contains('probe.one'));
        expect(content, contains('probe.two'));
      } finally {
        Directory.current = backup;
      }
      AppLogger.testMode(memory: <String>[]);
    });
  });
}
