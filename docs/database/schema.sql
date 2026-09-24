-- ============================================================
-- SnapSplit SQLite Database Schema
-- Version: 3.0
-- Based on PRD V4.0
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
    "default_payer_id" TEXT,                      -- 默认付款人ID：用户最后确认的Header默认付款人快照
    "default_participant_ids" TEXT,               -- 默认参与人ID列表（JSON格式）：用户最后确认的Header默认参与人快照，创建/编辑保存时写入，加新行/批量应用时读取
    "note" TEXT,                                  -- 备注
    "source" TEXT NOT NULL DEFAULT 'manual',      -- 来源：manual=手动，ai=AI在线解析，local=本地解析
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
    "payer_id" TEXT NOT NULL,                     -- 付款人/垫付人用户ID
    "note" TEXT,                                  -- 备注
    "created_at" INTEGER NOT NULL,                -- 创建时间（Unix时间戳）
    "updated_at" INTEGER NOT NULL,                -- 最后更新时间（Unix时间戳）
    "deleted_at" INTEGER,                         -- 软删除时间（NULL表示未删除）
    FOREIGN KEY ("shopping_list_id") REFERENCES "shopping_list" ("id"),
    FOREIGN KEY ("ledger_id") REFERENCES "ledger" ("id"),
    FOREIGN KEY ("payer_id") REFERENCES "user" ("id")
);

-- 索引
CREATE INDEX IF NOT EXISTS "idx_expense_item_shopping_list" ON "expense_item" ("shopping_list_id");
CREATE INDEX IF NOT EXISTS "idx_expense_item_ledger" ON "expense_item" ("ledger_id");
CREATE INDEX IF NOT EXISTS "idx_expense_item_payer" ON "expense_item" ("payer_id");
CREATE INDEX IF NOT EXISTS "idx_expense_item_deleted_at" ON "expense_item" ("deleted_at");

-- ============================================================
-- 6. 账目参与人表 (ItemParticipant)
-- 说明：记录每个账目的分摊参与人及分摊金额
-- ============================================================
CREATE TABLE IF NOT EXISTS "item_participant" (
    "id" TEXT PRIMARY KEY,                        -- UUID主键
    "expense_item_id" TEXT NOT NULL,              -- 关联账目ID
    "user_id" TEXT NOT NULL,                      -- 参与人用户ID
    "share_amount" INTEGER NOT NULL,              -- 具体分摊金额（分）：所有分摊方式保存时统一计算
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
-- 8. 标签表 (Tag)
-- 说明：账目标签，全局共享，支持归档
-- ============================================================
CREATE TABLE IF NOT EXISTS "tag" (
    "id" TEXT PRIMARY KEY,                        -- UUID主键
    "name" TEXT NOT NULL,                         -- 标签名称
    "icon" TEXT,                                  -- 标签图标
    "archived_at" INTEGER,                        -- 归档时间（NULL=活跃，有值=已归档）
    "created_at" INTEGER NOT NULL,                -- 创建时间（Unix时间戳）
    "updated_at" INTEGER NOT NULL,                -- 最后更新时间（Unix时间戳）
    "deleted_at" INTEGER                          -- 软删除时间（NULL表示未删除）
);

-- 索引
CREATE INDEX IF NOT EXISTS "idx_tag_archived_at" ON "tag" ("archived_at");
CREATE INDEX IF NOT EXISTS "idx_tag_deleted_at" ON "tag" ("deleted_at");

-- 唯一约束：标签名全局唯一（软删除后可重建同名；已归档的同名需先取消归档）
CREATE UNIQUE INDEX IF NOT EXISTS "idx_tag_name_unique" ON "tag" ("name") WHERE "deleted_at" IS NULL;

-- ============================================================
-- 9. 账目-标签关联表 (ItemTag)
-- 说明：账目与标签的多对多关联；无软删除字段，账目软删除时应用层在同一事务内硬删除关联行
-- ============================================================
CREATE TABLE IF NOT EXISTS "item_tag" (
    "id" TEXT PRIMARY KEY,                        -- UUID主键
    "expense_item_id" TEXT NOT NULL,              -- 关联账目ID
    "tag_id" TEXT NOT NULL,                       -- 关联标签ID
    "created_at" INTEGER NOT NULL,                -- 创建时间（Unix时间戳）
    FOREIGN KEY ("expense_item_id") REFERENCES "expense_item" ("id"),
    FOREIGN KEY ("tag_id") REFERENCES "tag" ("id")
);

-- 索引
CREATE INDEX IF NOT EXISTS "idx_item_tag_item" ON "item_tag" ("expense_item_id");
CREATE INDEX IF NOT EXISTS "idx_item_tag_tag" ON "item_tag" ("tag_id");

-- 唯一约束：同一账目不能重复打同一标签
CREATE UNIQUE INDEX IF NOT EXISTS "idx_item_tag_unique" ON "item_tag" ("expense_item_id", "tag_id");

-- ============================================================
-- 10. 周期预算表 (Budget)
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
