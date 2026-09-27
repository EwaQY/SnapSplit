# P6 补充计划书：AI 接口调用层（Cline 兼容）

> 分支：`feature/backend-logic`（与 P0–P5 同分支，不 push）。
> 前置决策：Dart DTO 并轨（`paid_amount` 只存档，`total_discount` 进折扣数组）；
> 失败抛类型化异常并预留本地解析；Prompt 保持英文原版；
> 探针与 App 统一走 `flutter_dotenv`（实现时先验证 CLI 加载，结论如实汇报）。
> 门禁沿用主计划表：测试目的 + 内容先确认才可 commit；
> E2E 全绿 + 用户确认才可 PR（reviewer `XcantloadX`）。

## 1. 目标与非目标

* 目标：打通“图片 → Cline API → `AiReceiptDto` → `DraftShopping`”真实链路，
  并提供本地探针做人工冒烟。
* 非目标：UI 确认页、批量 9 张并发、本地 OCR 实现（只留接口）、
  prompt 中文化、重试策略 UI。

## 2. 配置与密钥文件

| 文件 | 动作 | 说明 |
|---|---|---|
| `src/app/.env.example` | 新建并提交 | `base_url`（默认 `https://api.cline.bot/api/v1`）/ `model_id` / `api_key` + 中文注释 + 用法说明 |
| `src/app/.env` | 新建空文件，用户填写 | **永不提交**；commit 前以文件清单为证 |
| `.gitignore`（根） | 加一行 `.env` | 与 `data/*.db` 同类本地文件，一处管理 |

* App 启动路径用 `flutter_dotenv` 加载；测试永不读 `.env`
  （`AiConfig.fromMap` 纯构造 + MockClient）。
* 探针同样走 `flutter_dotenv`；实现第一步先验证 `dart run` 下能否加载，
  若不行如实汇报并改方案（不擅自手写）。

## 3. 实现清单（`src/app/lib/src/features/ai_ingest/`）

| 文件 | 内容 |
|---|---|
| `domain/ai_prompt.dart` | `SYSTEM_PROMPT` 英文原文常量搬运（含实付关键词与 JSON 结构约束） |
| `domain/ai_receipt_dto.dart` | `AiReceiptItem` 加可空 `paidAmount`（存档备查，不参与计算）；其余不动，T5-1 不重写 |
| `data/ai_config.dart` | `AiConfig{baseUrl, modelId, apiKey}`：`fromMap` + `fromEnv()`；缺 key 在调用时抛 `AiException(missingKey)` |
| `data/ai_recognition_service.dart` | `AiRecognitionService({config, client?})`：`parseImageBytes(bytes, {mime, sourceImageIndex})` + `parseImageFile(file, ...)`；base64、10MB 先验、60s 超时、`temperature 0.1/max_tokens 2048`、`x-client-type: cline-cli` 头；`data.choices[0].message.content` 信封解析、去围栏、`jsonDecode`→`aiReceiptDtoFromPythonJson` 映射（含字符串数字兼容）；全路径抛 `AiException(network/badStatus/badPayload)` |
| `data/local_receipt_parser.dart` | `abstract class LocalReceiptParser` 空实现（恒 null，占 `source: local` 坑）；调用顺序：AI 抛错 → 本地解析 → 手动自填 |
| `core/errors/app_exception.dart` | 新增 `AiException(kind, message)` + `AiFailureKind{missingKey, network, badStatus, badPayload}` |
| `tool/ai_probe.dart` | 人工冒烟：`dart run tool/ai_probe.dart <图片> [--index N]` → 打印原始 JSON + 草稿明细 + 合计；退出码 0/2（缺配置）/3（API 失败）；图片只读不入库；可提交（无密钥逻辑） |

## 4. 映射口径（Python → Dart DTO）

* `items[].amount`（折扣前小计）→ 基数；`total_discount`（负）→
  `discounts: [{name: 'AI订单折扣', amount}]`，走现有按比例摊；
  `surcharges` 置空；`merchant`/`expense_date` 直映射；
  `paid_amount` 存档；`discount_model/subtotal/实付总额` 暂不消费。
* `quantity`/`unit_price`/`amount` 的字符串数字转 num（对标 `_coerce_types`）。

## 5. 测试 T6（全 mock，零网络零真实 key）

| # | 目的 | 内容 |
|---|---|---|
| T6-1 | 真实信封解析 | canned Cline envelope（order/item 各一）→ finals 正确；围栏变体；字符串数字兼容 |
| T6-2 | 类型化异常 | 缺 key / 500 / 超时 / 坏 envelope 各抛对应 kind |
| T6-3 | 门禁 | `analyze` 零问题 + `flutter test` 全绿（含回归） |

## 6. 提交

* `feat(p6)`：§3 实现 + 配置 + 探针。
* `test(p6)`：T6 测试 + 本文件落盘（`docs/plans/backend-p6-ai-plan.md`）。
* commit 前出示文件清单，证 `.env` 未在内；不 push。

## 7. 进展日志

| 日期 | 事项 | 结论 |
|---|---|---|
| 2026-09-26 | 实现+自编译 | dotenv 在 CLI 下不可用已验证，探针改手写解析（App 照走 dotenv）；3 个 import/插值编译错已修 |
| 2026-09-26 | T6 全绿（74 tests 含回归）+ analyze 零问题 | 修测试 Latin1 构造问题 1 个，实现零改动；用户已确认 |
| 2026-09-26 | fix(p6)×2：重试/数量校验/探针结果格式 | T6 补到 82 全绿；4 张真图冒烟（3 成功 1 拦截后小数链路打通）；结果文件放 data/probe_results（不提交） |
