# SnapSplit 后端逻辑开发计划表

> 分支：`feature/backend-logic`（从 `main` 拉出，全量后端逻辑共用一个分支，不按模块分分支）。
> 基准：`docs/product.md V4.0`（业务）+ `docs/database/` 下三脚本（定义见 §1.1）。
> 规范：`AGENTS.md` → `docs/prompts/flutter.md`。
> 策略：Dart 先行、UI 推迟；当前先在 Windows 本机开发，Dart 直连本机 SQLite；完工后用冒烟 + E2E 验证，再接入 UI。
> 门禁：每个模块必须有对应 test；每个 test 的目的 + 内容必须先经用户确认，才可进行该模块 commit；最终冒烟通过 + E2E 全绿后，经用户确认才可提交 PR，PR 指定审批人为 `XcantloadX`。

## 1. 目标与约束

* 目标：用 Dart 完成 PRD V4.0 全量后端逻辑（纯逻辑 + Repository + Riverpod 接线），不写页面 UI；所有 DB 访问优先异步实现（`async/await`，禁止阻塞同步调用）。
* 建表脚本已完成，本任务不再新建/修改表结构：

### 1.1 数据库脚本定义（唯一口径）

| 脚本 | 定位 | 用途 |
|---|---|---|
| `docs/database/schema.sql` | 完整的建表语句（DDL，V3.0，含表 + 索引 + 唯一约束） | 新建库的唯一依据；`test` / `dev` 双库均由此脚本建立 |
| `docs/database/seed.sql` | 插入数据（DML 测试数据） | 仅用于 `test` 库灌入 determinstic 测试数据；不进真机包 |
| `docs/database/drop.sql` | 删表脚本 | 仅开发期重置 `test` / `dev` 库使用；真机禁用 |

### 1.2 Windows 本机双库策略（连接测试用）

* 当前开发在 Windows 本机进行，不直连提交库 `data/snapsplit.db` 做写操作（该库只读参照）。
* 用 `schema.sql` 分别建立两个新的本地库（均 gitignored，不提交）：
  * `data/snapsplit_test.db`：测试库，每次可 `drop.sql → schema.sql → seed.sql` 重建，用于各模块单测 / E2E。
  * `data/snapsplit_dev.db`：开发库，`schema.sql` 建空库 + 手动/脚本写入，用于联调时连接测试。
* 连接方式：`sqflite_common_ffi`（`databaseFactoryFfi`），真机 Android 切回 `sqflite` 默认 factory + `path_provider` 沙盒路径（P0 用抽象隔离）。
* 通用约束：
  * 金额以“分”（INTEGER）存储，展示转“元”；时间以 Unix 秒（INTEGER）存储。
  * `quantity × unit_price` 与 `final_amount` 冲突时以 `final_amount` 为准；分摊以 `final_amount` 为准。
  * 查询默认过滤 `deleted_at IS NULL`；外键 `NO ACTION`，级联由应用层同事务完成。
  * `freezed` 强类型模型，`sealed` 错误类型，`Riverpod 3.x` 接线，`logger`/`debugPrint`（禁 `print`），无无理由 `!` 断言，UI 禁直连 DB。

## 2. 模块计划总表

| # | 模块 | 范围（PRD 章节 / 表） | 提示词要点 | 验收要求 | 状态 |
|---|---|---|---|---|---|
| P0 | infra 基座 | DB 打开/事务 helper / `AppException(sealed)` / 金额·时间·UUID 工具 / `assets/db/schema.sql` 复用（只拷贝，不改结构） | 复用 schema.sql 为 asset；`PRAGMA foreign_keys=ON`；ffi 只读 seed 验证 | `flutter analyze` 零警告；ffi 只读打开 `data/snapsplit.db` 成功 | 待施工 |
| P1 | user / ledger / member | PRD §5.1/5.2/6.1–6.3；表 `user, ledger, ledger_member`：`ensureSelf` 首次建我、改昵称头像、建账本（我自动进成员）、虚拟人增改软删 | 历史账目保留已删成员引用并显示“已删除成员”；`ledger_member(ledger_id,user_id)` 唯一 | 内存库单测：建我幂等、成员唯一约束、软删过滤 | 待施工 |
| P2 | shopping / expense / split | PRD §5.3/5.4/5.6/6.4–6.6；表 `shopping_list, expense_item, item_participant`：单账目降维建单（写 `default_payer/participant_ids` 快照）、多账目建单、编辑恢复快照、删除同事务软删子（`expense_item` + `item_participant`）并硬删 `item_tag`；`SplitCalc` 支持均摊/比例/金额，余数优先垫付人否则最大份额者，`sum == final`，参与人 ≥ 1，付款人可不在参与人内 | 纯函数放 domain，无 DB 依赖 | seed 真数断言：`ei-007 3500 分 → 4 × 875`；级联删断言；`sum == final` 恒成立 | 待施工 |
| P3 | surcharge / tag / budget / period | PRD §6.7/6.8/6.12/6.14–6.15；`surcharge` 按原始金额比例摊入（四舍五入、差额给最大商品，单商品直接计入，不持久化中间字段）；表 `tag, item_tag` 全局共享、新建改名归档（`archived_at`），归档后新单不可选、历史引用保留，`item_tag` 无软删随账目硬删；表 `budget` 自然月全局粒度、`我作 payer 求和 / 预算`、超支仅警告；`isArchived` 历史周期抛 `ArchivedReadOnly` 禁写 | UI 仅归档不删除标签 | 归档/禁写/预算进度单测绿 | 待施工 |
| P4 | transfer / settlement / timeline | PRD §5.7/6.9–6.11；表 `transfer`：任意成员互转（默认我 → 对方）、不计消费只冲余额、仅当期可改删；`calcBoard` 输出我视角两两净额 + 全局应收/应付（不做最优转账）；timeline 按 `occurred_at` 倒序、单账目降维、多商品 ≤ 5 全展、> 5 前 3–4 +“共 N 项”、转账同层独立、历史标“已归档” | 结算为只读聚合，不写库 | 结算 → 转账 → 余额归零断言；时间线快照断言 | 待施工 |
| P5 | ai_ingest + providers + e2e | PRD §5.5/6.5/6.13/§9；`AiReceiptDto{merchant,date,items[],surcharges[],discounts[]}` 解析 → `surcharge` 算 `final` → 待确认单（一图一单）→ 复用 P2 落库；不存原图，失败重试/跳过/转手动；`source=manual/ai/local` 保留；Riverpod `AsyncNotifier<AsyncValue>` 接线备 UI 用 | AI DTO 为纯解析，不调网络（网络后续接） | `test/e2e/full_loop_test.dart` 全绿：`建我→建账本→加2人→单账目→多账目含折扣→AI两单确认→时间线→结算→转账归零→预算→上月只读→删单级联` | 待施工 |

## 3. 分支、提交与测试门禁规范

* 统一分支：`feature/backend-logic`，从 `main` 拉出；施工期间按需 `rebase main`。
* 不按模块分分支；一个模块 1–N 个 commit，commit 前缀模块号，例如：
  * `feat(p0): app database open + tx helper`
  * `feat(p2): shopping repo cascade soft delete`
  * `test(p2): split calculator seed asserts`
* 测试门禁（硬性）：
  * 每个模块完成后必须有对应的 test（单元测试和/或集成测试，见 §2 验收要求列）。
  * 每个测试在编写/执行前，必须先向用户提交「测试目的 + 测试内容」，经用户确认后，才可以进行该模块的 commit。
  * 本计划表 §6 进展日志同步记录每次「测试确认」结论。
* 完工与 PR 门禁：
  * 全模块完成后，先跑冒烟测试（smoke：双库可建连 + 全表 CRUD 走通 + 时间线/结算最小链路），再跑 E2E 全绿。
  * 冒烟 + E2E 全绿后，由用户确认，才可以提交 PR（`feature/backend-logic` → `main`）。
  * PR 必须指定审批人（reviewer）为 `XcantloadX`，并通过 `.github/workflows/flutter-ci.yml`（analyze + test + debug APK）。

## 4. 通用提示词与执行要求

* 通用前置（每模块开工复制使用）：
  * `遵 AGENTS.md → docs/prompts/flutter.md（Riverpod 3.x / freezed / sealed / 无 print / 无无理由 ! / Repository SSOT / UI 禁直连 DB），业务以 docs/product.md V4.0 为准，表结构以 docs/database/schema.sql V3.0 为准（只用不改），不写页面 UI，只交 Dart 逻辑 + 单测，直连 sqflite。`
* 各模块提示词 = 通用前置 + §2 对应行“提示词要点”句，转为指令执行。
* 每模块交付物：`lib/src/...` 逻辑代码 + `test/...` 单测 + 本表状态更新；禁止顺手改表结构、禁止写 UI 页面。

## 5. 闭环验证清单（P5 执行，PR 前置）

* [ ] `flutter analyze` 零警告。
* [ ] 各模块 test 全绿（均已逐个经用户确认目的 + 内容后 commit）。
* [ ] 冒烟测试通过（§3 定义）。
* [ ] `flutter test` 全绿（含 `test/e2e/full_loop_test.dart` 上述全链路）。
* [ ] seed 真数抽查通过（多标签、均摊余数、降维、归档禁写、余额归零）。
* [ ] 经用户确认后提交 PR（reviewer `XcantloadX`），PR CI（analyze / test / build debug APK）通过。

## 6. 进展日志（施工后追加，不重写历史）

| 日期 | 模块 | commit | 结论 |
|---|---|---|---|
| — | — | — | 待施工，本文档待验收 |
