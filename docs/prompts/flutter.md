# Flutter 代码规范

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119.

## 覆盖规则

总体代码规范依照 Dart 官方风格与 Flutter 官方架构指南。**严格 MUST** 按照如下顺序覆盖：

用户提示词要求 > 本规范要求 > `flutter_lints` / `dart format` 要求

## Dart 语言与类型

- 启用 sound null safety，**禁止 MUST NOT** 无理由使用 `!` 断言。延迟初始化**应当 SHOULD** 用 `late` + 明确初始化路径，或改为可空类型。
- 变量**优先 RECOMMENDED** 用 `final`，编译期常量**必须 MUST** 用 `const`。集合与模型**优先 RECOMMENDED** 不可变（`freezed` / `built_value` 或 `const` 构造）。
- 公开 API **必须 MUST** 声明返回类型与参数类型。**避免 SHOULD NOT** 使用 `dynamic` / 裸 `Object` 作为类型标注，JSON 解析后**必须 MUST** 立即转为强类型模型。
- 多返回值**优先 RECOMMENDED** 用 record / 小对象，而不是裸 `Map` / `List`。
- 状态建模**优先 RECOMMENDED** 用 `sealed class` + 模式匹配表达 loading / data / error，不用布尔组合拳。
- **禁止 MUST NOT** 使用 `print()` 输出日志，调试输出用 `debugPrint`，线上用 `logger`。
- 字符串拼接**应当 SHOULD** 用插值，循环拼接用 `StringBuffer`。
- 异步空隙后的 `BuildContext` 使用**必须 MUST** 先检查 `mounted` / `context.mounted`。

## 命名与文件

- 类、枚举、typedef、extension **必须 MUST** 用 `UpperCamelCase`；变量、函数、参数 **必须 MUST** 用 `lowerCamelCase`；库、包、文件、目录 **必须 MUST** 用 `lowercase_with_underscores`。
- 文件名**应当 SHOULD** 与其主要类 / 功能同名， barrel 文件**应当 SHOULD** 只做转发放行，不做逻辑。
- 私有成员以 `_` 前缀，顶层常量用 `lowerCamelCase` 或 `SCREAMING_CAPS` 二选一并在包内保持一致。

## Widget 架构

- 可复用 UI 片段**必须 MUST** 写成小 `StatelessWidget` / `StatefulWidget`，**禁止 MUST NOT** 用返回 Widget 的普通 helper 方法代替。`build()` 过长（经验值 ~100 行）**应当 SHOULD** 按变化频率拆分。
- 能加 `const` 的 Widget 与构造**必须 MUST** 加 `const`，集合字面量同理。
- 临时 UI 状态放 `StatefulWidget` 内部，全局 / 跨页状态**应当 SHOULD** 上提到状态管理，不在 `build()` 里放业务逻辑与副作用。
- `setState()` **必须 MUST** 下沉到实际变化的最小子树，**禁止 MUST NOT** 在根部高频调用。动画无关子树**必须 MUST** 作为 `child` 传入 `AnimatedBuilder`，不在 `builder` 内重建。
- 列表项有状态或可重排时**应当 SHOULD** 显式传 `key`。

## 状态管理

- 区分 ephemeral（输入框、Tab、动画控制器）与 app state，前者用 `setState` 即可，后者**应当 SHOULD** 用统一方案。
- 新代码**优先 RECOMMENDED** `Riverpod 3.x`（`Notifier` / `AsyncNotifier` + `riverpod_generator` 代码生成）；大团队 / 强审计场景**可 MAY** 用 `Bloc`（event -> state）。**禁止 MUST NOT** 在同一包内混用多套全局方案。
- 已废弃的 `StateProvider` / `StateNotifier` / `ChangeNotifier` 式写法**不应该 SHOULD NOT** 在新代码中出现。
- 异步状态**应当 SHOULD** 用 `AsyncValue`（data / loading / error）显式表达，**禁止 MUST NOT** 用空值 + 隐式 loading 糊弄 UI。
- UI 层**禁止 MUST NOT** 直连数据源，全局单例**禁止 MUST NOT** 被 Widget 直接读取，通过 provider / repository 注入以便测试替换。

## 分层与数据

- **应当 SHOULD** 按 UI 层 / 领域层（可选）/ 数据层分层，相邻层单向依赖，UI **禁止 MUST NOT** 直调网络 / 数据库实现。
- 每种可变数据**应当 SHOULD** 只有一个 `Repository` 作为单一数据源（SSOT），状态向下流、事件向上流（UDF）。
- 网络 / 存储 / 解析失败**必须 MUST** 转为显式错误类型向上抛，不吞异常，不返回魔术值。

## 布局与主题

- 颜色、字号、间距**必须 MUST** 走 `Theme.of` / `TextTheme` / `ColorScheme`，**禁止 MUST NOT** 在业务 Widget 里硬编码色值与文本样式，保证亮 / 暗主题可用。
- 尺寸适配**应当 SHOULD** 用 `MediaQuery` / `LayoutBuilder` / 自适应断点，**避免 SHOULD NOT** 写死大屏 / 小屏像素。
- 图片**应当 SHOULD** 配占位符与预缓存，长列表**必须 MUST** 用 `ListView.builder` / `GridView.builder` / sliver 懒加载。

## 性能

- `build()` 内**禁止 MUST NOT** 放重复昂贵计算，排序 / 过滤**应当 SHOULD** 用 `select` / memo / provider 缓存。
- 动画中**避免 SHOULD NOT** 用 `Opacity` / `saveLayer` / `Clip`，淡入用 `AnimatedOpacity` / `FadeInImage`，能预裁剪先裁剪。
- 避免整树 `watch`，只订阅最小片段；高频流**应当 SHOULD** 节流 / 去抖 / 分页。

## 资源与生命周期

- `Controller` / `FocusNode` / `AnimationController` / `StreamSubscription` **必须 MUST** 在 `dispose()` 释放。
- 未处理的 `Future` **不应该 SHOULD NOT** 悬空，fire-and-forget **必须 MUST** 显式处理错误。
- 大 JSON 解析与重计算**应当 SHOULD** 放 isolate / 后台，避免卡 UI 线程。

## Docstring 与注释

- 注释与文档**应 SHOULD** 以精炼的中文编写。
- 公开 Widget / 方法**强烈建议 RECOMMENDED** 用 `///` 写用途、参数、副作用，**不要 SHOULD NOT** 复述类型签名里已有的信息。
- 注释只写代码说不出的 why（非显而易见约束、上游 workaround、易误解原因），**禁止 MUST NOT** 逐行复述、记录变更历史、提交注释掉的代码。
- 重构 / 移动代码时**应该 SHOULD** 保留有效注释，逻辑变化时**必须 MUST** 同步更新。

## 测试

- 纯逻辑**推荐 RECOMMENDED** 写单元测试，关键交互**推荐 RECOMMENDED** 写 widget 测试，用 `Arrange-Act-Assert` 与语义化命名。
- 可测试性优先于简写：依赖注入优于全局直引，纯函数优于隐式状态。
