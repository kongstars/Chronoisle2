# Chronoisle2 HarmonyOS NEXT UI 升级方案

更新日期：2026-04-28

适用范围：`entry/src/main/ets/` 下的 HarmonyOS ArkUI 主端界面、桌面卡片、系统入口能力，以及与 UI 体验直接相关的服务层。

本方案用于把华为开发者官网最新 HarmonyOS 设计规范和系统特性，转化为 Chronoisle2 可分期落地的 UI 升级路线。目标不是机械支持所有平台能力，而是全面支持适用于 Chronoisle2 的 HarmonyOS NEXT 设计与生态规范，并对不适用项建立明确豁免清单。

## 1. 背景和目标

### 1.1 背景

华为 HarmonyOS 设计文档已经把新体验重点从单一手机 UI 扩展到多设备、多窗口、系统级入口和生态特性：

- HarmonyOS 设计理念：强调清晰易读、层次明确、直觉操作、多设备一致性与差异性平衡。
- 多设备响应式设计：要求应用适配不同屏幕尺寸、屏幕方向、折叠屏、平板和多窗口形态。
- UX 体验标准：覆盖点击热区、深色模式、系统手势、安全区、大字号、LTR/RTL 等基础体验。
- 交互响应：覆盖触屏、鼠标、键盘、焦点、统一拖拽等多输入方式。
- 系统特性：包括实况窗、桌面卡片、Intents Kit、Picker、Share Kit、华为账号登录、多窗口等。

Chronoisle2 当前定位是“安静、精确、持续可用的个人执行控制台”。因此升级方向应该服务于任务、目标、计划、专注、提醒和 AI 调度的日常执行效率，而不是做成展示型或营销型界面。

### 1.2 总目标

1. 视觉体验符合 HarmonyOS NEXT 气质：清晰、克制、轻科技感、信息密度高但不拥挤。
2. 交互体验符合基础 UX 标准：热区、焦点、键鼠、大字号、深色模式、安全区、动效反馈完整。
3. 多设备体验可用：手机竖屏不退化，横屏、折叠屏、平板、悬浮窗、分屏不只是简单拉伸。
4. 系统入口更完整：桌面卡片、实况窗、Intents、Picker、分享、华为账号登录形成一套生态体验。
5. 建立规范矩阵：每一项新规范都有状态、落点、验收方式和不采用原因。

### 1.3 不做的目标

以下能力不作为短中期目标，除非产品方向发生变化：

- 播控中心全量适配：当前只有白噪音/专注辅助，不是媒体播放类产品。
- 车机、电视、VR/AR 专项界面：当前 `module.json5` 仅声明 `phone`，产品核心场景不在这些设备。
- 元服务全量化：当前 `installationFree` 为 `false`，主产品仍是完整安装应用。
- 为了“全支持”强行接入和业务无关的系统能力。

## 2. 当前实现基线

### 2.1 已具备的基础

当前项目已经具备三层 UI 基础设施：

- 主题层：`entry/src/main/ets/theme/AppTheme.ets`
- Token 层：`entry/src/main/ets/foundation/tokens/*`
- 基组件层：`entry/src/main/ets/ui/base/*`

当前高频基组件包括：

- `AppButton`
- `AppCard`
- `AppChip`
- `AppEmptyState`
- `AppGoalCard`
- `AppHeroPanel`
- `AppIcon`
- `AppListRow`
- `AppPageHeader`
- `AppPanelSection`
- `AppReminderCard`
- `AppSearchBar`
- `AppSegmentTabs`
- `AppStatusBadge`
- `AppTaskRow`

当前主入口为 `pages/MainPage.ets`：

- `TodayTab`
- `TaskListTab`
- `CalendarTab`
- `MeTab`
- 中央 FAB
- `VoiceCreateOverlay`

当前生态能力基础：

- 桌面卡片：`entry/src/main/resources/base/profile/form_config.json`
- 华为账号登录：`pages/LoginPage.ets`
- 文件 Picker 导出：`services/StatsService.ets`
- widget 跳转：`EntryAbility.ets` + `postCardAction` 相关卡片代码
- 系统提醒：`DayEventReminderService.ets` / `MembershipReminderService.ets`

### 2.2 当前主要短板

1. 设计系统还没有完全收口。
   - token 文件已经存在，但页面内仍有大量手写尺寸、颜色和局部视觉规则。
   - `MotionTokens.ets` 已存在，但动效应用不系统。
   - 基组件尚未统一 hover、focus、pressed、disabled、loading 等状态。

2. 响应式和多窗口能力不足。
   - `module.json5` 当前只声明 `phone`。
   - 主页面结构仍是手机优先布局。
   - 宽屏、分屏、悬浮窗下缺少明确布局策略。

3. 路由体系还没有进入 Navigation 分栏架构。
   - 当前主要依赖 `router.pushUrl`。
   - 主壳直接承载底部 Tab、FAB、语音弹层和页面跳转。
   - 贸然全量迁移到 `Navigation/NavDestination` 风险较高。

4. 系统级新入口还未产品化。
   - 桌面卡片已有数量基础，但视觉和交互协议需要统一。
   - 实况窗尚未接入。
   - Intents Kit 尚未抽象动作层。
   - Share Kit 尚未形成统一分享体验。

5. 文档与实现之间需要建立追踪关系。
   - 当前已有 `docs/design/*` 历史资料和 `docs/design/ui/ui-style-guide.md`，但缺少一份面向 HarmonyOS NEXT 新规范的总控方案。

## 3. 适配原则

### 3.1 产品原则

Chronoisle2 的 UI 升级必须服务于“执行效率”，优先保证以下体验：

- 用户一眼知道今天该做什么。
- 任务、提醒、目标、专注状态之间的关系清晰。
- AI 能力像执行助手，而不是营销装饰。
- 信息密度高，但不要压迫。
- 系统入口增加便利性，而不是制造打扰。

### 3.2 技术原则

1. 先 token，后页面。
   - 新增视觉规则优先进入 `theme` 或 `foundation/tokens`。
   - 页面禁止新增长期私有视觉常量。

2. 先基组件，后业务页。
   - `AppButton`、`AppCard`、`AppListRow`、`AppChip`、`AppPageHeader` 等先补齐状态。
   - 页面只组合基组件，不重复实现同类视觉。

3. 先试点，后铺开。
   - 响应式、多窗口、Navigation 分栏先选低风险页面试点。
   - 主壳迁移必须放到试点验证之后。

4. 先本地闭环，后生态能力。
   - Live View 先做本地创建、更新、结束。
   - Intents 先抽动作服务，再接系统意图。
   - Share Kit 先统一分享内容模板，再接系统分享。

5. 不适用项必须显式记录。
   - 不采用不是遗漏，而是有产品理由的豁免。

## 4. 新规范适配矩阵

| 规范/能力 | 适配状态 | 项目落点 | 优先级 | 说明 |
| --- | --- | --- | --- | --- |
| 设计理念 | 计划支持 | `docs/design/ui/ui-style-guide.md`、token、基组件 | P0 | 作为所有 UI 调整的原则层 |
| UX 基础标准 | 计划支持 | 基组件、主页面、表单页 | P0 | 热区、大字号、安全区、深色模式、手势冲突 |
| 色彩/字体/圆角/阴影 | 部分支持 | `AppTheme.ets`、`foundation/tokens/*` | P1 | 已有基础，需要收口 |
| 动效设计 | 部分支持 | `MotionTokens.ets`、弹层、按钮、列表 | P1 | 需要统一进入/退出/按压/反馈 |
| 多设备响应式 | 计划支持 | `TodayTab`、`TaskListTab`、`StatsHubPage` | P2 | 先做页面试点 |
| GridRow/GridCol | 计划支持 | 统计页、任务页、今日页 | P2 | 用于宽屏布局 |
| Navigation 分栏 | 计划支持 | 统计/提醒页试点，后续主壳 | P3 | 不先全量迁移 |
| 智慧多窗 | 计划支持 | `module.json5`、窗口避让、页面响应式 | P3 | 先适配再声明 |
| 键鼠/焦点 | 计划支持 | 基组件、列表、表单、弹层 | P3 | 宽屏和多设备前提 |
| 统一拖拽 | 条件支持 | 任务排序、计划编排、目标任务关联 | P5 | 需要先明确业务手势 |
| Picker | 部分支持 | `StatsService.ets`、头像/文件导入导出 | P4 | 从旧 Picker 口径升级 |
| Share Kit | 计划支持 | 统计报告、今日计划、目标成果分享 | P4 | 适合低风险生态入口 |
| 华为账号登录 | 部分支持 | `LoginPage.ets` | P4 | 需按规范优化登录时机和按钮 |
| 桌面卡片 | 部分支持 | `widget/pages/*`、`form_config.json` | P4 | 已有多卡片，需要统一体系 |
| 实况窗 Live View | 计划支持 | 专注/番茄钟、AI 重排、今日计划执行 | P5 | 高价值，需真机和权限验证 |
| Intents Kit | 计划支持 | `AppActionService`、创建/专注/今日计划 | P6 | 需要接入、测试、上架流程 |
| 应用接续 | 条件支持 | 专注、今日计划、编辑草稿 | P7 | 需要多设备真机验证 |
| 分布式拖拽/剪贴板 | 条件支持 | 任务文本、计划片段导入 | P7 | 业务价值待评估 |
| 播控中心 | 不适用 | 白噪音/专注音频可单独评估 | 豁免 | 当前不是媒体播放产品 |
| 车机/电视/VR 专项规范 | 不适用 | 无 | 豁免 | 当前产品与设备类型不匹配 |
| 元服务全量化 | 暂缓 | 安装包/服务卡片 | P8 | 需产品策略和上架策略确认 |

## 5. 分期落地计划

### P0：规范建账与基线冻结

目标：建立可追踪的适配矩阵和验收口径，避免后续改动变成零散样式修补。

任务：

1. 新增本方案作为 HarmonyOS NEXT UI 升级总纲。
2. 在 `docs/design/ui/ui-style-guide.md` 中补充本方案链接和优先级关系。
3. 建立 `HarmonyOS 新规范适配矩阵`，每项标注：
   - `已支持`
   - `部分支持`
   - `计划支持`
   - `条件支持`
   - `暂缓`
   - `不适用`
4. 冻结当前核心页面截图和行为基线：
   - `MainPage`
   - `TodayTab`
   - `TaskListTab`
   - `CalendarTab`
   - `MeTab`
   - `CreateTaskPage`
   - `DayEventCreatePage`
   - `TodayPlanPage`
   - `PomodoroPage`
   - `StatsHubPage`
5. 建立验收视口：
   - 手机竖屏
   - 手机横屏
   - 深色模式
   - 大字号
   - 悬浮窗
   - 分屏
   - 折叠屏展开态/平板宽屏

产出：

- `docs/design/harmonyos/harmonyos-next-ui-upgrade-plan.md`
- 更新后的 `docs/design/ui/ui-style-guide.md`
- 页面截图基线记录
- 适配矩阵状态表

验收：

- 方案文档完整。
- 每个规范项都有明确状态。
- 当前工作区改动与方案改动可区分。

### P1：设计系统收口

目标：先把视觉规则落到 token 和基础组件，保证后续页面升级有统一底座。

任务：

1. 主题层收口。
   - 检查 `LightTheme` / `DarkTheme` 对比度。
   - 明确页面背景、表面层、浮层、输入框、边框、分割线、阴影颜色。
   - 减少页面直接使用十六进制颜色。

2. 字体层收口。
   - 明确页面标题、分区标题、正文、说明、数字、徽标文字的 token。
   - 所有 `Text` 优先使用 `TypographyTokens`。
   - 大字号模式下避免固定高度裁剪。

3. 间距与密度收口。
   - 明确页面 padding、section gap、card padding、row gap。
   - 表单页和工具页使用更紧凑密度。
   - 避免首屏主操作被挤出屏幕。

4. 圆角、边框、阴影收口。
   - 普通卡片、浮层卡片、强调卡片、危险卡片分别定义规则。
   - 避免重阴影和多层卡片嵌套。

5. 动效 token 可用化。
   - 页面切换、弹层进入、按钮按压、列表刷新、状态切换分别定义时长和曲线。
   - 禁止页面自定义随意动效时长。

6. 基组件补状态。
   - `AppButton`：pressed、disabled、loading、focus。
   - `AppCard`：interactive、pressed、focus、danger/accent/premium。
   - `AppChip`：selected、disabled、focus。
   - `AppListRow`：点击态、键盘焦点态、右侧操作区。
   - `AppSearchBar`：输入态、清除态、focus。
   - `AppPageHeader`：安全区、返回按钮、标题压缩。

重点文件：

- `entry/src/main/ets/theme/AppTheme.ets`
- `entry/src/main/ets/foundation/tokens/*`
- `entry/src/main/ets/ui/base/*`

验收：

- `git diff --check`
- `hvigor assembleApp -p product=default -p buildMode=debug`
- 手机竖屏首页视觉不退化。
- 深色模式下主要页面文字和边框可读。
- 基组件状态在页面中可复用，不需要页面重复实现。

### P2：核心页面响应式试点

目标：先让高信息密度页面在宽屏、多窗下真正可用。

试点页面：

1. `TodayTab`
2. `TaskListTab`
3. `StatsHubPage`

任务：

1. 新增响应式辅助能力。
   - 定义 `xs / sm / md / lg` 断点。
   - 提供当前窗口宽度或布局模式判断。
   - 页面按模式选择单列、双列或主辅布局。

2. 今日页响应式。
   - 手机：保持单列。
   - 宽屏：左侧为今日计划和执行主线，右侧为提醒、目标、统计摘要。
   - 避免 Hero 面板无限变宽。

3. 任务页响应式。
   - 手机：筛选条 + 列表。
   - 宽屏：筛选/目标/AI 重排入口固定在侧栏或顶部紧凑区，列表保持舒适宽度。
   - 任务卡片宽度不超过合理阅读宽度。

4. 统计页响应式。
   - 使用栅格思想组织指标卡、趋势图、热力图、分布图。
   - 宽屏下形成 2 列或 3 列，不做单列拉伸。

验收：

- 手机竖屏与当前体验基本一致。
- 宽屏下没有超宽卡片、超长行文本和过度空白。
- 分屏和悬浮窗下核心按钮仍可见。
- 大字号下卡片高度可以增长，但不互相遮挡。

### P3：多窗口和 Navigation 试点

目标：建立窗口模式和路由结构的中期升级路径。

任务：

1. 多窗口适配。
   - 检查全屏、悬浮窗、分屏、横屏的状态保存。
   - 适配顶部窗口控制条，避免遮挡返回、保存、关闭按钮。
   - 检查专注页、创建页、详情页的最小可用宽度。

2. `module.json5` 能力评估。
   - 在布局适配完成后，再考虑显式声明 `supportWindowMode`。
   - 评估是否增加折叠屏/平板设备类型。
   - 避免先声明能力导致审核或体验问题。

3. Navigation 低风险试点。
   - 不先改主壳。
   - 优先选择 `StatsHubPage` 或 `ReminderListPage` 做 `Navigation/NavDestination` 试点。
   - 试点通过后，再评估主壳是否迁移到 `NavigationMode.Auto`。

4. 主壳迁移预案。
   - 保留底部 Tab + FAB 的手机体验。
   - 宽屏时考虑侧边导航或导航栏固定。
   - 语音创建、widget 跳转、OAuth 回调、深链路必须有兼容方案。

验收：

- 多窗口切换不重启、不闪退、不丢当前任务状态。
- 顶部横条不遮挡页面头部操作。
- 子页返回链路稳定。
- widget、OAuth、语音创建入口不受影响。

### P4：系统控件与桌面卡片升级

目标：把低风险系统能力先产品化。

任务：

1. Picker 升级。
   - 检查 `StatsService.ets` 统计导出。
   - 后续头像、文件导入、报告导出统一使用系统 Picker。
   - 减少不必要权限申请。

2. Share Kit 接入。
   - 今日计划分享。
   - 统计报告分享。
   - 目标成果分享。
   - 分享内容使用系统推荐预览模板，避免自定义面板。

3. 华为账号登录体验优化。
   - 登录不应阻断用户初次理解产品价值。
   - 华为账号登录按钮、协议确认、取消路径按规范优化。
   - 登录失败、离线降级、同步状态提示统一使用基组件。

4. 桌面卡片体系升级。
   - 统一 `WidgetStyle.ets`、`WidgetGlyph.ets`。
   - 卡片页面继续保持 bind-only，不直接读取业务存储。
   - `4*4` 作为控制台卡片。
   - `2*4` 作为列表/计划卡片。
   - `2*2` 作为单动作/单状态卡片。
   - 统一卡片跳转协议：
     - 今日计划
     - 任务详情
     - 创建任务
     - 创建提醒
     - 语音创建
     - 开始专注

验收：

- 导出/分享流程使用系统控件。
- 取消 Picker 或分享不会造成错误提示。
- 卡片点击路径明确。
- 卡片和主 app 的状态、颜色、概念一致。

### P5：实况窗 Live View

目标：接入最能体现 HarmonyOS 生态价值的进行中任务入口。

第一批场景：

1. 番茄钟/专注中。
   - 最符合实况窗“开始、持续、动态变化、结束”的规则。
   - 展示剩余时间、当前任务、暂停/结束入口。

2. AI 重排中。
   - 仅在耗时明显、用户主动触发的重排任务中使用。
   - 展示“分析中、生成中、待确认”等状态。

3. 今日计划执行中。
   - 只用于用户主动开始的计划执行。
   - 不用于普通静态待办或远期提醒。

任务：

1. 新增 `LiveViewService.ets`。
2. 封装创建、更新、结束、状态校验。
3. 先本地生命周期闭环。
4. 再评估 Push Kit 更新。
5. 建立失败降级：实况窗不可用时不影响本地功能。

验收：

- 只有用户主动开始的进行中任务才创建实况窗。
- 任务结束后可靠结束。
- 应用进入后台后状态符合预期。
- 关闭实况窗不影响本地记录。
- 真机验证通过后才标记 `已支持`。

### P6：Intents Kit 和系统推荐

目标：把核心动作暴露给系统，形成快捷入口和智能推荐能力。

候选意图：

- 创建任务
- 创建提醒
- 语音创建
- 开始专注
- 打开今日计划
- 查看今日任务
- 搜索任务/目标
- 开始 AI 重排

前置任务：

1. 新增 `AppActionService`。
   - 将页面内关键动作抽成可复用服务。
   - 页面点击、widget、Intents 共用同一动作入口。

2. 明确权限边界。
   - 不能绕过登录、会员、配额、隐私确认。
   - 失败时返回可理解的系统提示。

3. 接入 Intents Kit。
   - 完成意图声明。
   - 完成端侧意图共享和调用。
   - 完成白名单/测试/上架配置。

验收：

- 页面内触发和系统意图触发结果一致。
- 权限、会员、配额判断一致。
- 系统推荐入口不会制造重复任务或误操作。

### P7：多设备协同能力评估

目标：只接真正有业务价值的高阶协同能力。

候选能力：

- 应用接续：从手机继续编辑今日计划或任务草稿。
- 跨设备拖拽：把文本、计划片段、任务描述拖入应用。
- 分布式剪贴板：快速捕获跨设备复制的任务文本。

采用条件：

- 有明确用户场景。
- 不增加隐私风险。
- 真机验证可完成。
- 不影响核心手机体验。

验收：

- 完成跨设备真机验证。
- 异常中断时草稿可恢复。
- 不自动读取或上传用户敏感内容。

### P8：长期策略项

目标：等待产品策略明确后再做。

候选：

- 元服务版本。
- 折叠屏/平板专版上架。
- 白噪音/专注音频接播控中心。
- 企业/团队协作视图。

当前结论：

- 暂不进入主开发路线。
- 保留在产品路线图中观察。

## 6. 页面级升级清单

### 6.1 MainPage

目标：

- 保持手机底部 Tab + FAB 体验稳定。
- 为宽屏侧边导航和 Navigation 迁移预留结构。

任务：

- 抽离主壳布局常量。
- 底部导航补齐 focus/hover/pressed。
- FAB 补齐安全区、多窗口位置和点击反馈。
- AddActionSheet 按半模态规范统一动效。
- 保持 `VoiceCreateOverlay` 入口稳定。

### 6.2 TodayTab

目标：

- 成为响应式试点主页面。
- 手机单列，宽屏主辅布局。

任务：

- 今日计划 Hero 限制最大宽度。
- 今日提醒横向卡片在宽屏变为辅助区。
- 目标推进卡片进入右栏或下方栅格。
- 搜索和创建入口保持首屏可见。

### 6.3 TaskListTab

目标：

- 任务执行效率优先。
- 宽屏下筛选和列表解耦。

任务：

- 筛选区响应式压缩。
- 任务列表最大阅读宽度。
- AI 重排入口统一为系统化提示条。
- 任务卡片补键盘 focus 和 hover。

### 6.4 CalendarTab

目标：

- 保持打卡/提醒视图清晰。
- 横屏和宽屏下日历与当日列表并列。

任务：

- 日历格固定比例。
- 当日提醒/任务列表可独立滚动。
- 模式切换使用 `AppSegmentTabs`。

### 6.5 MeTab

目标：

- 个人中心从列表堆叠升级为分组设置中心。

任务：

- 账户、权益、数据、主题、更多分区明确。
- 登录状态、会员状态、同步状态统一 badge。
- 宽屏下使用两列设置布局。

### 6.6 CreateTaskPage / DayEventCreatePage

目标：

- 表单更符合系统输入规范。
- 大字号、多窗口下主操作不被遮挡。

任务：

- 表单项统一为基组件。
- 日期/时间/目标选择器采用半模态规范。
- 保存按钮在小屏保持可见。
- 校验错误提示统一。

### 6.7 PomodoroPage / CreatePomodoroPage

目标：

- 作为实况窗第一批接入场景。

任务：

- 专注状态抽成服务。
- 运行中状态同步给 Live View。
- 暂停、继续、结束动作统一。
- 横屏/悬浮窗下保留核心控制。

### 6.8 StatsHubPage / FocusStatsPage

目标：

- 作为 GridRow/GridCol 和 Share Kit 试点。

任务：

- 指标卡栅格化。
- 图表区域限制宽度和高度。
- 统计导出迁移到新 Picker 口径。
- 报告分享接 Share Kit。

### 6.9 Widget Pages

目标：

- 卡片成为系统级执行入口，而不是简单信息展示。

任务：

- 统一视觉 token。
- 统一图标和状态色。
- 统一跳转协议。
- 保持 bind-only 架构。
- `4*4` 控制台卡片优先完善。

## 7. 工程任务拆分

### 7.1 文档任务

- 新增本升级方案。
- 更新 `docs/design/ui/ui-style-guide.md` 的规范来源和优先级。
- 建立 `docs/design/harmonyos/harmonyos-next-adaptation-matrix.md`。
- 更新 `docs/core/todo.md` 的 UI 升级路线。

### 7.2 基础设施任务

- 新增响应式断点 helper。
- 补齐 token。
- 补齐基组件状态。
- 抽 `AppActionService`。
- 抽 `LiveViewService`。
- 抽分享内容 builder。

### 7.3 页面任务

- TodayTab 响应式。
- TaskListTab 响应式。
- StatsHubPage 栅格化。
- CreateTaskPage 表单规范化。
- PomodoroPage 实况窗。
- Widget 视觉统一。

### 7.4 配置任务

- 评估 `module.json5` 设备类型。
- 评估 `supportWindowMode`。
- 实况窗权限/权益配置。
- Intents Kit 声明和上架配置。
- Share Kit / Picker 相关依赖确认。

## 8. 验收标准

### 8.1 基础构建

每期至少执行：

```powershell
git diff --check
hvigor assembleApp -p product=default -p buildMode=debug
```

如果设备验证可用，再执行：

```powershell
D:\software\devecostudio\SDK\20\toolchains\hdc.exe list targets
```

### 8.2 视觉验收

每期至少检查：

- 手机竖屏
- 手机横屏
- 深色模式
- 大字号
- 悬浮窗
- 分屏
- 宽屏/折叠屏展开态

检查项：

- 文本不截断。
- 按钮不重叠。
- 主操作可见。
- 安全区不遮挡。
- 卡片不无限拉伸。
- 深色模式对比度可读。
- loading、empty、error、disabled 状态完整。

### 8.3 交互验收

检查项：

- 点击热区足够。
- 键盘 focus 可见。
- 鼠标 hover 有反馈。
- 弹层可关闭。
- 返回链路正确。
- 横竖屏切换不丢状态。
- 多窗口切换不重启关键流程。

### 8.4 生态能力验收

桌面卡片：

- 刷新正常。
- 点击跳转正确。
- 数据为空时显示合理。

实况窗：

- 创建条件正确。
- 动态更新可靠。
- 结束可靠。
- 不滥用静态提醒。

Intents：

- 系统触发和页面触发结果一致。
- 权限、会员、配额判断一致。

Picker/Share：

- 取消无错误。
- 权限最小化。
- 分享内容预览清晰。

## 9. 风险和应对

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| 全量 UI 重构导致样式回退 | 高 | 先 token/基组件，后页面；每期截图验收 |
| Navigation 迁移破坏路由 | 高 | 先低风险页面试点，不先改主壳 |
| 多窗口声明过早 | 中高 | 先适配布局，再改 `module.json5` |
| Live View 权限/真机不稳定 | 中高 | 先服务封装和降级，再真机验证 |
| Intents 接入周期长 | 中 | 先抽 `AppActionService`，系统接入单独排期 |
| 页面私有样式继续扩散 | 中 | 文档规定新增视觉值必须进 token |
| widget 页面读取业务存储 | 中 | 继续保持 bind-only 架构 |
| 当前工作区改动较多 | 中 | 每期单独分支或至少拆分提交，避免混入无关改动 |

## 10. 推荐实施顺序

第一轮：P0 + P1

- 建账、文档、token、基组件。
- 目标是稳定设计底座。

第二轮：P2 + P3 部分

- TodayTab、TaskListTab、StatsHubPage 响应式试点。
- 多窗口布局检查。
- Navigation 只做低风险试点。

第三轮：P4

- Picker、Share Kit、华为登录体验、桌面卡片视觉统一。
- 目标是增强系统控件一致性。

第四轮：P5

- 番茄钟/专注实况窗。
- AI 重排实况窗。
- 今日计划执行实况窗。

第五轮：P6

- AppActionService。
- Intents Kit。
- 系统推荐入口。

第六轮：P7/P8 评估

- 应用接续。
- 跨设备拖拽。
- 元服务策略。
- 播控中心是否只为白噪音单独接入。

## 11. 完成定义

单项能力只有同时满足以下条件，才能在适配矩阵中标记为 `已支持`：

1. 有代码落点。
2. 有页面或服务调用。
3. 构建通过。
4. 至少完成对应视口或真机场景验证。
5. 文档状态已更新。

如果只完成 UI 或服务封装，但没有真机/权限/上架验证，应标记为 `部分支持`。

如果业务价值明确但尚未排期，应标记为 `计划支持`。

如果业务价值不足或产品类型不匹配，应标记为 `不适用`，并说明原因。

## 12. 下一步建议

建议下一步直接进入 P0/P1：

1. 更新 `docs/design/ui/ui-style-guide.md`，把本方案列为 HarmonyOS NEXT 适配总纲。
2. 新增 `docs/design/harmonyos/harmonyos-next-adaptation-matrix.md`。
3. 从 `AppButton`、`AppCard`、`AppListRow`、`AppChip` 开始补齐状态。
4. 选择 `TodayTab`、`TaskListTab`、`StatsHubPage` 作为 P2 响应式试点。

这条路线能先把风险最大的“风格回退”和“页面私有样式扩散”压住，再逐步接入多设备和生态能力。

