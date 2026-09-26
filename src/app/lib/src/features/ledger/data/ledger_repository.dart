import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/app_time.dart';
import '../../../core/utils/ids.dart';

/// 账本成员视图：成员关系 + 底层人员资料。
///
/// `member.deletedAt != null` 即“已删除成员”（历史引用保留，UI 打标）。
typedef LedgerMemberView = ({LedgerMember member, User user});

/// 账本 Repository：账本与账本成员的唯一数据源。
///
/// 说明：虚拟成员底层 `user` 行跨账本复用，改名影响所有账本；
/// 软删除只写 `ledger_member.deleted_at`，不删 `user` 行。
class LedgerRepository {
  LedgerRepository(this._db);

  final AppDatabase _db;

  /// 建账本并让 `ownerUserId` 自动成为成员，同一事务完成。
  Future<Ledger> createLedger({
    required String name,
    required String ownerUserId,
  }) async {
    if (name.trim().isEmpty) {
      throw ValidationException('账本名称不能为空');
    }
    final int now = nowUnixSeconds();
    final String ledgerId = newId();
    await _db.transaction(() async {
      await _db
          .into(_db.ledgers)
          .insert(
            LedgersCompanion.insert(
              id: ledgerId,
              name: name,
              ownerUserId: ownerUserId,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _db
          .into(_db.ledgerMembers)
          .insert(
            LedgerMembersCompanion.insert(
              id: newId(),
              ledgerId: ledgerId,
              userId: ownerUserId,
              joinedAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
    return getById(ledgerId);
  }

  /// 取账本，不存在抛 [NotFoundException]。
  Future<Ledger> getById(String id) async {
    final Ledger? ledger =
        await (_db.select(_db.ledgers)
              ..where((Ledgers t) => t.id.equals(id))).getSingleOrNull();
    if (ledger == null) {
      throw NotFoundException('账本不存在：$id');
    }
    return ledger;
  }

  /// 账本列表（创建时间倒序，同秒按插入序兜底；最近访问优先待 `last_visited` 列支持）。
  Future<List<Ledger>> listLedgers() =>
      (_db.select(_db.ledgers)
            ..where((Ledgers t) => t.deletedAt.isNull())
            ..orderBy([
              (Ledgers t) => OrderingTerm.desc(t.createdAt),
              (_) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
            ]))
          .get();

  /// 账本成员列表，默认排除已软删；`includeDeleted` 置 true 则全量返回。
  Future<List<LedgerMemberView>> listMembers(
    String ledgerId, {
    bool includeDeleted = false,
  }) async {
    await getById(ledgerId);
    final JoinedSelectStatement query =
        _db.select(_db.ledgerMembers).join([
          innerJoin(
            _db.users,
            _db.users.id.equalsExp(_db.ledgerMembers.userId),
          ),
        ])
          ..where(_db.ledgerMembers.ledgerId.equals(ledgerId));
    if (!includeDeleted) {
      query.where(_db.ledgerMembers.deletedAt.isNull());
    }
    final List<TypedResult> rows = await query.get();
    return <LedgerMemberView>[
      for (final TypedResult row in rows)
        (member: row.readTable(_db.ledgerMembers), user: row.readTable(_db.users)),
    ];
  }

  /// 添加虚拟成员到账本（已在账本内则抛 [ValidationException]）。
  Future<LedgerMemberView> addMember({
    required String ledgerId,
    required String userId,
  }) async {
    await getById(ledgerId);
    final int now = nowUnixSeconds();
    final String memberId = newId();
    try {
      await _db
          .into(_db.ledgerMembers)
          .insert(
            LedgerMembersCompanion.insert(
              id: memberId,
              ledgerId: ledgerId,
              userId: userId,
              joinedAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
    } on SqliteException catch (e) {
      if (e.extendedResultCode == 2067) {
        throw ValidationException('成员已在账本内：$userId');
      }
      rethrow;
    }
    final LedgerMember member =
        await (_db.select(_db.ledgerMembers)
              ..where(
                (LedgerMembers t) => t.id.equals(memberId),
              )).getSingle();
    final User user = await (_db.select(
      _db.users,
    )..where((Users t) => t.id.equals(userId))).getSingle();
    return (member: member, user: user);
  }

  /// 重命名成员（改底层 `user` 昵称，影响其所在全部账本）。
  Future<User> renameMember({
    required String ledgerId,
    required String userId,
    required String nickname,
  }) async {
    if (nickname.trim().isEmpty) {
      throw ValidationException('成员昵称不能为空');
    }
    final List<LedgerMemberView> members = await listMembers(
      ledgerId,
      includeDeleted: true,
    );
    if (!members.any((LedgerMemberView view) => view.user.id == userId)) {
      throw NotFoundException('成员不在账本内：$userId');
    }
    await (_db.update(_db.users)..where(
          (Users t) => t.id.equals(userId),
        )).write(
      UsersCompanion(nickname: Value(nickname), updatedAt: Value(nowUnixSeconds())),
    );
    return (_db.select(
      _db.users,
    )..where((Users t) => t.id.equals(userId))).getSingle();
  }

  /// 软删除成员（只写 `ledger_member.deleted_at`，历史账目引用保留）。
  Future<void> softDeleteMember({
    required String ledgerId,
    required String userId,
  }) async {
    final int now = nowUnixSeconds();
    final int changed =
        await (_db.update(_db.ledgerMembers)..where(
              (LedgerMembers t) =>
                  t.ledgerId.equals(ledgerId) &
                  t.userId.equals(userId) &
                  t.deletedAt.isNull(),
            )).write(
          LedgerMembersCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    if (changed == 0) {
      throw NotFoundException('成员不在账本内或已删除：$userId');
    }
  }
}
