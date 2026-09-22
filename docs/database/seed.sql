-- ============================================================
-- SnapSplit Test Data Seed
-- Version: 1.0
-- 说明：此脚本用于开发测试，插入示例数据
-- 使用前请先执行 schema.sql
-- ============================================================

-- 使用固定时间戳便于测试（2026-09-22 12:00:00 UTC = 1790000000）
-- 注意：实际使用时请替换为当前时间戳

-- ============================================================
-- 1. 用户数据
-- ============================================================

-- 本地账户"我"
INSERT INTO "user" (
    "id", "nickname", "avatar", "is_self",
    "created_at", "updated_at", "created_by", "updated_by", "device_id", "version"
) VALUES (
    'user-001', '我', NULL, 1,
    1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1
);

-- 虚拟成员
INSERT INTO "user" (
    "id", "nickname", "avatar", "is_self",
    "created_at", "updated_at", "created_by", "updated_by", "device_id", "version"
) VALUES (
    'user-002', '小明', NULL, 0,
    1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1
);

INSERT INTO "user" (
    "id", "nickname", "avatar", "is_self",
    "created_at", "updated_at", "created_by", "updated_by", "device_id", "version"
) VALUES (
    'user-003', '小红', NULL, 0,
    1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1
);

INSERT INTO "user" (
    "id", "nickname", "avatar", "is_self",
    "created_at", "updated_at", "created_by", "updated_by", "device_id", "version"
) VALUES (
    'user-004', '小李', NULL, 0,
    1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1
);

-- ============================================================
-- 2. 系统预置分类
-- ============================================================

INSERT INTO "category" ("id", "name", "icon", "is_system", "created_at", "updated_at", "created_by", "updated_by", "device_id", "version")
VALUES
    ('cat-001', '餐饮', '🍽️', 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('cat-002', '交通', '🚗', 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('cat-003', '购物', '🛒', 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('cat-004', '娱乐', '🎮', 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('cat-005', '居住', '🏠', 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('cat-006', '医疗', '💊', 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('cat-007', '教育', '📚', 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('cat-008', '通讯', '📱', 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('cat-009', '服饰', '👕', 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('cat-010', '其他', '📦', 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1);

-- ============================================================
-- 3. 账本数据
-- ============================================================

-- 室友合租账本
INSERT INTO "ledger" (
    "id", "name", "owner_user_id",
    "created_at", "updated_at", "created_by", "updated_by", "device_id", "version"
) VALUES (
    'ledger-001', '室友合租', 'user-001',
    1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1
);

-- 朋友聚餐账本
INSERT INTO "ledger" (
    "id", "name", "owner_user_id",
    "created_at", "updated_at", "created_by", "updated_by", "device_id", "version"
) VALUES (
    'ledger-002', '朋友聚餐', 'user-001',
    1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1
);

-- ============================================================
-- 4. 账本成员
-- ============================================================

-- 室友合租账本成员
INSERT INTO "ledger_member" ("id", "ledger_id", "user_id", "role", "joined_at", "created_at", "updated_at", "created_by", "updated_by", "device_id", "version")
VALUES
    ('lm-001', 'ledger-001', 'user-001', 'owner', 1790000000, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('lm-002', 'ledger-001', 'user-002', 'member', 1790000000, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('lm-003', 'ledger-001', 'user-003', 'member', 1790000000, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1);

-- 朋友聚餐账本成员
INSERT INTO "ledger_member" ("id", "ledger_id", "user_id", "role", "joined_at", "created_at", "updated_at", "created_by", "updated_by", "device_id", "version")
VALUES
    ('lm-004', 'ledger-002', 'user-001', 'owner', 1790000000, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('lm-005', 'ledger-002', 'user-002', 'member', 1790000000, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('lm-006', 'ledger-002', 'user-003', 'member', 1790000000, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('lm-007', 'ledger-002', 'user-004', 'member', 1790000000, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1);

-- ============================================================
-- 5. 购物单数据
-- ============================================================

-- 超市购物（多商品）
INSERT INTO "shopping_list" (
    "id", "ledger_id", "title", "merchant", "occurred_at", "created_by",
    "default_payer_id", "note", "source",
    "created_at", "updated_at", "updated_by", "device_id", "version"
) VALUES (
    'sl-001', 'ledger-001', '超市采购', '盒马鲜生', 1789900000, 'user-001',
    'user-001', '周末采购日用品', 'manual',
    1790000000, 1790000000, 'user-001', 'device-test-001', 1
);

-- 外卖订单（单商品）
INSERT INTO "shopping_list" (
    "id", "ledger_id", "title", "merchant", "occurred_at", "created_by",
    "default_payer_id", "note", "source",
    "created_at", "updated_at", "updated_by", "device_id", "version"
) VALUES (
    'sl-002', 'ledger-001', '午餐外卖', '美团外卖', 1789800000, 'user-002',
    'user-002', NULL, 'ai',
    1790000000, 1790000000, 'user-002', 'device-test-001', 1
);

-- 聚餐
INSERT INTO "shopping_list" (
    "id", "ledger_id", "title", "merchant", "occurred_at", "created_by",
    "default_payer_id", "note", "source",
    "created_at", "updated_at", "updated_by", "device_id", "version"
) VALUES (
    'sl-003', 'ledger-002', '周五聚餐', '海底捞', 1789700000, 'user-001',
    'user-001', '四人聚餐', 'manual',
    1790000000, 1790000000, 'user-001', 'device-test-001', 1
);

-- ============================================================
-- 6. 账目数据
-- ============================================================

-- 超市购物的账目
INSERT INTO "expense_item" (
    "id", "shopping_list_id", "ledger_id", "name", "quantity", "unit_price", "final_amount",
    "category_id", "payer_id", "split_type",
    "created_at", "updated_at", "created_by", "updated_by", "device_id", "version"
) VALUES
    ('ei-001', 'sl-001', 'ledger-001', '牛奶', 2, 1500, 3000, 'cat-001', 'user-001', 'equal', 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ei-002', 'sl-001', 'ledger-001', '面包', 3, 800, 2400, 'cat-001', 'user-001', 'equal', 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ei-003', 'sl-001', 'ledger-001', '洗发水', 1, 4500, 4500, 'cat-010', 'user-001', 'equal', 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1);

-- 午餐外卖（单商品，UI降维为账目）
INSERT INTO "expense_item" (
    "id", "shopping_list_id", "ledger_id", "name", "quantity", "unit_price", "final_amount",
    "category_id", "payer_id", "split_type",
    "created_at", "updated_at", "created_by", "updated_by", "device_id", "version"
) VALUES
    ('ei-004', 'sl-002', 'ledger-001', '黄焖鸡米饭', 1, 2500, 2500, 'cat-001', 'user-002', 'equal', 1790000000, 1790000000, 'user-002', 'user-002', 'device-test-001', 1);

-- 聚餐账目
INSERT INTO "expense_item" (
    "id", "shopping_list_id", "ledger_id", "name", "quantity", "unit_price", "final_amount",
    "category_id", "payer_id", "split_type",
    "created_at", "updated_at", "created_by", "updated_by", "device_id", "version"
) VALUES
    ('ei-005', 'sl-003', 'ledger-002', '锅底', 1, 8000, 8000, 'cat-001', 'user-001', 'equal', 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ei-006', 'sl-003', 'ledger-002', '肥牛卷', 2, 6000, 12000, 'cat-001', 'user-001', 'equal', 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ei-007', 'sl-003', 'ledger-002', '蔬菜拼盘', 1, 3500, 3500, 'cat-001', 'user-001', 'equal', 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ei-008', 'sl-003', 'ledger-002', '饮料', 4, 800, 3200, 'cat-001', 'user-001', 'equal', 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1);

-- ============================================================
-- 7. 账目参与人
-- ============================================================

-- 超市购物：均摊给室友合租账本成员
INSERT INTO "item_participant" ("id", "expense_item_id", "user_id", "share_amount", "ratio", "is_included", "created_at", "updated_at", "created_by", "updated_by", "device_id", "version")
VALUES
    -- 牛奶 30元，3人均摊，每人10元
    ('ip-001', 'ei-001', 'user-001', 1000, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-002', 'ei-001', 'user-002', 1000, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-003', 'ei-001', 'user-003', 1000, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    -- 面包 24元，3人均摊，每人8元
    ('ip-004', 'ei-002', 'user-001', 800, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-005', 'ei-002', 'user-002', 800, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-006', 'ei-002', 'user-003', 800, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    -- 洗发水 45元，3人均摊，每人15元
    ('ip-007', 'ei-003', 'user-001', 1500, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-008', 'ei-003', 'user-002', 1500, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-009', 'ei-003', 'user-003', 1500, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1);

-- 午餐外卖：小明独享
INSERT INTO "item_participant" ("id", "expense_item_id", "user_id", "share_amount", "ratio", "is_included", "created_at", "updated_at", "created_by", "updated_by", "device_id", "version")
VALUES
    ('ip-010', 'ei-004', 'user-002', 2500, NULL, 1, 1790000000, 1790000000, 'user-002', 'user-002', 'device-test-001', 1);

-- 聚餐：4人均摊
INSERT INTO "item_participant" ("id", "expense_item_id", "user_id", "share_amount", "ratio", "is_included", "created_at", "updated_at", "created_by", "updated_by", "device_id", "version")
VALUES
    -- 锅底 80元，4人均摊，每人20元
    ('ip-011', 'ei-005', 'user-001', 2000, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-012', 'ei-005', 'user-002', 2000, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-013', 'ei-005', 'user-003', 2000, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-014', 'ei-005', 'user-004', 2000, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    -- 肥牛卷 120元，4人均摊，每人30元
    ('ip-015', 'ei-006', 'user-001', 3000, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-016', 'ei-006', 'user-002', 3000, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-017', 'ei-006', 'user-003', 3000, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-018', 'ei-006', 'user-004', 3000, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    -- 蔬菜拼盘 35元，4人均摊，每人8.75元（取整875）
    ('ip-019', 'ei-007', 'user-001', 875, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-020', 'ei-007', 'user-002', 875, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-021', 'ei-007', 'user-003', 875, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-022', 'ei-007', 'user-004', 875, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    -- 饮料 32元，4人均摊，每人8元
    ('ip-023', 'ei-008', 'user-001', 800, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-024', 'ei-008', 'user-002', 800, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-025', 'ei-008', 'user-003', 800, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1),
    ('ip-026', 'ei-008', 'user-004', 800, NULL, 1, 1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1);

-- ============================================================
-- 8. 转账记录
-- ============================================================

INSERT INTO "transfer" (
    "id", "ledger_id", "from_user_id", "to_user_id", "amount", "occurred_at", "note",
    "created_by", "created_at", "updated_at", "device_id", "version"
) VALUES (
    'tr-001', 'ledger-001', 'user-002', 'user-001', 1500, 1789600000, '还上次垫付的饭钱',
    'user-001', 1790000000, 1790000000, 'device-test-001', 1
);

-- ============================================================
-- 9. 预算数据
-- ============================================================

INSERT INTO "budget" (
    "id", "user_id", "amount", "year", "month",
    "created_at", "updated_at", "created_by", "updated_by", "device_id", "version"
) VALUES (
    'budget-001', 'user-001', 500000, 2026, 9,
    1790000000, 1790000000, 'user-001', 'user-001', 'device-test-001', 1
);

-- ============================================================
-- 完成提示
-- ============================================================
-- 测试数据插入完成！
-- 包含：
-- - 1个本地账户"我" + 3个虚拟成员
-- - 10个系统预置分类
-- - 2个账本（室友合租、朋友聚餐）
-- - 7个账本成员关联
-- - 3个购物单（多商品、单商品、聚餐）
-- - 8个账目
-- - 26个参与人记录
-- - 1条转账记录
-- - 1个月预算（9月，5000元）
