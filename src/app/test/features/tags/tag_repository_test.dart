import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/database/app_database.dart';
import 'package:snap_split/src/core/errors/app_exception.dart';
import 'package:snap_split/src/features/ledger/data/ledger_repository.dart';
import 'package:snap_split/src/features/profile/data/user_repository.dart';
import 'package:snap_split/src/features/shopping/data/shopping_repository.dart';
import 'package:snap_split/src/features/tags/data/tag_repository.dart';

/// T3-2：标签建改归档，历史引用保留。
void main() {
  late AppDatabase db;
  late TagRepository tags;
  late UserRepository users;
  late LedgerRepository ledgers;
  late ShoppingRepository shopping;

  setUp(() {
    db = AppDatabase.memory();
    tags = TagRepository(db);
    users = UserRepository(db);
    ledgers = LedgerRepository(db);
    shopping = ShoppingRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('建改归档全链路', () async {
    final Tag food = await tags.createTag(name: '餐饮', icon: '🍽️');
    expect(food.name, '餐饮');

    await expectLater(
      tags.createTag(name: '餐饮'),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      tags.createTag(name: '  '),
      throwsA(isA<ValidationException>()),
    );

    final Tag renamed = await tags.renameTag(food.id, name: '美食');
    expect(renamed.name, '美食');
    final Tag other = await tags.createTag(name: '交通');
    await expectLater(
      tags.renameTag(other.id, name: '美食'),
      throwsA(isA<ValidationException>()),
    );

    // 打标签的账目先建好，再归档。
    final User self = await users.ensureSelf();
    final Ledger ledger = await ledgers.createLedger(
      name: '账本',
      ownerUserId: self.id,
    );
    await shopping.createSingleItem(
      ledgerId: ledger.id,
      name: '午餐',
      quantity: 1,
      unitPrice: 2500,
      finalAmount: 2500,
      payerId: self.id,
      participantIds: <String>[self.id],
      tagIds: <String>[food.id],
    );

    final Tag archived = await tags.archiveTag(food.id);
    expect(archived.archivedAt, isNotNull);

    // 选择器消失，管理页可见。
    expect(
      (await tags.listActiveTags()).map((Tag t) => t.id),
      isNot(contains(food.id)),
    );
    expect(
      (await tags.listAllTags()).map((Tag t) => t.id),
      contains(food.id),
    );

    // 历史账目标签明细仍显示原名。
    final List<ShoppingList> lists = await db.select(db.shoppingLists).get();
    final ShoppingDetail detail = await shopping.getDetail(
      lists.single.id,
    );
    expect(
      detail.items.single.tags.map((Tag t) => t.name),
      <String>['美食'],
    );
  });
}
