import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/logging/app_logger.dart';

import 'package:snap_split/src/core/database/app_database.dart';
import 'package:snap_split/src/core/errors/app_exception.dart';
import 'package:snap_split/src/features/ledger/data/ledger_repository.dart';
import 'package:snap_split/src/features/profile/data/user_repository.dart';

void main() {
  late AppDatabase db;
  late UserRepository users;
  late LedgerRepository ledgers;

  setUp(() {
    AppLogger.testMode();
    db = AppDatabase.memory();
    users = UserRepository(db);
    ledgers = LedgerRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('T1-3 建账本自动进成员', () {
    test('建账本同事务写入成员', () async {
      final User self = await users.ensureSelf();
      final Ledger ledger = await ledgers.createLedger(
        name: '室友合租',
        ownerUserId: self.id,
      );
      expect(ledger.name, '室友合租');
      final List<LedgerMemberView> members = await ledgers.listMembers(
        ledger.id,
      );
      expect(members, hasLength(1));
      expect(members.single.user.id, self.id);
    });

    test('空名称抛 ValidationException', () async {
      final User self = await users.ensureSelf();
      await expectLater(
        ledgers.createLedger(name: ' ', ownerUserId: self.id),
        throwsA(isA<ValidationException>()),
      );
    });

    test('listLedgers 创建时间倒序', () async {
      final User self = await users.ensureSelf();
      await ledgers.createLedger(name: '先建', ownerUserId: self.id);
      await ledgers.createLedger(name: '后建', ownerUserId: self.id);
      final List<Ledger> all = await ledgers.listLedgers();
      expect(all.map((Ledger e) => e.name), <String>['后建', '先建']);
    });
  });

  group('T1-4 虚拟成员全生命周期', () {
    test('增改软删与历史保留', () async {
      final User self = await users.ensureSelf();
      final Ledger ledger = await ledgers.createLedger(
        name: '账本',
        ownerUserId: self.id,
      );
      final User ming = await users.createVirtualMember(nickname: '小明');
      final LedgerMemberView added = await ledgers.addMember(
        ledgerId: ledger.id,
        userId: ming.id,
      );
      expect(added.user.nickname, '小明');

      expect(
        (await ledgers.listMembers(ledger.id)).map(
          (LedgerMemberView v) => v.user.nickname,
        ),
        contains('小明'),
      );

      final User renamed = await ledgers.renameMember(
        ledgerId: ledger.id,
        userId: ming.id,
        nickname: '大明',
      );
      expect(renamed.nickname, '大明');

      await ledgers.softDeleteMember(ledgerId: ledger.id, userId: ming.id);
      expect(
        (await ledgers.listMembers(ledger.id)).map(
          (LedgerMemberView v) => v.user.id,
        ),
        isNot(contains(ming.id)),
      );
      final List<LedgerMemberView> withDeleted = await ledgers.listMembers(
        ledger.id,
        includeDeleted: true,
      );
      final LedgerMemberView tombstone = withDeleted.singleWhere(
        (LedgerMemberView v) => v.user.id == ming.id,
      );
      expect(tombstone.member.deletedAt, isNotNull);
      // 历史引用保留：user 行仍在。
      expect((await users.getById(ming.id)).nickname, '大明');
    });

    test('重复添加抛 ValidationException', () async {
      final User self = await users.ensureSelf();
      final Ledger ledger = await ledgers.createLedger(
        name: '账本',
        ownerUserId: self.id,
      );
      final User ming = await users.createVirtualMember(nickname: '小明');
      await ledgers.addMember(ledgerId: ledger.id, userId: ming.id);
      await expectLater(
        ledgers.addMember(ledgerId: ledger.id, userId: ming.id),
        throwsA(isA<ValidationException>()),
      );
    });

    test('删不存在/不在账本的成员抛 NotFoundException', () async {      final User self = await users.ensureSelf();
      final Ledger ledger = await ledgers.createLedger(
        name: '账本',
        ownerUserId: self.id,
      );
      await expectLater(
        ledgers.softDeleteMember(ledgerId: ledger.id, userId: 'ghost'),
        throwsA(isA<NotFoundException>()),
      );
      await expectLater(
        ledgers.renameMember(
          ledgerId: ledger.id,
          userId: 'ghost',
          nickname: 'x',
        ),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('P9 账本删除收紧', () {
    test('当月空账本可删，删后列表与详情均不可查', () async {
      final User self = await users.ensureSelf();
      final Ledger ledger = await ledgers.createLedger(
        name: '临时',
        ownerUserId: self.id,
      );
      await ledgers.softDeleteLedger(ledger.id);
      expect(
        (await ledgers.listLedgers()).map((Ledger e) => e.id),
        isNot(contains(ledger.id)),
      );
      await expectLater(
        ledgers.getById(ledger.id),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('有账单的账本不可删', () async {
      final User self = await users.ensureSelf();
      final Ledger ledger = await ledgers.createLedger(
        name: '有账',
        ownerUserId: self.id,
      );
      await db
          .into(db.shoppingLists)
          .insert(
            ShoppingListsCompanion.insert(
              id: 'sl-1',
              ledgerId: ledger.id,
              occurredAt: 1,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await expectLater(
        ledgers.softDeleteLedger(ledger.id),
        throwsA(isA<ValidationException>()),
      );
    });

    test('非当月创建的账本不可删', () async {
      final User self = await users.ensureSelf();
      final DateTime now = DateTime.now();
      final DateTime lastMonth = DateTime(now.year, now.month - 1, 10);
      final int occurred = lastMonth.millisecondsSinceEpoch ~/ 1000;
      await db
          .into(db.ledgers)
          .insert(
            LedgersCompanion.insert(
              id: 'l-old',
              name: '旧账本',
              ownerUserId: self.id,
              createdAt: occurred,
              updatedAt: occurred,
            ),
          );
      await expectLater(
        ledgers.softDeleteLedger('l-old'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('非法 owner 建账本抛友好 DbException', () async {
      await expectLater(
        ledgers.createLedger(name: '坏账本', ownerUserId: 'ghost'),
        throwsA(
          isA<DbException>().having(
            (DbException e) => e.message,
            'message',
            contains('数据库异常'),
          ),
        ),
      );
    });
  });
}
