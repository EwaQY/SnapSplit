import 'package:drift/drift.dart';

/// drift 表类：数据库唯一真相源（对标 `docs/database/schema.sql` v1 快照）。
///
/// 约定：
/// - `tableName` 显式锁定原表名（含保留字 `user`，drift 会自动加引号）。
/// - 列名靠 snake_case 自动转换（`ownerUserId` → `owner_user_id`），等价性测试锁定。
/// - 时间（Unix 秒）/金额（分）/`is_self` 一律 `IntColumn`，
///   不用 `DateTimeColumn`/`BoolColumn`（后者会引入额外约束，破坏等价）。
/// - 索引不在此类中声明，统一见 [AppDatabase] 的迁移策略（原文搬运）。

/// 用户：本地账户（`is_self = 1`）与虚拟成员（`is_self = 0`）。
class Users extends Table {
  @override
  String get tableName => 'user';

  TextColumn get id => text()();
  TextColumn get nickname => text()();
  TextColumn get avatar => text().nullable()();
  IntColumn get isSelf => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 账本：多人分摊记账的顶层容器。
class Ledgers extends Table {
  @override
  String get tableName => 'ledger';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get ownerUserId => text().references(Users, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 账本成员：账本与用户的关联关系。
class LedgerMembers extends Table {
  @override
  String get tableName => 'ledger_member';

  TextColumn get id => text()();
  TextColumn get ledgerId => text().references(Ledgers, #id)();
  TextColumn get userId => text().references(Users, #id)();
  IntColumn get joinedAt => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 购物单：一次购物的集合，底层包含多个账目。
class ShoppingLists extends Table {
  @override
  String get tableName => 'shopping_list';

  TextColumn get id => text()();
  TextColumn get ledgerId => text().references(Ledgers, #id)();
  TextColumn get title => text().nullable()();
  TextColumn get merchant => text().nullable()();
  IntColumn get occurredAt => integer()();
  TextColumn get defaultPayerId => text().nullable().references(Users, #id)();
  TextColumn get defaultParticipantIds => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 账目/商品：最小记账单位，也是分摊基本单位。
class ExpenseItems extends Table {
  @override
  String get tableName => 'expense_item';

  TextColumn get id => text()();
  TextColumn get shoppingListId => text().references(ShoppingLists, #id)();
  TextColumn get ledgerId => text().references(Ledgers, #id)();
  TextColumn get name => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  IntColumn get unitPrice => integer().withDefault(const Constant(0))();
  IntColumn get finalAmount => integer()();
  TextColumn get payerId => text().references(Users, #id)();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 账目参与人：每个账目的分摊参与人及具体分摊金额（分）。
class ItemParticipants extends Table {
  @override
  String get tableName => 'item_participant';

  TextColumn get id => text()();
  TextColumn get expenseItemId => text().references(ExpenseItems, #id)();
  TextColumn get userId => text().references(Users, #id)();
  IntColumn get shareAmount => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 转账/结算记录：成员间资金转移，不计消费，只影响余额。
class Transfers extends Table {
  @override
  String get tableName => 'transfer';

  TextColumn get id => text()();
  TextColumn get ledgerId => text().references(Ledgers, #id)();
  @ReferenceName('sentTransfers')
  TextColumn get fromUserId => text().references(Users, #id)();
  @ReferenceName('receivedTransfers')
  TextColumn get toUserId => text().references(Users, #id)();
  IntColumn get amount => integer()();
  IntColumn get occurredAt => integer()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 标签：全局共享，`archived_at` 非空即已归档。
class Tags extends Table {
  @override
  String get tableName => 'tag';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  IntColumn get archivedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 账目-标签关联：多对多，无软删除字段。
class ItemTags extends Table {
  @override
  String get tableName => 'item_tag';

  TextColumn get id => text()();
  TextColumn get expenseItemId => text().references(ExpenseItems, #id)();
  TextColumn get tagId => text().references(Tags, #id)();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 周期预算：按自然月统计“我作付款人”的账目。
class Budgets extends Table {
  @override
  String get tableName => 'budget';

  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  IntColumn get amount => integer()();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
