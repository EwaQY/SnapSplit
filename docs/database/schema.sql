-- ============================================================
-- SnapSplit SQLite Database Schema
-- Version: 2.0
-- Based on PRD V3.0
-- 说明：所有时间字段使用Unix时间戳（INTEGER），金额字段使用"分"为单位
-- ============================================================

-- 启用外键约束（SQLite默认不启用）
PRAGMA foreign_keys = ON;

-- ============================================================
-- 1. 用户表 (User / Profile)
-- 说明：存储本地账户和虚拟成员信息
-- ============================================================
CREATE TABLE IF NOT EXISTS "user" (
    "id" TEXT PRIMARY KEY,                        -- UUID主键
    "nickname" TEXT NOT NULL,                     -- 昵称
    "avatar" TEXT,                                -- 头像URL
    "is_self" INTEGER NOT NULL DEFAULT 0,         -- 是否为本地账户"我"：1=是，0=否（虚拟成员）
    "created_at" INTEGER NOT NULL,                -- 创建时间（Unix时间戳）
    "updated_at" INTEGER NOT NULL,                -- 最后更新时间（Unix时间戳）
    "deleted_at" INTEGER                          -- 软删除时间（NULL表示未删除）
);

-- 索引
CREATE INDEX IF NOT EXISTS "idx_user_is_self" ON "user" ("is_self");
CREATE INDEX IF NOT EXISTS "idx_user_deleted_at" ON "user" ("deleted_at");

-- ============================================================
-- 2. 账本表 (Ledger)
-- 说明：多人分摊记账的顶层容器
-- ============================================================
CREATE TABLE IF NOT EXISTS "ledger" (
    "id" TEXT PRIMARY KEY,                        -- UUID主键
    "name" TEXT NOT NULL,                         -- 账本名称
    "owner_user_id" TEXT NOT NULL,                -- 创建者用户ID
    "created_at" INTEGER NOT NULL,                -- 创建时间（Unix时间戳）
    "updated_at" INTEGER NOT NULL,                -- 最后更新时间（Unix时间戳）
    "deleted_at" INTEGER,                         -- 软删除时间（NULL表示未删除）
    FOREIGN KEY ("owner_user_id") REFERENCES "user" ("id")
);

-- 索引
CREATE INDEX IF NOT EXISTS "idx_ledger_owner" ON "ledger" ("owner_user_id");
CREATE INDEX IF NOT EXISTS "idx_ledger_deleted_at" ON "ledger" ("deleted_at");

-- ============================================================
-- 3. 账本成员表 (LedgerMember)
-- 说明：账本与用户的关联关系
-- ============================================================
CREATE TABLE IF NOT EXISTS "ledger_member" (
    "id" TEXT PRIMARY KEY,                        -- UUID主键
    "ledger_id" TEXT NOT NULL,                    -- 账本ID
    "user_id" TEXT NOT NULL,                      -- 用户ID
    "joined_at" INTEGER NOT NULL,                 -- 加入时间（Unix时间戳）
    "created_at" INTEGER NOT NULL,                -- 创建时间（Unix时间戳）
    "updated_at" INTEGER NOT NULL,                -- 最后更新时间（Unix时间戳）
    "deleted_at" INTEGER,                         -- 软删除时间（NULL表示未删除）
    FOREIGN KEY ("ledger_id") REFERENCES "ledger" ("id"),
    FOREIGN KEY ("user_id") REFERENCES "user" ("id")
);

-- 索引
CREATE INDEX IF NOT EXISTS "idx_ledger_member_ledger" ON "ledger_member" ("ledger_id");
CREATE INDEX IF NOT EXISTS "idx_ledger_member_user" ON "ledger_member" ("user_id");
CREATE INDEX IF NOT EXISTS "idx_ledger_member_deleted_at" ON "ledger_member" ("deleted_at");

-- 唯一约束：同一账本内同一用户不能重复加入
CREATE UNIQUE INDEX IF NOT EXISTS "idx_ledger_member_unique" ON "ledger_member" ("ledger_id", "user_id") WHERE "deleted_at" IS NULL;

-- ============================================================
-- 4. 购物单表 (ShoppingList)
-- 说明：一次购物或一张小票/截图的集合，包含多个账目
-- ============================================================
CREATE TABLE IF NOT EXISTS "shopping_list" (
    "id" TEXT PRIMARY KEY,                        -- UUID主键
    "ledger_id" TEXT NOT NULL,                    -- 所属账本ID
    "title" TEXT,                                 -- 购物单标题
    "merchant" TEXT,                              -- 商家名称
    "occurred_at" INTEGER NOT NULL,               -- 发生时间（Unix时间戳）
    "default_payer_id" TEXT,                      -- 默认付款人ID
    "default_participant_ids" TEXT,               -- 默认参与人ID列表（JSON格式）
    "note" TEXT,                                  -- 备注
    "source" TEXT NOT NULL DEFAULT 'manual',      -- 来源：manual=手动，ai=AI识别
    "created_at" INTEGER NOT NULL,                -- 创建时间（Unix时间戳）
    "updated_at" INTEGER NOT NULL,                -- 最后更新时间（Unix时间戳）
    "deleted_at" INTEGER,                         -- 软删除时间（NULL表示未删除）
    FOREIGN KEY ("ledger_id") REFERENCES "ledger" ("id"),
    FOREIGN KEY ("default_payer_id") REFERENCES "user" ("id")
);

-- 索引
CREATE INDEX IF NOT EXISTS "idx_shopping_list_ledger" ON "shopping_list" ("ledger_id");
CREATE INDEX IF NOT EXISTS "idx_shopping_list_occurred_at" ON "shopping_list" ("occurred_at");
CREATE INDEX IF NOT EXISTS "idx_shopping_list_deleted_at" ON "shopping_list" ("deleted_at");

-- ============================================================
-- 5. 账目/商品表 (ExpenseItem)
-- 说明：最小记账单位，也是分摊基本单位
-- ============================================================
CREATE TABLE IF NOT EXISTS "expense_item" (
    "id" TEXT PRIMARY KEY,                        -- UUID主键
    "shopping_list_id" TEXT NOT NULL,             -- 所属购物单ID
    "ledger_id" TEXT NOT NULL,                    -- 所属账本ID（冗余，便于查询）
    "name" TEXT NOT NULL,                         -- 商品/账目名称
    "quantity" INTEGER NOT NULL DEFAULT 1,        -- 数量
    "unit_price" INTEGER NOT NULL DEFAULT 0,      -- 单价（分）
    "final_amount" INTEGER NOT NULL,              -- 最终金额（分，已摊入折扣/附加费）
    "category_id" TEXT,                           -- 分类ID
    "payer_id" TEXT NOT NULL,                     -- 付款人/垫付人用户ID
    "split_type" TEXT NOT NULL DEFAULT 'equal',   -- 分摊方式：equal=均摊，ratio=按比例，amount=按金额
    "note" TEXT,                                  -- 备注
    "created_at" INTEGER NOT NULL,                -- 创建时间（Unix时间戳）
    "updated_at" INTEGER NOT NULL,                -- 最后更新时间（Unix时间戳）
    "deleted_at" INTEGER,                         -- 软删除时间（NULL表示未删除）
    FOREIGN KEY ("shopping_list_id") REFERENCES "shopping_list" ("id"),
    FOREIGN KEY ("ledger_id") REFERENCES "ledger" ("id"),
    FOREIGN KEY ("category_id") REFERENCES "category" ("id"),
    FOREIGN KEY ("payer_id") REFERENCES "user" ("id")
);

-- 索引
CREATE INDEX IF NOT EXISTS "idx_expense_item_shopping_list" ON "expense_item" ("shopping_list_id");
CREATE INDEX IF NOT EXISTS "idx_expense_item_ledger" ON "expense_item" ("ledger_id");
CREATE INDEX IF NOT EXISTS "idx_expense_item_payer" ON "expense_item" ("payer_id");
CREATE INDEX IF NOT EXISTS "idx_expense_item_category" ON "expense_item" ("category_id");
CREATE INDEX IF NOT EXISTS "idx_expense_item_deleted_at" ON "expense_item" ("deleted_at");

-- ============================================================
-- 6. 账目参与人表 (ItemParticipant)
-- 说明：记录每个账目的分摊参与人及分摊金额
-- ============================================================
CREATE TABLE IF NOT EXISTS "item_participant" (
    "id" TEXT PRIMARY KEY,                        -- UUID主键
    "expense_item_id" TEXT NOT NULL,              -- 关联账目ID
    "user_id" TEXT NOT NULL,                      -- 参与人用户ID
    "share_amount" INTEGER,                       -- 分摊金额（分），按金额/均摊时使用
    "ratio" REAL,                                 -- 分摊比例，按比例分摊时使用（如0.25表示25%）
    "is_included" INTEGER NOT NULL DEFAULT 1,     -- 是否参与分摊：1=参与，0=不参与
    "created_at" INTEGER NOT NULL,                -- 创建时间（Unix时间戳）
    "updated_at" INTEGER NOT NULL,                -- 最后更新时间（Unix时间戳）
    "deleted_at" INTEGER,                         -- 软删除时间（NULL表示未删除）
    FOREIGN KEY ("expense_item_id") REFERENCES "expense_item" ("id"),
    FOREIGN KEY ("user_id") REFERENCES "user" ("id")
);

-- 索引
CREATE INDEX IF NOT EXISTS "idx_item_participant_item" ON "item_participant" ("expense_item_id");
CREATE INDEX IF NOT EXISTS "idx_item_participant_user" ON "item_participant" ("user_id");
CREATE INDEX IF NOT EXISTS "idx_item_participant_deleted_at" ON "item_participant" ("deleted_at");

-- 唯一约束：同一账目内同一用户不能重复
CREATE UNIQUE INDEX IF NOT EXISTS "idx_item_participant_unique" ON "item_participant" ("expense_item_id", "user_id") WHERE "deleted_at" IS NULL;

-- ============================================================
-- 7. 转账/结算记录表 (Transfer / Settlement)
-- 说明：记录成员间资金转移，不计消费，只影响余额
-- ============================================================
CREATE TABLE IF NOT EXISTS "transfer" (
    "id" TEXT PRIMARY KEY,                        -- UUID主键
    "ledger_id" TEXT NOT NULL,                    -- 所属账本ID
    "from_user_id" TEXT NOT NULL,                 -- 付款方用户ID
    "to_user_id" TEXT NOT NULL,                   -- 收款方用户ID
    "amount" INTEGER NOT NULL,                    -- 转账金额（分）
    "occurred_at" INTEGER NOT NULL,               -- 转账时间（Unix时间戳）
    "note" TEXT,                                  -- 备注
    "created_at" INTEGER NOT NULL,                -- 创建时间（Unix时间戳）
    "updated_at" INTEGER NOT NULL,                -- 最后更新时间（Unix时间戳）
    "deleted_at" INTEGER,                         -- 软删除时间（NULL表示未删除）
    FOREIGN KEY ("ledger_id") REFERENCES "ledger" ("id"),
    FOREIGN KEY ("from_user_id") REFERENCES "user" ("id"),
    FOREIGN KEY ("to_user_id") REFERENCES "user" ("id")
);

-- 索引
CREATE INDEX IF NOT EXISTS "idx_transfer_ledger" ON "transfer" ("ledger_id");
CREATE INDEX IF NOT EXISTS "idx_transfer_from_user" ON "transfer" ("from_user_id");
CREATE INDEX IF NOT EXISTS "idx_transfer_to_user" ON "transfer" ("to_user_id");
CREATE INDEX IF NOT EXISTS "idx_transfer_occurred_at" ON "transfer" ("occurred_at");
CREATE INDEX IF NOT EXISTS "idx_transfer_deleted_at" ON "transfer" ("deleted_at");

-- ============================================================
-- 8. 分类表 (Category)
-- 说明：账目分类，系统预置+账本级自定义
-- ============================================================
CREATE TABLE IF NOT EXISTS "category" (
    "id" TEXT PRIMARY KEY,                        -- UUID主键
    "name" TEXT NOT NULL,                         -- 分类名称
    "icon" TEXT,                                  -- 分类图标
    "is_system" INTEGER NOT NULL DEFAULT 0,       -- 是否系统预置：1=系统预置，0=自定义
    "ledger_id" TEXT,                             -- 账本ID（NULL=全局预置分类，非NULL=账本级自定义分类）
    "archived_at" INTEGER,                        -- 归档时间（NULL=活跃，有值=已归档）
    "created_at" INTEGER NOT NULL,                -- 创建时间（Unix时间戳）
    "updated_at" INTEGER NOT NULL,                -- 最后更新时间（Unix时间戳）
    "deleted_at" INTEGER,                         -- 软删除时间（NULL表示未删除）
    FOREIGN KEY ("ledger_id") REFERENCES "ledger" ("id")
);

-- 索引
CREATE INDEX IF NOT EXISTS "idx_category_is_system" ON "category" ("is_system");
CREATE INDEX IF NOT EXISTS "idx_category_ledger" ON "category" ("ledger_id");
CREATE INDEX IF NOT EXISTS "idx_category_archived_at" ON "category" ("archived_at");
CREATE INDEX IF NOT EXISTS "idx_category_deleted_at" ON "category" ("deleted_at");

-- ============================================================
-- 9. 周期预算表 (Budget)
-- 说明：按自然月设置预算，统计"我的消费"
-- ============================================================
CREATE TABLE IF NOT EXISTS "budget" (
    "id" TEXT PRIMARY KEY,                        -- UUID主键
    "user_id" TEXT NOT NULL,                      -- 用户ID（预算所属者）
    "amount" INTEGER NOT NULL,                    -- 预算金额（分）
    "year" INTEGER NOT NULL,                      -- 年份（如2026）
    "month" INTEGER NOT NULL,                     -- 月份（1-12）
    "created_at" INTEGER NOT NULL,                -- 创建时间（Unix时间戳）
    "updated_at" INTEGER NOT NULL,                -- 最后更新时间（Unix时间戳）
    "deleted_at" INTEGER,                         -- 软删除时间（NULL表示未删除）
    FOREIGN KEY ("user_id") REFERENCES "user" ("id")
);

-- 索引
CREATE INDEX IF NOT EXISTS "idx_budget_user" ON "budget" ("user_id");
CREATE INDEX IF NOT EXISTS "idx_budget_year_month" ON "budget" ("year", "month");
CREATE INDEX IF NOT EXISTS "idx_budget_deleted_at" ON "budget" ("deleted_at");

-- 唯一约束：同一用户同一月份只能有一个预算
CREATE UNIQUE INDEX IF NOT EXISTS "idx_budget_unique" ON "budget" ("user_id", "year", "month") WHERE "deleted_at" IS NULL;
