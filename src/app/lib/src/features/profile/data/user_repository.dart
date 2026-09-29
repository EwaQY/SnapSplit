import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/utils/app_time.dart';
import '../../../core/utils/ids.dart';

/// 本地账户 Repository：设备上唯一的“我”，首次启动自动生成。
class UserRepository {
  UserRepository(this._db);

  final AppDatabase _db;

  /// 取“我”，不存在则创建后返回。幂等，可反复调用。
  Future<User> ensureSelf() => AppLogger.audit(
    action: 'user.ensureSelf',
    entity: 'user',
    run: () async {
      final List<User> found =
          await (_db.select(_db.users)
                ..where(
                  (t) => t.isSelf.equals(1) & t.deletedAt.isNull(),
                )
                ..limit(1))
              .get();
      if (found.isNotEmpty) {
        return found.single;
      }
      final int now = nowUnixSeconds();
      final String id = newId();
      await _db
          .into(_db.users)
          .insert(
            UsersCompanion.insert(
              id: id,
              nickname: '我',
              isSelf: const Value(1),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return getById(id);
    },
  );

  /// 取指定用户，不存在抛 [NotFoundException]。
  Future<User> getById(String id) async {
    final User? user =
        await (_db.select(_db.users)
              ..where((Users t) => t.id.equals(id))).getSingleOrNull();
    if (user == null) {
      throw NotFoundException('用户不存在：$id');
    }
    return user;
  }

  /// 改昵称/头像（传 null 表示不改），同步刷新 `updated_at`。
  Future<User> updateProfile(
    String id, {
    String? nickname,
    String? avatar,
  }) => AppLogger.audit(
    action: 'user.updateProfile',
    entity: 'user',
    id: id,
    run: () async {
      if (nickname != null && nickname.trim().isEmpty) {
        throw ValidationException('昵称不能为空');
      }
      await getById(id);
      await (_db.update(_db.users)..where(
            (t) => t.id.equals(id),
          )).write(
        UsersCompanion(
          nickname: nickname == null ? const Value.absent() : Value(nickname),
          avatar: avatar == null ? const Value.absent() : Value(avatar),
          updatedAt: Value(nowUnixSeconds()),
        ),
      );
      return getById(id);
    },
  );

  /// 新建虚拟成员（`is_self = 0`），昵称必填。
  Future<User> createVirtualMember({
    required String nickname,
    String? avatar,
  }) => AppLogger.audit(
    action: 'user.createVirtualMember',
    entity: 'user',
    run: () async {
      if (nickname.trim().isEmpty) {
        throw ValidationException('虚拟成员昵称不能为空');
      }
      final int now = nowUnixSeconds();
      final String id = newId();
      await _db
          .into(_db.users)
          .insert(
            UsersCompanion.insert(
              id: id,
              nickname: nickname,
              avatar: Value(avatar),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return getById(id);
    },
  );
}
