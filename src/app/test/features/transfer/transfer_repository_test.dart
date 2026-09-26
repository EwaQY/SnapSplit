import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/database/app_database.dart';
import 'package:snap_split/src/core/errors/app_exception.dart';
import 'package:snap_split/src/core/utils/app_time.dart';
import 'package:snap_split/src/features/ledger/data/ledger_repository.dart';
import 'package:snap_split/src/features/profile/data/user_repository.dart';
import 'package:snap_split/src/features/transfer/data/transfer_repository.dart';

/// T4-2：转账 CRUD 与校验。
void main() {
  late AppDatabase db;
  late UserRepository users;
  late LedgerRepository ledgers;
  late TransferRepository transfers;

  late User self;
  late User ming;
  late Ledger ledger;

  setUp(() async {
    db = AppDatabase.memory();
    users = UserRepository(db);
    ledgers = LedgerRepository(db);
    transfers = TransferRepository(db);
    self = await users.ensureSelf();
    ming = await users.createVirtualMember(nickname: '小明');
    ledger = await ledgers.createLedger(
      name: '账本',
      ownerUserId: self.id,
    );
    await ledgers.addMember(ledgerId: ledger.id, userId: ming.id);
  });

  tearDown(() async {
    await db.close();
  });

  test('建改软删往返', () async {
    final Transfer created = await transfers.createTransfer(
      ledgerId: ledger.id,
      fromUserId: self.id,
      toUserId: ming.id,
      amountCents: 1500,
      note: '结清',
    );
    expect((created.amount, created.note), (1500, '结清'));

    final Transfer updated = await transfers.updateTransfer(
      created.id,
      amountCents: 1000,
    );
    expect(updated.amount, 1000);

    await transfers.softDeleteTransfer(created.id);
    expect(await transfers.listTransfers(ledger.id), isEmpty);
    await expectLater(
      transfers.getById(created.id),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('同人/0 金额/非成员抛 ValidationException', () async {
    await expectLater(
      transfers.createTransfer(
        ledgerId: ledger.id,
        fromUserId: self.id,
        toUserId: self.id,
        amountCents: 100,
      ),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      transfers.createTransfer(
        ledgerId: ledger.id,
        fromUserId: self.id,
        toUserId: ming.id,
        amountCents: 0,
      ),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      transfers.createTransfer(
        ledgerId: ledger.id,
        fromUserId: self.id,
        toUserId: 'ghost',
        amountCents: 100,
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('改删历史记录抛 ArchivedReadOnlyException', () async {
    final DateTime now = DateTime.now();
    final int past =
        DateTime(now.year, now.month - 1, 10).millisecondsSinceEpoch ~/ 1000;
    final String id = 'tr-old';
    final int created = nowUnixSeconds();
    await db
        .into(db.transfers)
        .insert(
          TransfersCompanion.insert(
            id: id,
            ledgerId: ledger.id,
            fromUserId: self.id,
            toUserId: ming.id,
            amount: 100,
            occurredAt: past,
            createdAt: created,
            updatedAt: created,
          ),
        );
    await expectLater(
      transfers.updateTransfer(id, amountCents: 200),
      throwsA(isA<ArchivedReadOnlyException>()),
    );
    await expectLater(
      transfers.softDeleteTransfer(id),
      throwsA(isA<ArchivedReadOnlyException>()),
    );
  });
}
