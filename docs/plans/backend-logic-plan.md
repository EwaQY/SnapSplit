# SnapSplit 后端逻辑开发计划表

> 分支：`feature/backend-logic`（从 `main` 拉出，全量后端逻辑共用一个分支，不按模块分分支）。
> 基准：`docs/product.md V4.0`（业务）+ Dart 表类（`src/app/lib/src/core/database/tables/`，数据库唯一真相源）+ `docs/database/` 三脚本（已冻结为 v1 基线参考，定义见 §1.1）。
> 规范：`AGENTS.md` → `docs/prompts/flutter.md`。
> 策略：Dart 先行、UI 推迟；当前先在 Windows 本机开发，Dart 经 drift 直连本机 SQLite；完工后用冒烟 + E2E 验证，再接入 UI。
> 门禁：每个模块必须有对应 test；每个 test 的目的 + 内容必须先经用户确认，才可进行该模块 commit；最终冒烟通过 + E2E 全绿后，经用户确认才可提交 PR，PR 指定审批人为 `XcantloadX`。

## 1. 目标与约束

* 目标：用 Dart 完成 PRD V4.0 全量后端逻辑（drift 类型安全持久层 + 纯逻辑 + Repository + Riverpod 接线），不写页面 UI；所有 DB 访问优先异步实现（`async/await`，禁止阻塞同步调用）。
* 数据库真相源为 Dart 表类（`src/app/lib/src/core/database/tables/`，drift `@DriftDatabase` 注册），不再是 SQL 脚本：

### 1.1 数据库脚本定义（已冻结，仅作 v1 基线参考）

| 脚本 | 定位 | 用途 |
|---|---|---|
| `docs/database/schema.sql` | v1 建表语句快照（DDL V3.0，含表 + 索引 + 唯一约束） | 冻结参考 + drift 等价性测试的 oracle；不再作为建库依据，不进 App 包 |
| `docs/database/seed.sql` | v1 测试数据快照（DML） | 仅作行数参考（user 4 / tag 10 / ledger 2 / item 8 等）；测试数据一律用 drift companions 自插，不执行本脚本 |
| `docs/database/drop.sql` | v1 删表脚本快照 | 冻结参考；开发期重置改用删库文件 / `NativeDatabase.memory()` 重建；真机禁用 |

### 1.2 Windows 本机双库策略（drift 创建）

* 当前开发在 Windows 本机进行，不直连提交库 `data/snapsplit.db` 做写操作（该库只读，兼等价性 oracle）。
* `test` / `dev` 双库均由 drift 创建（均 gitignored，不提交）：
  * `data/snapsplit_test.db`：测试库，drift `onCreate` 建表 + 自插 fixtures，用于各模块单测 / E2E。
  * `data/snapsplit_dev.db`：开发库，同上建空库 + 手动写入，用于联调时连接测试。
* 连接方式：`drift_flutter` 的 `driftDatabase()`（ffi，Win/Android 统一）；单测用 drift `NativeDatabase.memory()`。`sqflite` 系依赖已移除（drift 不走 sqflite 通道，二者是两套驱动，留着是死依赖）。
* 通用约束：
  * 金额以“分”（INTEGER）存储，展示转“元”；时间以 Unix 秒（INTEGER）存储；drift 表类中一律用 `IntColumn`（`is_self` 亦用 `IntColumn`，`BoolColumn` 会多 CHECK 约束，破坏等价）。
  * `quantity × unit_price` 与 `final_amount` 冲突时以 `final_amount` 为准；分摊以 `final_amount` 为准。
  * 查询默认过滤 `deleted_at IS NULL`；外键无级联子句（NO ACTION），级联由应用层同事务完成；4 个 partial 唯一索引 + 其余普通索引按 `schema.sql` 原文经 `customStatement` 创建（索引名保留）。
  * drift 生成文件（`*.g.dart` / `*.drift.dart`）必须提交（CI 不跑 codegen）；改表后执行 `dart run build_runner build --delete-conflicting-outputs` 并连同产物 commit。
  * `freezed` 领域模型，`sealed` 错误类型，`Riverpod 3.x` 接线，`logger`/`debugPrint`（禁 `print`），无无理由 `!` 断言，UI 禁直连 DB。

## 2. 模块计划总表

| # | 模块 | 范围（PRD 章节 / 表） | 提示词要点 | 验收要求 | 状态 |
|---|---|---|---|---|---|
| P0 | drift 基座 | drift 依赖 + 10 张 Dart 表类 + `AppDatabase(@DriftDatabase)` + 迁移策略（`createAll` + 原文索引 + 外键 ON）/ `AppException(sealed)` / 金额·时间·UUID 工具 | 表类 `tableName` 锁定原名；主键 TEXT；时间/金额 `IntColumn` | 等价性测试语义全对比通过 + `flutter analyze` 零警告 | 已完成 |
| P1 | user / ledger / member | PRD §5.1/5.2/6.1–6.3；表 `user, ledger, ledger_member`：`ensureSelf` 首次建我、改昵称头像、建账本（我自动进成员）、虚拟人增改软删 | 历史账目保留已删成员引用并显示“已删除成员”；`ledger_member(ledger_id,user_id)` 唯一 | 内存库单测：建我幂等、成员唯一约束、软删过滤 | 已完成 |
| P2 | shopping / expense / split | PRD §5.3/5.4/5.6/6.4–6.6；表 `shopping_list, expense_item, item_participant`：单账目降维建单（写 `default_payer/participant_ids` 快照）、多账目建单、编辑恢复快照、删除同事务软删子（`expense_item` + `item_participant`）并硬删 `item_tag`；`SplitCalc` 支持均摊/比例/金额，余数优先垫付人否则最大份额者，`sum == final`，参与人 ≥ 1，付款人可不在参与人内 | 纯函数放 domain，无 DB 依赖 | seed 真数断言：`ei-007 3500 分 → 4 × 875`；级联删断言；`sum == final` 恒成立 | 已完成 |
| P3 | surcharge / tag / budget / period | PRD §6.7/6.8/6.12/6.14–6.15；`surcharge` 按原始金额比例摊入（四舍五入、差额给最大商品，单商品直接计入，不持久化中间字段）；表 `tag, item_tag` 全局共享、新建改名归档（`archived_at`），归档后新单不可选、历史引用保留，`item_tag` 无软删随账目硬删；表 `budget` 自然月全局粒度、`我作 payer 求和 / 预算`、超支仅警告；`isArchived` 历史周期抛 `ArchivedReadOnly` 禁写 | UI 仅归档不删除标签 | 归档/禁写/预算进度单测绿 | 已完成 |
| P4 | transfer / settlement / timeline | PRD §5.7/6.9–6.11；表 `transfer`：任意成员互转（默认我 → 对方）、不计消费只冲余额、仅当期可改删；`calcBoard` 输出我视角两两净额 + 全局应收/应付（不做最优转账）；timeline 按 `occurred_at` 倒序、单账目降维、多商品 ≤ 5 全展、> 5 前 3–4 +“共 N 项”、转账同层独立、历史标“已归档” | 结算为只读聚合，不写库 | 结算 → 转账 → 余额归零断言；时间线快照断言 | 已完成 |
| P5 | ai_ingest + providers + e2e | PRD §5.5/6.5/6.13/§9；`AiReceiptDto{merchant,date,items[],surcharges[],discounts[]}` 解析 → `surcharge` 算 `final` → 待确认单（一图一单）→ 复用 P2 落库；不存原图，失败重试/跳过/转手动；`source=manual/ai/local` 保留；Riverpod `AsyncNotifier<AsyncValue>` 接线备 UI 用 | AI DTO 为纯解析，不调网络（网络后续接） | `test/e2e/full_loop_test.dart` 全绿：`建我→建账本→加2人→单账目→多账目含折扣→AI两单确认→时间线→结算→转账归零→预算→上月只读→删单级联` | 已完成 |
| P7 | 日志审计 | 全 Repository 写入口 `audit`（成功 info/失败 error 原样抛）；单文件 `app.log` + 启动清 5 天前 + 5MB 截尾；`main` 全局捕获；文件落盘不走网络 | 读操作不记；阈值常量可调 | T8 全绿 + 全量回归 | 已完成 |

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
  * `遵 AGENTS.md → docs/prompts/flutter.md（Riverpod 3.x / freezed / sealed / 无 print / 无无理由 ! / Repository SSOT / UI 禁直连 DB），业务以 docs/product.md V4.0 为准，表结构以 src/app/lib/src/core/database/tables/ 下 Dart 表类为准（docs/database/*.sql 已冻结只读），不写页面 UI，只交 Dart 逻辑 + 单测，经 drift 直连 SQLite。`
* 各模块提示词 = 通用前置 + §2 对应行“提示词要点”句，转为指令执行。
* 每模块交付物：`lib/src/...` 逻辑代码（含 drift 产物 `*.g.dart`）+ `test/...` 单测 + 本表状态更新；禁止顺手改表语义、禁止写 UI 页面；改表类后必须重跑 codegen 并验证等价性测试。

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
| 2026-09-25 | 决策 | — | 切纯 Dart Table 类 + 语义等价；seed 自插；移除 sqflite 系；旧 sqflite 版 P0（未 commit）作废 |
| 2026-09-26 | P0 | feat(p0)+test(p0) | T0-1~T0-6 全绿（19 tests）+ analyze 零问题，用户已确认测试方案与结果 |
| 2026-09-26 | P1 | feat(p1)+test(p1) | T1-1~T1-5 全绿（30 tests 含回归）+ analyze 零问题，用户已确认测试方案与结果 |
| 2026-09-26 | P2 | feat(p2)+test(p2) | T2-1~T2-6 全绿（44 tests 含回归）+ analyze 零问题，余数口径（并列取首位）已确认；修成员校验排序bug |
| 2026-09-26 | P3 | feat(p3)+test(p3) | T3-1~T3-4 全绿（53 tests 含回归）+ analyze 零问题，实现零返工 |
| 2026-09-26 | P4 | feat(p4)+test(p4) | T4-1~T4-4 全绿（61 tests 含回归）+ analyze 零问题；3 次测试算术错已纠正，实现未动 |
| 2026-09-26 | P5 | feat(p5)+test(p5) | T5-1~T5-4 全绿（67 tests 含回归）+ analyze 零问题；riverpod_generator与drift不兼容改手写providers |
| 2026-09-27 | P6 | feat(p6)+test(p6)+fix(p6)×2 | T6 全绿 + AI 真图冒烟；Cline 兼容调用层，重试与数量校验 |
| 2026-09-27 | schema-v2 | feat+test | 数量 REAL + 迁移 v2 + prompt 归一化；T7 全绿（81 tests） |
| 2026-09-27 | P7 | feat(p7)+test(p7) | T8 全绿（86 tests 含回归）+ analyze 零问题；17 个写入口审计埋点 |
| 2026-09-26 | P6 | feat(p6)+test(p6)+fix(p6) | T6 全绿（78 tests 含回归）+ analyze 零问题；Cline 兼容调用层，重试 1 次，4 张真图冒烟 3 成功 1 拦截 |

## 7. 数量列 INTEGER→REAL 切换（schema-v2）

* 原因：称重商品数量为小数（c921 的 0.32 公斤），INTEGER 装不下；
  钱继续分 + 整数不动（分摊/结算/预算只认 `final_amount`，零影响）。
* 冻结红线：`docs/database/*.sql` 一字不动（v1 快照/oracle）；
  `docs/product.md` 仅改数量描述一行（整数→支持小数）。
* 范围：表类 `quantity IntColumn→RealColumn` + `schemaVersion 2` +
  迁移（建新表→导数→删旧→改名，SQLite 无 ALTER COLUMN）；
  等价性测试 quantity 期望改 REAL；
  `DraftItem.quantity` int→double；AI 映射去 `toInt()`；
  c921 校验 `<1` 改 `<=0`；fixtures 加 0.32 用例。
* 回滚：迁移前老库文件保留（dev 双库重建即可，gitignored 无风险）。
* 结论（2026-09-26）：T7 全绿（81 tests）+ analyze 零问题；prompt 由 AI 归一化数量（称重小数/件数回填/缺省 1），不加 pieces 字段。
