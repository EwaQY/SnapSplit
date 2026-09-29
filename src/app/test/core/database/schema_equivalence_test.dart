import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_split/src/core/database/app_database.dart';

/// 期望列：`PRAGMA table_info` 行（列名，类型，非空，默认值，主键序）。
typedef ExpectedColumn = (String, String, bool, String?, int);

/// 期望外键：`PRAGMA foreign_key_list` 行（来源列，目标表，目标列）。
typedef ExpectedForeignKey = (String, String, String);

/// 期望索引（覆盖列有序；partial 索引带 WHERE 原文）。
typedef ExpectedIndex = ({String name, bool unique, List<String> columns, String? where});

/// v1 基线期望（转录自冻结的 `docs/database/schema.sql`，语义对比）。
///
/// 口径：列名/类型/非空/默认值/主键、外键目标与动作、索引唯一性+覆盖列+
/// partial WHERE；表名/索引名/语句格式差异不管。
const Map<String, List<ExpectedColumn>> kExpectedColumns = <String, List<ExpectedColumn>>{
  'user': <ExpectedColumn>[
    ('id', 'TEXT', true, null, 1),
    ('nickname', 'TEXT', true, null, 0),
    ('avatar', 'TEXT', false, null, 0),
    ('is_self', 'INTEGER', true, '0', 0),
    ('created_at', 'INTEGER', true, null, 0),
    ('updated_at', 'INTEGER', true, null, 0),
    ('deleted_at', 'INTEGER', false, null, 0),
  ],
  'ledger': <ExpectedColumn>[
    ('id', 'TEXT', true, null, 1),
    ('name', 'TEXT', true, null, 0),
    ('owner_user_id', 'TEXT', true, null, 0),
    ('created_at', 'INTEGER', true, null, 0),
    ('updated_at', 'INTEGER', true, null, 0),
    ('deleted_at', 'INTEGER', false, null, 0),
  ],
  'ledger_member': <ExpectedColumn>[
    ('id', 'TEXT', true, null, 1),
    ('ledger_id', 'TEXT', true, null, 0),
    ('user_id', 'TEXT', true, null, 0),
    ('joined_at', 'INTEGER', true, null, 0),
    ('created_at', 'INTEGER', true, null, 0),
    ('updated_at', 'INTEGER', true, null, 0),
    ('deleted_at', 'INTEGER', false, null, 0),
  ],
  'shopping_list': <ExpectedColumn>[
    ('id', 'TEXT', true, null, 1),
    ('ledger_id', 'TEXT', true, null, 0),
    ('title', 'TEXT', false, null, 0),
    ('merchant', 'TEXT', false, null, 0),
    ('occurred_at', 'INTEGER', true, null, 0),
    ('default_payer_id', 'TEXT', false, null, 0),
    ('default_participant_ids', 'TEXT', false, null, 0),
    ('note', 'TEXT', false, null, 0),
    ('source', 'TEXT', true, "'manual'", 0),
    ('created_at', 'INTEGER', true, null, 0),
    ('updated_at', 'INTEGER', true, null, 0),
    ('deleted_at', 'INTEGER', false, null, 0),
  ],
  'expense_item': <ExpectedColumn>[
    ('id', 'TEXT', true, null, 1),
    ('shopping_list_id', 'TEXT', true, null, 0),
    ('ledger_id', 'TEXT', true, null, 0),
    ('name', 'TEXT', true, null, 0),
    ('quantity', 'REAL', true, '1.0', 0),
    ('unit_price', 'INTEGER', true, '0', 0),
    ('final_amount', 'INTEGER', true, null, 0),
    ('payer_id', 'TEXT', true, null, 0),
    ('note', 'TEXT', false, null, 0),
    ('created_at', 'INTEGER', true, null, 0),
    ('updated_at', 'INTEGER', true, null, 0),
    ('deleted_at', 'INTEGER', false, null, 0),
  ],
  'item_participant': <ExpectedColumn>[
    ('id', 'TEXT', true, null, 1),
    ('expense_item_id', 'TEXT', true, null, 0),
    ('user_id', 'TEXT', true, null, 0),
    ('share_amount', 'INTEGER', true, null, 0),
    ('created_at', 'INTEGER', true, null, 0),
    ('updated_at', 'INTEGER', true, null, 0),
    ('deleted_at', 'INTEGER', false, null, 0),
  ],
  'transfer': <ExpectedColumn>[
    ('id', 'TEXT', true, null, 1),
    ('ledger_id', 'TEXT', true, null, 0),
    ('from_user_id', 'TEXT', true, null, 0),
    ('to_user_id', 'TEXT', true, null, 0),
    ('amount', 'INTEGER', true, null, 0),
    ('occurred_at', 'INTEGER', true, null, 0),
    ('note', 'TEXT', false, null, 0),
    ('created_at', 'INTEGER', true, null, 0),
    ('updated_at', 'INTEGER', true, null, 0),
    ('deleted_at', 'INTEGER', false, null, 0),
  ],
  'tag': <ExpectedColumn>[
    ('id', 'TEXT', true, null, 1),
    ('name', 'TEXT', true, null, 0),
    ('icon', 'TEXT', false, null, 0),
    ('archived_at', 'INTEGER', false, null, 0),
    ('created_at', 'INTEGER', true, null, 0),
    ('updated_at', 'INTEGER', true, null, 0),
    ('deleted_at', 'INTEGER', false, null, 0),
  ],
  'item_tag': <ExpectedColumn>[
    ('id', 'TEXT', true, null, 1),
    ('expense_item_id', 'TEXT', true, null, 0),
    ('tag_id', 'TEXT', true, null, 0),
    ('created_at', 'INTEGER', true, null, 0),
  ],
  'budget': <ExpectedColumn>[
    ('id', 'TEXT', true, null, 1),
    ('user_id', 'TEXT', true, null, 0),
    ('amount', 'INTEGER', true, null, 0),
    ('year', 'INTEGER', true, null, 0),
    ('month', 'INTEGER', true, null, 0),
    ('created_at', 'INTEGER', true, null, 0),
    ('updated_at', 'INTEGER', true, null, 0),
    ('deleted_at', 'INTEGER', false, null, 0),
  ],
};

const Map<String, List<ExpectedForeignKey>> kExpectedForeignKeys =
    <String, List<ExpectedForeignKey>>{
      'user': <ExpectedForeignKey>[],
      'ledger': <ExpectedForeignKey>[('owner_user_id', 'user', 'id')],
      'ledger_member': <ExpectedForeignKey>[
        ('ledger_id', 'ledger', 'id'),
        ('user_id', 'user', 'id'),
      ],
      'shopping_list': <ExpectedForeignKey>[
        ('ledger_id', 'ledger', 'id'),
        ('default_payer_id', 'user', 'id'),
      ],
      'expense_item': <ExpectedForeignKey>[
        ('shopping_list_id', 'shopping_list', 'id'),
        ('ledger_id', 'ledger', 'id'),
        ('payer_id', 'user', 'id'),
      ],
      'item_participant': <ExpectedForeignKey>[
        ('expense_item_id', 'expense_item', 'id'),
        ('user_id', 'user', 'id'),
      ],
      'transfer': <ExpectedForeignKey>[
        ('ledger_id', 'ledger', 'id'),
        ('from_user_id', 'user', 'id'),
        ('to_user_id', 'user', 'id'),
      ],
      'tag': <ExpectedForeignKey>[],
      'item_tag': <ExpectedForeignKey>[
        ('expense_item_id', 'expense_item', 'id'),
        ('tag_id', 'tag', 'id'),
      ],
      'budget': <ExpectedForeignKey>[('user_id', 'user', 'id')],
    };

const Map<String, List<ExpectedIndex>> kExpectedIndexes = <String, List<ExpectedIndex>>{
  'user': <ExpectedIndex>[
    (name: 'idx_user_is_self', unique: false, columns: ['is_self'], where: null),
    (
      name: 'idx_user_deleted_at',
      unique: false,
      columns: ['deleted_at'],
      where: null,
    ),
  ],
  'ledger': <ExpectedIndex>[
    (
      name: 'idx_ledger_owner',
      unique: false,
      columns: ['owner_user_id'],
      where: null,
    ),
    (
      name: 'idx_ledger_deleted_at',
      unique: false,
      columns: ['deleted_at'],
      where: null,
    ),
  ],
  'ledger_member': <ExpectedIndex>[
    (
      name: 'idx_ledger_member_ledger',
      unique: false,
      columns: ['ledger_id'],
      where: null,
    ),
    (
      name: 'idx_ledger_member_user',
      unique: false,
      columns: ['user_id'],
      where: null,
    ),
    (
      name: 'idx_ledger_member_deleted_at',
      unique: false,
      columns: ['deleted_at'],
      where: null,
    ),
    (
      name: 'idx_ledger_member_unique',
      unique: true,
      columns: ['ledger_id', 'user_id'],
      where: 'WHERE "deleted_at" IS NULL',
    ),
  ],
  'shopping_list': <ExpectedIndex>[
    (
      name: 'idx_shopping_list_ledger',
      unique: false,
      columns: ['ledger_id'],
      where: null,
    ),
    (
      name: 'idx_shopping_list_occurred_at',
      unique: false,
      columns: ['occurred_at'],
      where: null,
    ),
    (
      name: 'idx_shopping_list_deleted_at',
      unique: false,
      columns: ['deleted_at'],
      where: null,
    ),
  ],
  'expense_item': <ExpectedIndex>[
    (
      name: 'idx_expense_item_shopping_list',
      unique: false,
      columns: ['shopping_list_id'],
      where: null,
    ),
    (
      name: 'idx_expense_item_ledger',
      unique: false,
      columns: ['ledger_id'],
      where: null,
    ),
    (
      name: 'idx_expense_item_payer',
      unique: false,
      columns: ['payer_id'],
      where: null,
    ),
    (
      name: 'idx_expense_item_deleted_at',
      unique: false,
      columns: ['deleted_at'],
      where: null,
    ),
  ],
  'item_participant': <ExpectedIndex>[
    (
      name: 'idx_item_participant_item',
      unique: false,
      columns: ['expense_item_id'],
      where: null,
    ),
    (
      name: 'idx_item_participant_user',
      unique: false,
      columns: ['user_id'],
      where: null,
    ),
    (
      name: 'idx_item_participant_deleted_at',
      unique: false,
      columns: ['deleted_at'],
      where: null,
    ),
    (
      name: 'idx_item_participant_unique',
      unique: true,
      columns: ['expense_item_id', 'user_id'],
      where: 'WHERE "deleted_at" IS NULL',
    ),
  ],
  'transfer': <ExpectedIndex>[
    (
      name: 'idx_transfer_ledger',
      unique: false,
      columns: ['ledger_id'],
      where: null,
    ),
    (
      name: 'idx_transfer_from_user',
      unique: false,
      columns: ['from_user_id'],
      where: null,
    ),
    (
      name: 'idx_transfer_to_user',
      unique: false,
      columns: ['to_user_id'],
      where: null,
    ),
    (
      name: 'idx_transfer_occurred_at',
      unique: false,
      columns: ['occurred_at'],
      where: null,
    ),
    (
      name: 'idx_transfer_deleted_at',
      unique: false,
      columns: ['deleted_at'],
      where: null,
    ),
  ],
  'tag': <ExpectedIndex>[
    (
      name: 'idx_tag_archived_at',
      unique: false,
      columns: ['archived_at'],
      where: null,
    ),
    (
      name: 'idx_tag_deleted_at',
      unique: false,
      columns: ['deleted_at'],
      where: null,
    ),
    (
      name: 'idx_tag_name_unique',
      unique: true,
      columns: ['name'],
      where: 'WHERE "deleted_at" IS NULL',
    ),
  ],
  'item_tag': <ExpectedIndex>[
    (
      name: 'idx_item_tag_item',
      unique: false,
      columns: ['expense_item_id'],
      where: null,
    ),
    (
      name: 'idx_item_tag_tag',
      unique: false,
      columns: ['tag_id'],
      where: null,
    ),
    (
      name: 'idx_item_tag_unique',
      unique: true,
      columns: ['expense_item_id', 'tag_id'],
      where: null,
    ),
  ],
  'budget': <ExpectedIndex>[
    (
      name: 'idx_budget_user',
      unique: false,
      columns: ['user_id'],
      where: null,
    ),
    (
      name: 'idx_budget_year_month',
      unique: false,
      columns: ['year', 'month'],
      where: null,
    ),
    (
      name: 'idx_budget_deleted_at',
      unique: false,
      columns: ['deleted_at'],
      where: null,
    ),
    (
      name: 'idx_budget_unique',
      unique: true,
      columns: ['user_id', 'year', 'month'],
      where: 'WHERE "deleted_at" IS NULL',
    ),
  ],
};

/// 空白归一化后对比（生成器换行/缩进差异不管）。
String _normalize(String sql) => sql.replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  group('T0-1 drift 建库与 v1 快照语义等价', () {
    test('10 张表存在', () async {
      final List<QueryRow> rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            'AND name NOT LIKE ?',
            variables: [Variable.withString('sqlite_%')],
          )
          .get();
      final Set<String> names = <String>{
        for (final QueryRow row in rows) row.read<String>('name'),
      };
      expect(names, kExpectedColumns.keys.toSet());
    });

    test('列定义等价（列名/类型/非空/默认/主键）', () async {
      for (final MapEntry<String, List<ExpectedColumn>> entry
          in kExpectedColumns.entries) {
        final List<QueryRow> rows = await db
            .customSelect('PRAGMA table_info("${entry.key}")')
            .get();
        final List<ExpectedColumn> actual = <ExpectedColumn>[
          for (final QueryRow row in rows)
            (
              row.read<String>('name'),
              row.read<String>('type'),
              row.read<int>('notnull') == 1,
              row.readNullable<String>('dflt_value'),
              row.read<int>('pk'),
            ),
        ];
        expect(actual, entry.value, reason: '表 ${entry.key} 列定义漂移');
      }
    });

    test('外键等价（目标表/列，NO ACTION）', () async {
      for (final MapEntry<String, List<ExpectedForeignKey>> entry
          in kExpectedForeignKeys.entries) {
        final List<QueryRow> rows = await db
            .customSelect('PRAGMA foreign_key_list("${entry.key}")')
            .get();
        // 外键子句顺序语义无关，按三元组无序对比。
        final List<ExpectedForeignKey> actual = <ExpectedForeignKey>[
          for (final QueryRow row in rows)
            (
              row.read<String>('from'),
              row.read<String>('table'),
              row.read<String>('to'),
            ),
        ]..sort(
          (ExpectedForeignKey a, ExpectedForeignKey b) =>
              '${a.$1}.${a.$2}.${a.$3}'.compareTo('${b.$1}.${b.$2}.${b.$3}'),
        );
        final List<ExpectedForeignKey> expected = entry.value.toList()
          ..sort(
            (ExpectedForeignKey a, ExpectedForeignKey b) =>
                '${a.$1}.${a.$2}.${a.$3}'.compareTo('${b.$1}.${b.$2}.${b.$3}'),
          );
        expect(actual, expected, reason: '表 ${entry.key} 外键漂移');
        for (final QueryRow row in rows) {
          expect(row.read<String>('on_update'), 'NO ACTION');
          expect(row.read<String>('on_delete'), 'NO ACTION');
        }
      }
    });

    test('索引等价（唯一性/覆盖列/partial WHERE）', () async {
      for (final MapEntry<String, List<ExpectedIndex>> entry
          in kExpectedIndexes.entries) {
        final List<QueryRow> rows = await db
            .customSelect('PRAGMA index_list("${entry.key}")')
            .get();
        // 排除主键自增索引，只看显式索引。
        final List<QueryRow> explicit = rows
            .where(
              (QueryRow row) =>
                  !(row.read<String>('name').startsWith('sqlite_autoindex')),
            )
            .toList();
        expect(
          explicit.map((QueryRow row) => row.read<String>('name')).toSet(),
          entry.value.map((ExpectedIndex index) => index.name).toSet(),
          reason: '表 ${entry.key} 索引集合漂移',
        );
        for (final ExpectedIndex expected in entry.value) {
          final QueryRow info = explicit.singleWhere(
            (QueryRow row) => row.read<String>('name') == expected.name,
          );
          expect(
            info.read<int>('unique') == 1,
            expected.unique,
            reason: '索引 ${expected.name} 唯一性漂移',
          );
          final List<QueryRow> columns = await db
              .customSelect('PRAGMA index_info("${expected.name}")')
              .get();
          columns.sort(
            (QueryRow a, QueryRow b) =>
                a.read<int>('seqno').compareTo(b.read<int>('seqno')),
          );
          expect(
            <String>[for (final QueryRow c in columns) c.read<String>('name')],
            expected.columns,
            reason: '索引 ${expected.name} 覆盖列漂移',
          );
          final List<QueryRow> ddl = await db
              .customSelect(
                "SELECT sql FROM sqlite_master WHERE type = 'index' AND name = ?",
                variables: [Variable.withString(expected.name)],
              )
              .get();
          final String sql = ddl.single.read<String>('sql');
          if (expected.where == null) {
            expect(
              sql.contains('WHERE'),
              isFalse,
              reason: '索引 ${expected.name} 不应是 partial 索引',
            );
          } else {
            expect(
              _normalize(sql).contains(_normalize(expected.where!)),
              isTrue,
              reason: '索引 ${expected.name} partial 条件漂移：$sql',
            );
          }
        }
      }
    });

    test('外键约束已启用', () async {
      final QueryRow row = await db
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(row.read<int>('foreign_keys'), 1);
    });
  });
}
