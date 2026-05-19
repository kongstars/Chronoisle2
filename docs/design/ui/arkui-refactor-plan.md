# Chronoisle ArkUI 组件拆分清单、命名建议与改造顺序

更新时间：2026-04-19

适用对象：前端、客户端负责人、测试

关联文档：

- [精致效率 UI 风格规范](</docs/design/ui/ui-style-guide-efficiency.md>)
- [深浅色主题 Token 规范](</docs/design/ui/theme-token-spec.md>)
- [视觉 Token 与组件外观规范](</docs/design/ui/ui-visual-token-spec.md>)

## 1. 文档目标

本文档用于指导主端 ArkUI 改造的工程落地，目标是：

- 把当前按页面堆叠的实现，逐步重构为可复用的组件体系。
- 让主题、状态、AI 流程、会员配额、同步反馈形成统一模式。
- 在不一次性推翻现有页面的前提下，支持分阶段改造与回归测试。

## 2. 当前代码面的主要问题

### 2.1 主题系统未真正下沉

当前已有：

- `common/AppStyle.ets`
- `theme/AppTheme.ets`
- `services/ThemeService.ets`

但实际页面中仍大量使用硬编码颜色、边框、阴影和卡片样式，导致：

- 暗色模式一致性不够
- 新页面很难复用视觉规范
- 会员、风险、AI 状态无法形成统一语义色
- 深色模式和浅色模式缺少统一验收口径

### 2.2 页面职责偏重，组件职责偏轻

当前问题：

- `TodayTab` 同时承担搜索、倒计时、提醒、计划等多块 UI。
- `MeTab` 既处理数据初始化又渲染多个不同业务分区。
- `TaskListTab` 还是以纯页面拼装为主，缺少可复用列表单元。

### 2.3 AI 交互没有统一容器

当前问题：

- 目标规划有多阶段状态机，但页面表达仍是单页内分支。
- 今日计划和重排尚未形成统一的“预览 -> 采纳 -> 落地”模式。
- 语音创建有 Overlay，但与其他 AI 能力的状态表达不统一。

### 2.4 系统级状态没有统一出口

当前问题：

- `TelemetryService` 设计完成，但生命周期未完整接线。
- `CloudSyncService` 已接线，但成功/失败状态仅部分页面可见。
- 公告系统尚无全局容器。

## 3. 改造原则

### 3.1 分层原则

组件按四层组织：

1. `foundation`：主题、token、图标、常量、通用类型
2. `base`：按钮、卡片、标签、列表行、空状态等基础 UI
3. `blocks`：页面内可组合模块，如首页 Hero、会员卡、同步卡
4. `features`：和业务能力强绑定的容器，如今日计划面板、重排面板、目标规划流程

### 3.2 渐进式替换原则

- 不建议一次性重写所有页面。
- 每一阶段改造一个主页面和一组相关组件。
- 新旧页面并存时，以“组件复用替代页面复制”为优先。

### 3.3 状态收敛原则

所有功能页面优先采用：

- 容器组件负责数据获取和状态机
- 展示组件负责 UI 渲染和事件上抛

不要在纯展示组件内直接发请求。

### 3.4 深浅色模式工程原则

- 深色模式和浅色模式都视为一等运行模式，不允许只在浅色模式下完成组件开发。
- 基础组件禁止直接写死中性色、边框色、背景色、激活色，必须走语义 token。
- 组件对外暴露的优先是语义属性而不是具体颜色值，例如：
  - `tone="primary | success | warning | danger | premium"`
  - `variant="filled | outlined | ghost"`
  - `emphasis="high | medium | low"`
- 所有组件都要在两种模式下验证以下状态：
  - default
  - active
  - disabled
  - loading
  - error
- 图标组件和底部 Tab 必须按小尺寸真实场景检查，不能只看放大稿。
- 任何新增组件如果无法在深色模式下通过对比度和层级检查，不允许进入可复用层。

## 4. 目标目录结构

建议在 `entry/src/main/ets` 下新增如下目录：

```text
entry/src/main/ets/
├─ foundation/
│  ├─ tokens/
│  │  ├─ ColorTokens.ets
│  │  ├─ SpacingTokens.ets
│  │  ├─ RadiusTokens.ets
│  │  ├─ TypographyTokens.ets
│  │  └─ MotionTokens.ets
│  ├─ theme/
│  │  ├─ AppTheme.ets
│  │  └─ ThemeTypes.ets
│  ├─ types/
│  │  ├─ PageState.ets
│  │  ├─ AsyncState.ets
│  │  └─ QuotaState.ets
│  └─ utils/
├─ ui/
│  ├─ base/
│  │  ├─ AppButton.ets
│  │  ├─ AppChip.ets
│  │  ├─ AppCard.ets
│  │  ├─ AppPageHeader.ets
│  │  ├─ AppEmptyState.ets
│  │  ├─ AppErrorState.ets
│  │  ├─ AppLoadingState.ets
│  │  └─ AppStatusBadge.ets
│  ├─ blocks/
│  │  ├─ AnnouncementBanner.ets
│  │  ├─ SyncStatusBar.ets
│  │  ├─ MembershipSummaryCard.ets
│  │  ├─ CreditSummaryCard.ets
│  │  ├─ TodayPlanHeroCard.ets
│  │  ├─ RiskOverviewCard.ets
│  │  ├─ GoalSummaryCard.ets
│  │  ├─ TaskSummaryCard.ets
│  │  ├─ ReminderCarousel.ets
│  │  └─ CountdownCard.ets
│  └─ overlays/
│     ├─ BottomActionSheet.ets
│     ├─ VoiceCreateOverlay.ets
│     ├─ TodayPlanSheet.ets
│     └─ RescheduleSheet.ets
├─ features/
│  ├─ today/
│  ├─ goals/
│  ├─ calendar/
│  ├─ profile/
│  ├─ membership/
│  ├─ credits/
│  ├─ announcements/
│  ├─ telemetry/
│  └─ voice/
├─ pages/
└─ services/
```

## 5. 组件拆分清单

### 5.1 foundation 层

| 组件/文件 | 职责 | 输入/输出 | 当前参考 |
| --- | --- | --- | --- |
| `ColorTokens.ets` | 统一颜色语义 token | 导出颜色对象 | 现有 `AppTheme.ets` |
| `SpacingTokens.ets` | 统一间距 token | 导出 spacing 常量 | 现有 `AppStyle.ets` |
| `SurfaceTokens.ets` | 统一 background/surface/border/elevation 语义层级 | 导出表面层级 token | 建议新增 |
| `TypographyTokens.ets` | 统一字号和字重 | 导出文本规格 | 页面分散定义 |
| `PageState.ets` | 页面级状态枚举 | `loading/empty/error/ready/offline` | 需新增 |
| `AsyncState.ets` | AI 和异步状态模型 | `idle/checking/generating/success/failed` | 需新增 |

### 5.2 ui/base 层

| 组件名 | 职责 | 关键 props | 备注 |
| --- | --- | --- | --- |
| `AppButton` | 统一按钮样式与状态 | `variant`, `size`, `loading`, `disabled`, `text` | 替代各页 Button 自定义 |
| `AppChip` | 标签/筛选 chip | `label`, `active`, `tone` | 替代筛选 chip |
| `AppCard` | 标准卡片容器 | `variant`, `padding`, `radius`, `interactive` | Today/Me/Member 共用 |
| `AppPageHeader` | 标准页头 | `title`, `subtitle`, `showBack`, `actions` | 统一二级页头 |
| `AppEmptyState` | 空状态 | `title`, `description`, `actionText` | 不再每页手写 |
| `AppErrorState` | 错误状态 | `title`, `description`, `retryText` | 不只用 toast |
| `AppLoadingState` | 骨架与加载态 | `mode`, `label` | 页面与卡片共用 |
| `AppStatusBadge` | 成功/警告/会员/同步状态标记 | `status`, `text` | 统一状态视觉 |
| `AppListRow` | 设置项和菜单行 | `title`, `subtitle`, `trailing`, `onClick` | 用于 Me 页 |

所有 `ui/base` 组件必须满足：

- 不直接引用硬编码 hex 作为最终颜色来源
- 同时支持浅色模式和深色模式
- 在 Story/预览页中至少展示一组双模式截图

### 5.3 ui/blocks 层

| 组件名 | 所属域 | 职责 | 当前来源 | 建议事件 |
| --- | --- | --- | --- | --- |
| `AnnouncementBanner` | announcements | 展示活动公告 | 新增 | `onTap`, `onDismiss` |
| `SyncStatusBar` | profile/system | 展示同步状态 | MeTab + EntryAbility 状态整合 | `onRetry`, `onTap` |
| `TodayPlanHeroCard` | today | 首页 Hero | TodayTab/TodayPlanPage | `onView`, `onGenerate`, `onAdjust` |
| `RiskOverviewCard` | today | 展示逾期/冲突/重排 | 新增 | `onViewSuggestion`, `onAdopt` |
| `TaskSummaryCard` | today/goals | 标准任务卡 | TaskListTab 局部 | `onTap`, `onComplete` |
| `GoalSummaryCard` | goals | 标准目标卡 | TodayTab/GoalList 未来组件 | `onTap` |
| `ReminderCarousel` | today/calendar | 横滑提醒区 | TodayTab 提醒区 | `onTapItem`, `onAdd` |
| `CountdownHighlightCard` | today/calendar | 倒计时卡 | TodayTab 倒计时卡 | `onTap` |
| `MembershipSummaryCard` | profile | 展示会员状态摘要 | MeTab + MembershipPage | `onOpenMembership` |
| `CreditSummaryCard` | profile/credits | 展示积分余额和明细入口 | MeTab | `onOpenTransactions` |
| `QuotaUsagePanel` | membership | 展示多功能配额 | MembershipPage | `onOpenMembership` |
| `SearchEntryBar` | today/goals | 搜索统一入口 | TodayTab/SearchPage | `onTap` |

### 5.4 ui/overlays 层

| 组件名 | 职责 | 关键状态 | 备注 |
| --- | --- | --- | --- |
| `BottomActionSheet` | FAB 全局创建面板 | open/close | 承接创建动作 |
| `VoiceCreateOverlay` | 语音创建四阶段交互 | idle/recording/analyzing/done/error | 基于现有 Overlay 改造 |
| `TodayPlanSheet` | 今日计划预览与采纳 | loading/preview/adopted/failed | 新增 |
| `RescheduleSheet` | 一键重排预览与采纳 | loading/preview/partial/failed | 新增 |

### 5.5 features 层

#### `features/today`

| 组件/容器 | 职责 |
| --- | --- |
| `TodayContainer` | 汇总今日页数据源和页面级状态 |
| `TodayHeaderSection` | 顶部问候、搜索、系统摘要 |
| `TodayExecutionSection` | 聚焦任务列表 |
| `TodayTimelineSection` | 倒计时与提醒区 |

#### `features/goals`

| 组件/容器 | 职责 |
| --- | --- |
| `GoalsHubContainer` | 目标/行动双视图容器 |
| `GoalBreakdownFlow` | 多阶段 AI 规划外层容器 |
| `GoalProgressSection` | 进度追踪渲染与编辑 |
| `GoalActionSection` | 行动任务和提醒编辑 |
| `GoalTracePanel` | 规划 trace/debug 视图 |

#### `features/profile`

| 组件/容器 | 职责 |
| --- | --- |
| `ProfileContainer` | 用户信息、积分、同步、设置汇总 |
| `ProfileSettingsSection` | 主题、帮助、关于、退出 |
| `SyncCardContainer` | 同步状态与触发 |

#### `features/membership`

| 组件/容器 | 职责 |
| --- | --- |
| `MembershipContainer` | 拉取会员状态、商品、配额 |
| `MembershipProductList` | 商品卡列表 |
| `MembershipBenefitSection` | 权益解释与差异 |

#### `features/credits`

| 组件/容器 | 职责 |
| --- | --- |
| `CreditTransactionsContainer` | 积分流水查询 |
| `CreditTransactionList` | 列表与空状态 |

## 6. 命名建议

### 6.1 文件命名

- 组件文件一律使用 `PascalCase.ets`
- 类型文件使用 `PascalCaseTypes.ets` 或 `XxxState.ets`
- 功能容器使用 `XxxContainer.ets`
- 区块组件使用 `XxxSection.ets`
- 弹层组件使用 `XxxSheet.ets` 或 `XxxOverlay.ets`

### 6.2 组件命名

推荐：

- `TodayPlanHeroCard`
- `RiskOverviewCard`
- `MembershipSummaryCard`
- `CreditSummaryCard`
- `GoalTracePanel`

不推荐：

- `Card1`
- `MainBlock`
- `InfoView`
- `DialogNew`

### 6.3 事件命名

事件统一使用动词前缀：

- `onTap`
- `onRetry`
- `onDismiss`
- `onAdopt`
- `onGenerate`
- `onOpenMembership`

不推荐：

- `click`
- `doAction`
- `handleIt`

### 6.4 状态命名

建议：

- `isLoading`
- `isSyncing`
- `isGeneratingPlan`
- `showVoiceOverlay`
- `selectedGoalId`
- `currentPlanState`

避免：

- `flag`
- `state1`
- `showDialog2`

### 6.5 Builder 命名

推荐 Builder 仅用于局部布局片段，并且带语义前缀：

- `@Builder private HeaderSection()`
- `@Builder private EmptyStateView()`
- `@Builder private TaskItemCard(task: Task)`

不要用 Builder 承担网络请求和复杂状态分支。

## 7. 页面到组件的迁移映射

| 当前文件 | 主要问题 | 目标拆分 |
| --- | --- | --- |
| `components/TodayTab.ets` | 职责过重、硬编码样式多 | `SearchEntryBar + TodayPlanHeroCard + RiskOverviewCard + ReminderCarousel + CountdownHighlightCard + TodayExecutionSection` |
| `components/TaskListTab.ets` | 只有任务过滤逻辑，缺少目标语义 | `GoalsHubContainer + GoalSummaryCard + TaskSummaryCard + AppChip` |
| `components/CalendarTab.ets` | 既做导航又做事件列表 | `CalendarHeaderSection + CalendarSwitch + ReminderTimelineSection` |
| `components/MeTab.ets` | 数据和视图耦合 | `ProfileContainer + MembershipSummaryCard + CreditSummaryCard + SyncCardContainer + ProfileSettingsSection` |
| `pages/MembershipPage.ets` | 购买、权益、配额混在单页 | `MembershipContainer + QuotaUsagePanel + MembershipBenefitSection + MembershipProductList` |
| `components/VoiceCreateOverlay.ets` | 逻辑和视图耦合 | `VoiceCreateContainer + VoiceCreateOverlayView` |
| `pages/TodayPlanPage.ets` | 本地偏好孤岛 | `TodayPlanSheet + TodayPlanContainer` |
| `components/RescheduleDialog.ets` | 占位实现 | `RescheduleSheet + RescheduleContainer` |

## 8. 改造顺序

建议按 7 个阶段推进，每个阶段尽量单独提测。

### 阶段 0：设计系统打底

#### 目标

- 先把 token、基础组件、状态类型补齐。
- 建立浅色模式和深色模式的统一开发基线。

#### 任务

- 抽离颜色、字号、间距、圆角、阴影、动效 token。
- 抽离 `background / surface / elevatedSurface / border / divider / text / icon` 语义层级 token。
- 新增 `AppCard/AppButton/AppChip/AppLoadingState/AppEmptyState/AppErrorState`。
- 清理明显的硬编码样式入口。
- 为关键基础组件建立浅色/深色双模式预览基线。

#### 输出

- `foundation/*`
- `ui/base/*`

#### 风险

- 改动面大，容易影响现有页面显示。

#### 验证

- 浅色/深色模式快速走查。
- 核心按钮、卡片、筛选 chip 视觉对齐。
- 中性文字、边框、分隔线在深色模式下不发灰、不糊成一层。

### 阶段 1：壳层与系统状态

#### 目标

- 先补全全局系统能力，再改首页。

#### 任务

- 在主端壳层挂载 `AnnouncementBanner` 位置。
- 统一同步状态来源。
- 接入 `TelemetryService.init()`、前后台 `flush()`、关键生命周期事件。

#### 输出

- `SyncStatusBar`
- 全局公告容器
- Telemetry 生命周期接线

#### 验证

- 启动、前台、后台、失败重试链路可观测。

### 阶段 2：Today 首页重构

#### 目标

- 重做唯一首页。

#### 任务

- 将 `TodayTab` 拆为头部、Hero、风险区、执行区、提醒区。
- 接入云端今日计划 API。
- 接入重排入口。
- 顶部展示公告和同步状态。

#### 输出

- `TodayContainer`
- `TodayPlanHeroCard`
- `RiskOverviewCard`
- `ReminderCarousel`
- `CountdownHighlightCard`

#### 验证

- 无计划、有预生成计划、已采纳计划三种状态完整。
- 配额不足时 CTA 正确跳转。

### 阶段 3：Today Plan 与 Reschedule AI 交互

#### 目标

- 统一今日计划和重排的预览采纳模式。

#### 任务

- 新增 `TodayPlanSheet`
- 新增 `RescheduleSheet`
- 增加差异预览组件
- 接入配额与埋点

#### 输出

- AI 预览与采纳通路统一

#### 验证

- 预览态不改动本地数据
- 采纳后首页与任务列表同步刷新

### 阶段 4：Goals Hub 与 Goal Detail

#### 目标

- 把任务 tab 升级为目标驱动 hub。

#### 任务

- 新增 `GoalsHubContainer`
- 目标/行动双分段
- 目标卡与任务卡统一
- 在目标详情中增加规划记录入口

#### 输出

- 新 Goals Hub
- 目标详情结构重排

#### 验证

- 有目标、无目标、有任务无目标三种场景都成立

### 阶段 5：Goal Breakdown 与 Onboarding 整合

#### 目标

- 新手引导和正式目标规划走同一条主链路。

#### 任务

- 引导页只保留选择目标和解释层
- 进入正式 `GoalBreakdownFlow`
- 增加 Trace 入口

#### 输出

- 统一 AI 规划流程

#### 验证

- 首次启动可完整走通 `Onboarding -> GoalBreakdown -> GoalDetail -> Today`

### 阶段 6：Me、会员、积分流水

#### 目标

- 形成完整权益闭环。

#### 任务

- `MeTab` 拆分为权益卡、积分卡、同步卡、设置区
- 新增积分流水页
- 会员页增强权益解释

#### 输出

- `CreditTransactionsPage`
- 新版 `MembershipContainer`
- 新版 `ProfileContainer`

#### 验证

- 基础版、会员版、积分冻结、商品加载失败都可测试

### 阶段 7：Calendar、Search、收尾优化

#### 目标

- 完成信息结构对齐和视觉统一。

#### 任务

- Calendar 卡片和 Today/Goals 组件对齐
- Search 结果卡统一
- 扫尾硬编码样式

#### 输出

- 全局视觉统一

## 9. 服务与状态模型建议

### 9.1 状态模型

建议新增统一状态类型：

```text
PageState = 'loading' | 'ready' | 'empty' | 'error' | 'offline'
AsyncState = 'idle' | 'checking' | 'generating' | 'preview' | 'adopted' | 'failed'
QuotaState = 'enough' | 'low' | 'exhausted' | 'membership_required'
SyncState = 'idle' | 'syncing' | 'success' | 'failed'
```

### 9.1 主题适配状态建议

建议新增统一主题上下文约束：

```text
ThemeMode = 'light' | 'dark' | 'system'
ThemeSurfaceLevel = 'background' | 'surface' | 'surfaceRaised'
ThemeContrast = 'normal' | 'high'
```

建议所有基础组件优先消费 `ThemeColors + SurfaceLevel + Tone`，而不是直接消费颜色值。

### 9.2 容器职责

容器组件负责：

- 初始化服务
- 拉取数据
- 合并多源状态
- 管理 Sheet/Overlay 的开关
- 埋点

展示组件负责：

- 纯渲染
- 状态分支显示
- 用户动作上抛

### 9.3 业务状态整合建议

`TodayContainer` 需要整合以下来源：

- 本地任务、目标、提醒、番茄钟
- 云端今日计划
- 风险分析和重排建议
- 公告数据
- 同步状态
- 配额状态

### 9.4 主题落地约束

- 页面容器只负责声明当前使用哪些语义层级，不负责重新定义颜色。
- `ui/base` 和 `ui/blocks` 组件必须优先消费 `themeColors`。
- 图标激活态、未激活态、禁用态必须通过主题 token 控制。
- 浅色/深色模式下，如果组件需要不同透明度、不同描边强度，应该通过 token 层解决，不允许页面临时拼色。

## 10. 测试策略

### 10.1 阶段性回归原则

- 每一阶段单独提测，不要求一次覆盖所有页面。
- 每一个新组件至少在一个真实页面落地后再继续抽象。

### 10.2 页面测试清单

#### Today

- 无计划
- 有 pending 计划
- 有 adopted 计划
- 计划生成失败
- 重排失败
- 公告有/无
- 同步成功/失败
- 基础会员/高级会员

#### Goals

- 无目标
- 有目标无任务
- 有目标有任务
- 任务逾期较多
- AI 拆解入口成功/失败

#### Goal Breakdown

- 每一步成功
- 每一步失败
- 中途退出再恢复
- 采纳成功
- 本地应用失败

#### Voice Create

- 文本输入成功
- 录音识别成功
- 录音失败
- 会员不足
- 网络失败

#### Me / Membership / Credits

- 未登录
- 基础版
- 高级版
- 积分冻结
- 流水为空
- 商品加载失败

### 10.3 样式测试清单

- 浅色模式
- 暗色模式
- 超长标题
- 超长摘要
- 无图、无公告、无提醒的空状态
- 多个状态 badge 并列
- 底部 Tab 在两种模式下的激活/未激活/按下状态
- 卡片边框、分隔线、输入框描边在深色模式下的可见性
- 重点 CTA、风险 CTA、会员 CTA 在两种模式下的语义一致性

### 10.4 双模式专项验收

- 每个 P0 页面至少有一张浅色模式截图和一张深色模式截图进入提测记录。
- 每个新增基础组件至少通过一次双模式视觉走查。
- 对比度不足、边框丢失、图标发灰、层级不清，均按缺陷处理，不视为“样式优化项”。

### 10.5 埋点测试清单

需要验证至少以下事件：

- `session_start`
- `membership_page_view`
- `ai_plan_triggered`
- `ai_plan_adopted`
- `ai_reschedule_triggered`
- `ai_reschedule_adopted`
- `goal_breakdown_triggered`
- `goal_breakdown_adopted`
- `voice_input_started`
- `voice_input_completed`

## 11. 推荐 PR 拆分

建议一阶段一个 PR，降低风险：

1. `theme-and-base-components`
2. `system-state-and-telemetry`
3. `today-home-refactor`
4. `today-plan-and-reschedule`
5. `goals-hub-refactor`
6. `goal-breakdown-unification`
7. `profile-membership-credits`
8. `calendar-search-polish`

## 12. 前端验收标准

### 工程标准

- 页面内硬编码主色和卡片样式显著减少
- 新增页面优先使用 `ui/base` 和 `ui/blocks`
- 功能状态不依赖 toast 作为唯一反馈

### 交互标准

- 所有 AI 流程都有统一的检查、生成、预览、采纳、失败阶段
- 所有高价值动作都有明确结果页或状态反馈
- 配额不足和会员不足都能稳定跳到权益页

### 可维护性标准

- 页面负责业务编排，组件负责展示
- 系统级状态有统一来源
- 同类组件命名和 props 风格一致
