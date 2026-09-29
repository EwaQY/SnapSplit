import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/logging/app_logger.dart';

import 'package:snap_split/src/core/database/app_database.dart';
import 'package:snap_split/src/core/errors/app_exception.dart';
import 'package:snap_split/src/features/profile/data/user_repository.dart';

void main() {
  late AppDatabase db;
  late UserRepository users;

  setUp(() {
    AppLogger.testMode();
    db = AppDatabase.memory();
    users = UserRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('T1-1 首次启动建我幂等', () {
    test('空库两次 ensureSelf 返回同一人且仅一行', () async {
      final User first = await users.ensureSelf();
      final User second = await users.ensureSelf();
      expect(first.id, second.id);
      expect(first.nickname, '我');
      expect(first.isSelf, 1);
      final List<User> all = await db.select(db.users).get();
      expect(all, hasLength(1));
    });
  });

  group('T1-2 本地资料改名', () {
    test('改昵称头像生效且 updatedAt 推进', () async {
      final User self = await users.ensureSelf();
      final User updated = await users.updateProfile(
        self.id,
        nickname: '新我',
        avatar: 'a.png',
      );
      expect(updated.nickname, '新我');
      expect(updated.avatar, 'a.png');
      expect(updated.updatedAt, greaterThanOrEqualTo(self.updatedAt));
    });

    test('空昵称抛 ValidationException', () async {
      final User self = await users.ensureSelf();
      await expectLater(
        users.updateProfile(self.id, nickname: '  '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('不存在的 id 抛 NotFoundException', () async {
      await expectLater(
        users.updateProfile('ghost', nickname: 'x'),
        throwsA(isA<NotFoundException>()),
      );
      await expectLater(
        users.getById('ghost'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('虚拟成员昵称必填', () async {
      await expectLater(
        users.createVirtualMember(nickname: ''),
        throwsA(isA<ValidationException>()),
      );
      final User member = await users.createVirtualMember(nickname: '小明');
      expect(member.isSelf, 0);
      expect(member.nickname, '小明');
    });
  });
}
