-- ============================================================
-- SnapSplit Drop All Tables
-- 说明：一次性删除所有表（谨慎使用！）
-- ============================================================

-- 禁用外键约束，避免删除顺序问题
PRAGMA foreign_keys = OFF;

-- 删除所有表
DROP TABLE IF EXISTS "item_participant";
DROP TABLE IF EXISTS "expense_item";
DROP TABLE IF EXISTS "shopping_list";
DROP TABLE IF EXISTS "transfer";
DROP TABLE IF EXISTS "ledger_member";
DROP TABLE IF EXISTS "budget";
DROP TABLE IF EXISTS "category";
DROP TABLE IF EXISTS "ledger";
DROP TABLE IF EXISTS "user";
DROP TABLE IF EXISTS "schema_meta";

-- 重新启用外键约束
PRAGMA foreign_keys = ON;
