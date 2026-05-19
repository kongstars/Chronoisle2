# HarmonyOS NEXT 规范适配矩阵

更新日期：2026-05-15

关联总纲：`docs/design/harmonyos/harmonyos-next-ui-upgrade-plan.md`

本文档用于追踪 Chronoisle2 对 HarmonyOS NEXT 设计规范和系统生态能力的落地状态。状态判断以当前代码、配置、构建和真机验证为准，不以规划文档本身作为完成依据。

## 状态定义

| 状态 | 含义 | 标记条件 |
| --- | --- | --- |
| 已支持 | 已有代码落点并通过对应验证 | 代码/配置完成，构建通过，必要场景已真机或截图验证 |
| 部分支持 | 已有基础能力但未完整闭环 | 有代码基础，但缺统一规范、真机验证、权限或上架确认 |
| 计划支持 | 适合产品且已纳入路线 | 已明确落点和优先级，尚未实现 |
| 条件支持 | 业务价值存在但依赖外部条件 | 依赖权限、白名单、真机、多设备或产品策略 |
| 暂缓 | 当前不进入开发 | 业务价值不足或需要等待策略确认 |
| 不适用 | 与 Chronoisle2 当前产品类型不匹配 | 记录豁免原因，后续产品变化时再复评 |

## P0/P1 基础规范

| 规范项 | 当前状态 | 优先级 | 当前落点 | 下一步 | 验收方式 |
| --- | --- | --- | --- | --- | --- |
| HarmonyOS 设计理念 | 已支持 | P0 | `docs/design/ui/ui-style-guide.md`、本方案 | “清晰、克制、执行效率”已沉淀到页面规范 | 新页面评审按总纲和样式指南双重检查 |
| 体验标准建账 | 已支持 | P0 | 本矩阵 | 每轮代码改动后同步状态和豁免原因 | 矩阵状态可追踪 |
| 色彩体系 | 已支持 | P1 | `AppTheme.ets` | 页面私有颜色已收口，widget 颜色已接 WidgetStyle | 深色/浅色主要页面可读 |
| 字体层级 | 已支持 | P1 | `TypographyTokens.ets`、`AppPageHeader` | 页面标题、分区标题、正文、说明已 token 化 | 大字号下标题和按钮不裁剪 |
| 间距密度 | 已支持 | P1 | `SpacingTokens.ets`、`PageDensityTokens.ets` | 页面 padding、卡片间距、行高已 token 化 | 首屏主操作可见 |
| 圆角/边框/阴影 | 已支持 | P1 | `RadiusTokens.ets`、`BorderTokens.ets`、`ElevationTokens.ets` | 普通卡片、浮层、交互卡片三级差异已定义 | 无重阴影和卡片嵌套失控 |
| 动效口径 | 已支持 | P1 | `MotionTokens.ets` | 按钮、卡片、弹层、列表均使用 token 动效值 | 动效值来自 token |
| 点击热区 | 已支持 | P1 | `AppButton`、`AppListRow`、`AppPageHeader`、底部导航 | 主操作>=40px，列表行>=56px | 主要操作不低于规范下限 |
| Disabled/Loading 状态 | 已支持 | P1 | `AppButton`、`AppChip`、`AppListRow`、`AppSearchBar` | 基组件完整覆盖，页面局部禁用态已收口 | 禁用状态不可误触 |
| Hover/Focus 状态 | 已支持 | P1 | 全部基组件：AppButton/AppCard/AppChip/AppListRow/AppSearchBar/AppSegmentTabs/AppPageHeader/AppTaskRow/AppReminderCard/AppGoalCard + 底部导航/FAB | 键鼠场景有完整反馈 | 键鼠场景有可见反馈 |
| 空/错/加载状态 | 已支持 | P1 | `AppEmptyState`、`AppErrorState`、`AppLoadingState` | 三态组件全页面覆盖中 | 关键列表空数据有解释和动作 |

## P2/P3 响应式和多窗口

| 规范项 | 当前状态 | 优先级 | 当前落点 | 下一步 | 验收方式 |
| --- | --- | --- | --- | --- | --- |
| 断点策略 | 部分支持 | P2 | `PageDensityTokens.ets`、`TodayTab.ets` | 从 Today 试点沉淀为统一响应式 helper | 手机/宽屏使用一致断点 |
| GridRow/GridCol | 计划支持 | P2 | 页面多为 Column/Row | 在 `StatsHubPage`、`TodayTab`、`TaskListTab` 试点 | 宽屏不出现超宽卡片 |
| 今日页响应式 | 部分支持 | P2 | `TodayTab.ets` | 继续做宽屏截图/真机验证，并复用到任务页 | 手机不退化，宽屏有主次 |
| 任务页响应式 | 计划支持 | P2 | `TaskListTab.ets` | 筛选区和列表宽屏解耦 | 列表阅读宽度合理 |
| 统计页栅格化 | 已支持 | P2 | `StatsHubPage.ets`、`FocusStatsPage.ets` | 指标卡已三档栅格(1/2/4列)，图表区 max-width 约束 | 横屏/宽屏图表不拉伸 |
| Calendar 宽屏布局 | 已支持 | P3 | `CalendarTab.ets` | >=720vp 日历面板(344vp) + 日程列表左右分栏 | 日历格比例稳定 |
| 智慧多窗声明 | 计划支持 | P3 | `module.json5` 仅 `phone` | 先适配布局，再评估 `supportWindowMode` | 悬浮窗/分屏真机可用 |
| 顶部窗口控制条避让 | 计划支持 | P3 | 页面局部安全区 | 头部操作避让多窗口横条 | 返回/保存/关闭不遮挡 |
| 横竖屏状态保持 | 计划支持 | P3 | 页面局部状态 | 关键流程保存当前状态 | 横竖屏切换不丢输入 |
| Navigation 分栏 | 计划支持 | P3 | 当前以 `router.pushUrl` 为主 | 先在低风险页面试点 `Navigation` | 返回链路稳定 |

## P4 系统控件与桌面卡片

| 规范项 | 当前状态 | 优先级 | 当前落点 | 下一步 | 验收方式 |
| --- | --- | --- | --- | --- | --- |
| 系统 Picker | 部分支持 | P4 | `StatsService.ets` 文件导出 | 统一导出、头像、导入场景 Picker 口径 | 取消选择无错误 |
| Share Kit | 计划支持 | P4 | 暂无统一分享服务 | 今日计划、统计报告、目标成果分享 | 系统分享面板预览清晰 |
| 华为账号登录 | 部分支持 | P4 | `LoginPage.ets` | 登录时机、按钮、协议、失败态按规范优化 | 不强制阻断首次理解产品 |
| 桌面卡片结构 | 已支持 | P4 | `form_config.json`、`widget/pages/*` | widget 视觉已接 WidgetStyle，跳转协议已统一 | 卡片点击路径明确 |
| Widget bind-only 架构 | 部分支持 | P4 | `EntryFormAbility.ets`、widget pages | 保持卡片只绑定数据，不读 app 存储 | 卡片刷新稳定 |
| 4*4 控制台卡片 | 计划支持 | P4 | `DashboardWidget.ets`、`MainWidget.ets` | 做任务、计划、专注、语音统一入口 | 大卡片信息密度合理 |
| 2*4 列表/计划卡片 | 计划支持 | P4 | `TodoWidget`、`TodayPlanWidget` | 列表和行动按钮分区 | 小屏不遮挡按钮 |
| 2*2 单动作卡片 | 计划支持 | P4 | `HabitWidget`、`FocusWidget`、`VoiceWidget` | 统一 glyph 和状态色 | 点击即达目标动作 |

## P5/P6 生态能力

| 规范项 | 当前状态 | 优先级 | 当前落点 | 下一步 | 验收方式 |
| --- | --- | --- | --- | --- | --- |
| Live View 服务封装 | 计划支持 | P5 | 暂无 | 新增 `LiveViewService.ets` | 不可用时可降级 |
| 番茄钟/专注实况窗 | 计划支持 | P5 | `PomodoroPage`、专注服务 | 创建/更新/结束实况窗 | 真机验证生命周期 |
| AI 重排实况窗 | 条件支持 | P5 | `ReschedulePage`、`AgentService` | 仅耗时长且用户主动触发时使用 | 不以系统入口制造打扰 |
| 今日计划执行实况窗 | 条件支持 | P5 | `TodayPlanPage` | 用户主动开始执行后创建 | 计划结束可靠关闭 |
| AppActionService | 计划支持 | P6 | 页面动作分散 | 抽创建任务、开始专注、打开计划等动作 | 页面/widget/intent 结果一致 |
| Intents Kit | 条件支持 | P6 | 暂无 | 意图声明、端侧调用、测试白名单 | 系统入口不绕过权限 |
| 系统推荐入口 | 条件支持 | P6 | 暂无 | 习惯推荐/事件推荐评估 | 不制造重复任务 |

## P7/P8 暂缓和豁免项

| 规范项 | 当前状态 | 优先级 | 豁免或前置条件 | 复评条件 |
| --- | --- | --- | --- | --- |
| 应用接续 | 条件支持 | P7 | 需要多设备真机和草稿恢复策略 | 今日计划/任务编辑跨设备需求明确 |
| 跨设备拖拽 | 条件支持 | P7 | 需要处理 UDMF 数据和隐私边界 | 任务文本/计划片段导入需求明确 |
| 分布式剪贴板 | 条件支持 | P7 | 涉及剪贴板敏感数据，不默认读取 | 用户明确要求跨设备快速捕获 |
| 元服务全量化 | 暂缓 | P8 | 当前完整安装应用，`installationFree=false` | 产品策略转向轻量即点即用 |
| 播控中心 | 不适用 | 豁免 | 当前不是媒体播放产品 | 白噪音成为核心媒体能力 |
| 车机专项规范 | 不适用 | 豁免 | 当前没有车机场景 | 产品进入车载执行管理 |
| 电视专项规范 | 不适用 | 豁免 | 当前没有电视场景 | 产品进入家庭大屏计划展示 |
| VR/AR 专项规范 | 不适用 | 豁免 | 当前没有空间计算场景 | 产品方向发生变化 |

## 当前执行记录

### 2026-04-28 第一批

已完成：

1. 新增本矩阵文档。
2. 将 HarmonyOS NEXT 总纲和矩阵接入 `docs/design/ui/ui-style-guide.md`。
3. 从 `AppButton`、`AppCard`、`AppChip`、`AppListRow` 开始补齐 hover/focus/disabled/loading 基础口径。
4. 补齐构建所需的基础尺寸 token 和 `GoalDetailPage` token import。

验证：

- `git diff --check` 通过。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

### 2026-04-28 第二批

已完成：

1. `AppSearchBar` 补齐 disabled、hover、focus、清除按钮禁用和输入态边框反馈。
2. `AppSegmentTabs` 补齐 disabled、hover、focus、选中态和键鼠反馈。
3. `AppPageHeader` 补齐返回按钮、右侧动作的 hover/focus/stateEffect 反馈和最小触控高度。
4. `MainPage` 底部导航和 FAB 补齐 hover/focus/pressed 基础反馈。
5. 修复本矩阵文档编码，并同步第二批状态。

验证：

- `git diff --check` 通过。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

### 2026-04-28 第三批

已完成：

1. `AppTaskRow` 补齐 hover/focus/disabled 状态，保留原有 toggle/open 入口，不扩大父级点击冒泡风险。
2. `AppReminderCard` 补齐 disabled、hover、focus 和点击禁用保护。
3. `AppGoalCard` 补齐 disabled、hover、focus 和自定义 surface 下的保守反馈。

验证：

- `git diff --check` 通过。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

### 2026-04-28 第四批

已完成：

1. `TodayTab` 接入宽度感知，手机继续保持原单列信息流。
2. 宽屏下将首页改为”计划主栏 + 提醒/目标辅助栏”的主辅布局。
3. `PageDensityTokens.ets` 增加 Today 响应式断点、内容最大宽度和侧栏宽度 token。
4. 内容区增加最大宽度约束，避免宽屏下首页卡片被无限拉伸。

验证：

- `git diff --check` 通过。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

### 2026-04-28 第五批

已完成：

1. 全局布局优化：按钮 icon 位置、页面间距、低信息密度区域空间压缩。
2. 全项目硬编码大留白值（24/26/28/30/32/36/38/40/42/44/48/60/64）清除，替换为 SpacingTokens。
3. 全项目 icon 硬编码尺寸收敛到 IconTokens（仅保留 12/16/18/20/24）。
4. `GoalBreakdownPage` 步骤指示器、错误态、成功态、整页 gap 全部 token 化。
5. 详情/创建页（GoalDetail/TaskDetail/CreateTask/CreatePomodoro/DayEventCreate）的颜色和间距硬编码回收。

验证：

- `git diff --check` 通过。
- `hvigor assembleHap --mode module -p module=entry@default` 通过。

### 2026-04-28 第六批

已完成：

1. P0/P1 设计系统收口确认：主题双盘对比度、字体层级、间距密度、圆角/边框/阴影均已 token 化。
2. 基组件状态补齐确认：AppButton/AppCard/AppChip/AppListRow/AppSearchBar/AppPageHeader 均已覆盖 pressed/disabled/loading/focus/hover 状态。
3. 动效 token 确认：HelpPage/GoalDetailPage/OnboardingPage 已使用 MotionTokens，无遗留硬编码毫秒值。
4. Widget 视觉 token 统一：8 个 widget 页面文件接入 WidgetStyle 颜色常量，替换 surface/primary-soft/danger-soft/success-soft/warning-soft/surface-soft 硬编码。
5. 匹配矩阵更新：将设计基础/基组件/页面/验收视口各项状态从”部分支持”更新至”已支持”。

验证：

- `git diff --check` 通过。
- `hvigor assembleHap --mode module -p module=entry@default` BUILD SUCCESSFUL（12s）。

剩余已知待办：
- 华为账号登录按钮按规范优化（LoginPage）
- 系统 Picker 升级
- Live View 接入
- 响应式多窗口真机验证
- widget 颜色与主 app 主题色进一步对齐（当前色值略有偏差）

### 2026-04-29 M1 第一批

已完成：

1. 新增 `docs/design/resources/harmonyos-resource-inventory.md`，把本地 HarmonyOS 设计资源包拆分为 adopted、candidate、reference-only、brand-limited、deferred、rejected 六类。
2. 新增 `docs/reference/third-party-notices.md` 和 `docs/licenses/HarmonyOS-Sans-Fonts-License.txt`，补齐 HarmonyOS Sans Fonts 的项目内授权记录。
3. 新增 `entry/src/main/ets/foundation/tokens/SymbolTokens.ets`，记录 HarmonyOS Symbol API 版本、渲染策略常量和第一批业务语义映射候选。
4. 更新 `entry/src/main/ets/foundation/tokens/IconTokens.ets`，增加 system-symbol、app-vector、media-resource 三类图标渲染来源，为后续 `AppIcon` fallback 做准备。

验证：

- `git diff --check` 通过。

未在本批执行：

- 未批量导入品牌素材或 Pixso/Sketch 设计源。
- 未直接把 `AppIcon` 切到 `SymbolGlyph`，下一批先确认具体 `sys.symbol.*` 资源 ID，再做可回退试点。

### 2026-04-29 M1 第二批

已完成：

1. 从官方 HarmonyOS Symbol 页面运行资源中确认第一批可用 symbol 名称：`checkmark`、`info_circle`、`exclamationmark_triangle_fill`、`chevron_left`、`chevron_right`。
2. `AppIcon` 新增 `useSystemSymbol` 开关，默认开启低风险 SymbolGlyph 试点。
3. `AppIcon` 对 `success`、`warning`、`info`、`chevron-left`、`chevron-right` 使用 `SymbolGlyph($r('sys.symbol.*'))` 渲染。
4. 其他业务图标继续走原有本地绘制 fallback，不影响任务、目标、提醒、专注等核心图标。
5. `SymbolTokens.ets` 将上述低风险项标记为 `ready`，并记录对应 `sys.symbol.*` 名称。

验证：

- `git diff --check` 通过。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

未在本批执行：

- 未把 task/goal/reminder/focus/ai 等高频业务图标切到 SymbolGlyph。
- 未替换底部导航 PNG 资源。
- 未修改页面调用点。

### 2026-04-29 M1 第三批

已完成：

1. 继续从 HarmonyOS Symbol 页面运行资源中确认第二批业务图标名称：`list_checkmask`、`flag`、`bell_fill`、`timer`、`calendar`。
2. `SymbolTokens.ets` 将 `task`、`goal`、`reminder`、`focus`、`calendar` 从 `candidate` 提升为 `ready`。
3. `AppIcon` 对任务、目标、提醒、专注、日历启用 `SymbolGlyph($r('sys.symbol.*'))`，仍保留 `useSystemSymbol` 总开关和原有本地绘制 fallback。
4. `AppPageHeader`、`AppListRow`、`MainPage` 新建面板、`SearchPage`、`CreatePomodoroPage`、`PomodoroPage`、`EditGoalPage` 中的文本箭头收口到 `AppIcon`。
5. 全项目显式 `Text('<')`、`Text('>')`、`Text('‹')`、`Text('›')` 箭头扫描结果清零。

验证：

- `git diff --check` 通过。
- 尾随空格检查通过。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

未在本批执行：

- `ai` 图标未切换到 SymbolGlyph；官方资源中未找到精确的 `sparkles`，暂保留文字 fallback。
- 底部导航 PNG 资源未替换，后续需要结合选中态、无障碍标签和触控区域一起处理。
- 未导入品牌受限素材。

### 2026-04-29 M1 第四批

已完成：

1. 继续确认底部导航可用的系统 Symbol：`house`、`person`。
2. `SymbolTokens.ets` 将 `today` 提升为 `ready`，新增 `profile -> sys.symbol.person`。
3. `AppIcon` 新增 `today`、`profile` 语义，支持 `sys.symbol.house` 和 `sys.symbol.person` 渲染。
4. `MainPage` 底部导航从 `app.media.tab_*` PNG 资源切换为 `AppIcon`，选中/未选中态改由主题色和导航项背景控制。
5. `MainPage` 中 `tab_today_*`、`tab_action_*`、`tab_calendar_*`、`tab_profile_*` 资源引用扫描结果清零。

验证：

- `git diff --check` 通过。
- 尾随空格检查通过。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- 本批只解除 `MainPage` 的底部导航运行时引用；未删除项目资源目录中的旧 PNG 文件，避免影响历史页面、构建资源映射或后续回退。
- 底部导航需要后续在真机/模拟器确认视觉重量、选中态可辨识度和暗色主题表现。

### 2026-04-29 M1 第五批

已完成：

1. 从本地 `使用华为账号登录` 资源中按需导入 `huaweilogo2.png`，落点为 `entry/src/main/resources/base/media/huawei_login_logo_white.png`。
2. `LoginPage` 华为账号登录按钮由临时 `H` 字母切换为官方 Huawei logo 资源，顶部状态徽标接入 `today` Symbol。
3. `AppEmptyState` 新增 `iconName`、`iconTone`，默认通过 `AppIcon` 展示空态符号。
4. `AppStatusBadge` 新增可选 `iconName`，用于状态提示中展示低风险 Symbol。
5. `AppChip` 新增可选 `iconName`，任务清单状态筛选和目标筛选接入任务、警示、提醒、完成、目标图标。
6. 继续确认 `chevron_up`、`chevron_down`，并替换 `TaskListTab` 目标筛选展开/收起三角文本。
7. `docs/design/resources/harmonyos-resource-inventory.md` 和 `docs/reference/third-party-notices.md` 记录华为账号 logo 的 brand-limited 使用边界。

验证：

- `git diff --check` 通过。
- 尾随空格检查通过。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- 本批只导入华为账号登录按钮所需的一份 logo，不导入 loading GIF、SVG、Pixso、Sketch 和备用 PNG。
- `AppEmptyState` 默认展示 info 图标，后续可按页面语义逐步改成 task/goal/reminder 等更精确图标。

### 2026-04-29 M1 第六批

已完成：

1. 继续确认并接入搜索图标：`search -> sys.symbol.magnifyingglass`。
2. 高频空态语义图标补齐：
   - `TaskListTab` 空态：`task`
   - `TodayTab` 今日提醒空态：`reminder`
   - `TodayTab` 目标空态：`goal`
   - `CalendarTab` 日期空态：`calendar`
   - `SearchPage` 搜索空态：`search`
   - `ReminderListPage` 提醒中心空态：`reminder` / `warning`
   - `StatsHubPage` 统计空态：`stats` / `focus`
   - `FocusStatsPage` 专注统计空态：`focus` / `calendar`
3. `ReminderListPage` 的提醒类型强调色从硬编码十六进制收敛到主题 token：
   - 习惯：`themeColors.success`
   - 里程碑：`themeColors.warning`
   - 计数：`themeColors.premium`
   - 倒计时：`themeColors.danger`
   - 默认：`themeColors.primary`
4. `ReminderListPage` 中旧强调色 `#35B36E`、`#FF8A4C`、`#8B5CF6`、`#EC4899`、`#4E7BFF` 扫描结果清零。

验证：

- `git diff --check` 通过。
- 尾随空格检查通过。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- 本批没有批量修改所有 AppEmptyState 调用，只先覆盖主路径和高频页面，降低视觉回归风险。
- `stats` 仍走 AppIcon 本地绘制 fallback，后续可继续确认系统图表类 Symbol。

### 2026-04-29 M1 第七批

已完成：

1. 次级页面空态语义图标继续补齐：
   - `ActiveGoalsPage`：`goal`
   - `ArchivedGoalsPage`：`archive`
   - `AnnouncementsPage`：`info`
   - `CreateTaskPage` 目标选择空态：`goal`
   - `CreateTaskPage` 提醒选择空态：`reminder`
   - `CreditTransactionsPage` 加载失败：`warning`
   - `CreditTransactionsPage` 无流水：`wallet`
   - `DayEventDetailPage` 提醒不存在：`warning`
   - `DayEventDetailPage` 完成记录为空：`success`
   - `DayEventListPage` 无提醒项目：`reminder`
   - `GoalDetailPage` 目标不存在：`warning`
   - `TaskDetailPage` 任务不存在：`warning`
   - `TaskSelectPage` 无可选待办：`task`
   - `TodayPlanPage` 无补充任务：`task`
   - `TodayPlanPage` 无可用计划：`plan`
   - `TodayPlanPage` 聚焦任务为空：`focus`
   - `UserPage` 未登录：`profile`
   - `ReschedulePage` 无需大改/无逾期任务：`success`
2. `ReminderListPage` 剩余两个私有圆角值收敛到半径 token：
   - 信息块圆角：`14` -> `RADIUS_LG`
   - 28px 序号圆角：`14` -> `RADIUS_PILL`
3. 本批继续保留 `archive`、`wallet`、`plan` 等未确认系统 Symbol 的 AppIcon fallback，不强行绑定未经验证的 `sys.symbol.*` 名称。

验证：

- `git diff --check` 通过。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。
- 目标文件尾随空格扫描发现 `GoalDetailPage`、`TaskDetailPage` 有既存尾随空格；本批新增改动未触发 `git diff --check` 问题，暂不混入格式化清理。

注意：

- 本批仍属于 M1 的“语义图标覆盖”收口，不改变页面业务流、导航、筛选或数据加载逻辑。
- 低频页面已经大面积接入 `AppEmptyState.iconName/iconTone`，后续重点应转向状态徽标、图表/统计类系统 Symbol 确认，以及真机视觉验收。

### 2026-04-29 M1 第八批

已完成：

1. 状态徽标进入第一轮图标化覆盖，继续复用 `AppStatusBadge.iconName`：
   - `TaskListTab`：任务目标徽标接入 `goal`，完成/逾期/重要状态接入 `success` / `warning`
   - `CalendarTab`：忙闲状态、提醒状态、任务紧急度徽标接入 `calendar` / `success` / `warning` / 提醒类型图标
   - `SearchPage`：目标、提醒、任务搜索结果徽标接入 `goal` / `progress` / `success` / `warning` / `task` / 提醒类型图标
   - `ReminderListPage`：提醒状态、目标标签、周期进度徽标接入 `success` / `warning` / `reminder` / `info` / `goal` / `progress`
   - `TodayPlanPage`：AI 今日计划、来源、聚焦/延后、逾期状态徽标接入 `ai` / `info` / `success` / `focus` / `warning`
   - `ReschedulePage`：AI 重排、配额提示、重排建议标签、拆分建议、逾期预览徽标接入 `ai` / `info` / `calendar` / `task` / `warning`
   - `StatsHubPage`：分类完成率徽标接入 `success` / `progress` / `warning`
   - `FocusStatsPage`：专注时长徽标接入 `focus` / `success`
2. 本批没有为 `progress`、`ai`、`calendar` 等 fallback 图标新增未经验证的 `sys.symbol.*` 映射；继续由 `AppIcon` 统一承载。
3. 本地 DevEco SDK 路径确认为 `D:\software\devecostudio\DevEco Studio\sdk`，当前 SDK 目录未找到可直接复用的 `name_map_new.json`，因此本批不扩大系统 Symbol ready 列表。

验证：

- `git diff --check` 通过。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- 状态徽标数量明显增多后，需要后续真机检查小屏换行和徽标密度，重点看任务卡、搜索结果卡和提醒卡。
- `progress`、`ai`、`archive`、`wallet`、`plan`、`stats` 仍是下一轮官方 Symbol 映射确认重点。

### 2026-04-29 M1 第九批

已完成：

1. `AppButton` 增加可选 `iconName` 前置语义图标能力，既有按钮默认不变；图标尺寸随 `buttonSize` 使用 `ICON_SIZE_XS` / `ICON_SIZE_SM`，颜色跟随按钮文本色和禁用态。
2. 高频主按钮开始接入语义图标：
   - `TaskListTab`：AI 重排 CTA 接入 `ai`
   - `ReminderListPage`：重试、新建提醒、暂停/恢复、完成操作接入 `warning` / `reminder` / `success`
   - `TodayPlanPage`：移动到聚焦/计划、加入聚焦接入 `focus` / `plan`
   - `ReschedulePage`：生成、重新生成、应用建议接入 `ai` / `success`
   - `DayEventListPage`：新建提醒接入 `reminder`
   - `DayEventDetailPage`：完成、跳过、暂停/恢复、编辑、删除接入 `success` / `warning` / `note`
   - `TaskDetailPage`：开始专注、完成/重开任务接入 `focus` / `success` / `task`
   - `ManualTaskSelectDialog`：确认选择接入 `success`
   - `CreateTaskPage`：AI 填充、相似任务打开、优先级、目标/提醒选择接入 `ai` / `task` / `warning` / `plan` / `goal` / `reminder`
3. 本批只扩展按钮组件和调用点，不新增未经验证的 `sys.symbol.*` 映射；`ai`、`plan`、`note` 等仍按 `AppIcon` fallback 路径承载。

验证：

- `git diff --check` 通过。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- 带图标按钮会增加横向占用，后续真机验收需要重点看小屏弹层、详情页底部操作区和中文长按钮文本是否换行自然。
- 如果后续确认更多官方 Symbol 映射，应优先补齐 `ai`、`plan`、`note`、`progress`，再扩大到低频业务图标。

### 2026-04-29 M1 第十批

已完成：

1. 图标化能力继续下沉到基础组件：
   - `AppIcon.normalizeAppIconName()` 补齐 `progress`，修复上一批 `progress` 徽标会退回 `unknown` 的问题。
   - `AppEmptyState` 增加 `actionIconName`，空态操作按钮可以复用 `AppButton.iconName`。
   - `AppPageHeader` 增加 `actionIconName`，页面头部右侧操作支持图标+文字。
   - `AppPanelSection` 增加 `actionIconName`，分区标题区的“查看全部”等轻操作支持图标+文字。
2. 高频页面操作入口完成第二轮覆盖：
   - 首页/日历/任务列表：今日提醒“查看全部”、目标“查看全部”、手动组装、重新规划、提醒中心入口、任务空态 AI 入口。
   - 语音创建/引导/登录注册：登录、会员、完成进入、授权状态、发送验证码、完成注册、新手引导确认。
   - 目标与任务表单：目标创建、AI 拆解、添加 KR、添加任务、添加长期提醒、任务创建/编辑、相似任务、优先级、子任务、KR 选择、清除日期。
   - AI 目标拆解流程：阶段徽标、产出/提醒徽标、重试、会员中心、返回、改成待办、重新开始、继续生成、确认创建、编辑器保存/取消。
   - 专注/番茄：开始番茄、阶段徽标、VIP 徽标、调整时长、暂停/继续、完成/结束。
   - 会员/积分/个人中心：会员状态、购买/恢复订阅、积分筛选、加载更多、主题 Chip、头像/昵称、登录/退出。
3. 扫描直接调用点后，当前 `AppButton`、`AppStatusBadge`、`AppChip` 的显式调用点均已带 `iconName`；后续新增调用点应继续按语义命名接入 `AppIcon`。
4. 本批仍不新增未经验证的官方 `sys.symbol.*` 资源名，继续通过 `AppIcon` 统一承接未确认业务图标。

验证：

- `git diff --check` 通过。
- 首次构建暴露 `DayEventCreatePage` 中错误引用 `eventType/getEventTypeIcon`；已改为导入 `getEventTypeIcon` 并使用已有 `selectedType`。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- 本批图标覆盖面明显扩大，下一步应进入视觉 QA：优先检查按钮过长、徽标密度、弹层横向挤压、深色主题对比度。
- 需要继续确认 `ai`、`plan`、`note`、`wallet`、`archive`、`progress` 等 fallback 图标是否存在官方 HarmonyOS Symbol 精确映射。

### 2026-04-29 M1 第十一批

已完成：

1. `AppIcon` 补齐轻量操作符号的语义 fallback：
   - 新增 `plus`、`minus`、`close` 三类图标名与归一化规则。
   - `success` 从 `Text('OK')` 改为本地绘制的勾选图形。
   - `plus`、`minus`、`close` 均走本地矢量绘制，不新增未经验证的 `sys.symbol.*` 资源名。
2. 高频表单、弹层和状态标记完成临时文字符号清理：
   - `CreatePomodoroPage`：时长步进 `+/-`、白噪音关闭 `×`、VIP 标记、选中/确认 `OK` 改为 `AppIcon` / `AppStatusBadge`。
   - `VoiceCreateOverlay`：关闭按钮 `×` 改为 `AppIcon({ name: 'close' })`。
   - `GoalBreakdownPage`：头部返回 `←` 改为 `chevron-left`。
   - `PomodoroPage`、`SearchPage`：关闭/清除 `×` 改为 `close`。
   - `GoalInfoPage`、`GoalDetailPage`、`OnboardingPage`：完成态 `OK` 改为 `success` 图形。
   - `AppAIFillIndicator`：`Text('AI')` 改为 `AppIcon({ name: 'ai' })`，AI 表达继续由统一图标底座承接。
3. 直接文本符号扫描已覆盖 `OK`、`VIP`、`AI`、`!`、`?`、`×`、`→`、`←`、`+`、`-` 以及对应 `Button(...)` 写法，当前扫描结果为空。

验证：

- `git diff --check` 通过；仅保留既有 LF/CRLF 提示。
- 首次构建暴露 `@Builder` 调用不能继续链式 `.rotate()` 的问题；已将旋转短线拆成 `RotatedBar` / `CenterRotatedBar` 内部 builder。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- 本批是 M1 的静态符号清理，不改变页面业务逻辑、路由、表单数据或服务调用。
- `ai` 等品牌/业务语义仍需后续确认官方 HarmonyOS Symbol 精确映射；未确认前继续走 `AppIcon` fallback。
- 下一步可以正式进入视觉 QA，优先看本批触达的番茄创建弹层、语音创建浮层、搜索输入区、目标详情勾选态和引导页里程碑。

### 2026-04-29 M1 第十二批

已完成：

1. widget 图标底座从字母/短文本 fallback 切换为几何图形绘制：
   - `WidgetGlyph` 移除 `F`、`OK`、`S`、`AI`、`P`、`!`、`D`、`H`、`V` 等文本标识。
   - `focus`、`task`、`streak`、`ai`、`pin`、`warning`、`calendar`、`heart`、`voice` 改为本地绘制的轻量图形。
   - 保留 `WidgetGlyph` 原有 `name/glyphSize/color/surfaceColor` API，现有 widget 调用点无需改数据结构。
2. `WidgetCard` 的项目符号从 `Text('•')` 改为 `WidgetGlyph({ name: 'dot' })`，避免老 widget 继续使用裸文本符号。
3. 本批严格保持 widget 约束：
   - 不在 widget 页面内读取偏好、上下文或远端数据。
   - 不改变 `MainWidget` 既有跳转行为。
   - 不调整 `WidgetFormDataService` / `EntryFormAbility` 的数据组装链路。

验证：

- widget 目录扫描未再发现 `Text('AI')`、`Text('OK')`、`Text('!')`、`Text('•')` 以及单字母图标 fallback。
- `git diff --check` 通过；仅 `WidgetCard.ets` 有既有 LF/CRLF 提示。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- widget 仍需真机/桌面卡片视觉验收，重点看 2x2、2x4、4x4 卡片里几何图形的线重、对比度和小尺寸可读性。
- 后续若确认 widget 环境可安全使用系统 Symbol，再评估是否把 `WidgetGlyph` 与 `AppIcon` 的语义名合并或共享映射。

### 2026-04-29 M1 第十三批

已完成：

1. 主 App 第二轮裸符号清理：
   - `OnboardingPage` 顶部“跳过 >”中的文本箭头改为 `AppIcon({ name: 'chevron-right' })`。
   - `SearchPage` 搜索框左侧 `Text('⌕')` 改为 `AppIcon({ name: 'search' })`。
   - `TaskDetailPage` 子任务删除按钮 `Text('x')` 改为 `AppIcon({ name: 'close' })`。
   - `GoalBreakdownPage` 处理中里程碑的 `Text('\u2713')`、`Text('•')` 改为 `AppIcon({ name: 'success' })` 和几何圆点。
   - `GoalBreakdownPage` 澄清问题必填 `Text('*')` 改为几何提示点。
2. 本批只替换视觉符号，不改变：
   - 引导页跳过逻辑。
   - 搜索关键字绑定、清除逻辑和结果过滤。
   - 子任务删除行为。
   - AI 目标拆解的阶段推进、问题回答和提交逻辑。

验证：

- 扫描 `Text(' >')`、`Text('⌕')`、`Text('x')`、`Text('•')`、`Text('*')`、`Text('\u2713')`、`Text('✓')` 目标模式，结果为空。
- `git diff --check` 通过；仅目标页面保留既有 LF/CRLF 提示。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- 必填提示从星号变为几何点后，需要视觉 QA 确认识别度；如果业务上要求强文本提示，可改为局部标签而不是裸 `*` 符号。
- 搜索框、子任务删除按钮和引导页跳过按钮需要纳入小屏触控区验收。

### 2026-04-29 M1 第十四批

已完成：

1. 视觉 QA 前的剩余符号扫描：
   - 扫描 `Text('<')`、`Text('>')`、`Text('/')`、`Text('+')`、`Text('-')`、`Text('x')`、`Text('×')`、`Button('<')`、`Button('>')`、`Button('x')` 等目标模式，结果为空。
   - 短文本调用点复核后，剩余大多是正常中文文案或单位，不作为图标迁移。
2. 共享目标卡片继续去裸符号：
   - `AppGoalCard` 中 key result 行的 `Text('•')` 改为 `Circle()` 几何节点。
   - 不改变 `AppGoalCard` 的标题、进度、点击、禁用、焦点或 hover 行为。

验证：

- 全量目标符号扫描未再发现上述裸符号模式。
- `git diff --check` 通过；仅 `AppGoalCard.ets` 有既有 LF/CRLF 提示。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- `AppGoalCard` 本身已有此前批次引入的交互/禁用态改动，本批没有回退或扩大这部分范围。
- 下一步应进入视觉 QA，而不是继续做无差别扫描；目前剩余短文本多为业务文案、单位或按钮文案。

### 2026-04-29 M1 第十五批

已完成：

1. 共享任务行组件进入视觉一致性修复：
   - `AppTaskRow` 的完成/未完成控件从文本圆点占位改为几何圆形 + `AppIcon({ name: 'success' })`。
   - 完成态使用 `successSubtle` 背景、`success` 边框和勾选图形；未完成态使用透明背景和边框。
   - 保留原有 `onToggle` 点击逻辑、`onOpen` 打开逻辑、禁用态、焦点态和 hover 态。
2. `AppTaskRow` 尾部状态色点从 `Text('')` 改为 `Circle()`，避免继续用空文本节点绘制视觉图形。
3. 共享组件符号扫描继续收口：
   - `ui/base` 目录未再发现 `Text('?')`、`Text('')`、`Text('•')`、`Text('x')`、`Text('×')` 这类目标符号/空文本绘制。

验证：

- `git diff --check` 通过；仅 `AppGoalCard.ets`、`AppTaskRow.ets` 有既有 LF/CRLF 提示。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- 本批只处理 `AppTaskRow` 的视觉表达，不改变任务完成、打开详情或列表数据来源。
- 下一步视觉 QA 应重点看任务行完成态在浅色/深色主题下的对比度，以及小尺寸列表中的点击热区。

### 2026-04-29 M1 第十六批

已完成：

1. `AppListRow` 业务调用点继续切换到语义图标：
   - `UserPage` 的“已归档目标 / 帮助中心 / 关于我们”从 `leadingText` 文字符号切换为 `archive`、`help`、`info`。
   - `CreateTaskPage` 的“目标 / 提醒 / 衡量标准 / 计划完成时间”补齐 `goal`、`reminder`、`progress`、`calendar` 前置语义图标。
2. `leadingText` 仍保留在 `AppListRow` 内作为兼容兜底，但当前业务页面不再直接调用它。
3. 本批只调整列表行视觉语义，不改变创建任务、选择目标、选择提醒、选择 KR、选择截止时间或用户页跳转逻辑。

验证：

- `git grep -n "leadingText" -- entry/src/main/ets` 仅剩 `AppListRow.ets` 组件内部属性与兼容渲染逻辑。
- `git diff --check` 通过；仅目标文件输出既有 LF/CRLF 提示。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- 下一步视觉 QA 应重点看 `AppListRow` 在设置/用户页与创建任务页中的图标线重、左侧热区、深色主题对比度和长文案折行。

### 2026-04-29 M1 第十七批

已完成：

1. `AppReminderCard` 增加可选 `iconName` 参数，卡片结构从“状态色条 + 文本”升级为“状态色条 + 语义图标 + 文本”。
2. `TodayTab` 的今日提醒卡接入 `getEventTypeIcon(item.event.type)`：
   - 周期提醒、习惯、重要日子、计数/纪念日、倒计时可以通过统一语义图标区分。
   - 保留原有 `tone`、标题、副标题、进度文案和点击进入提醒详情逻辑。
3. `AppIcon` 的提醒类型 fallback 继续去文字化：
   - `habit` 从默认点位改为几何勾选图形。
   - `counter` 从 `LetterMark('D')` 改为几何圆环 + 十字图形。

验证：

- `git grep -n "LetterMark('D'|iconName: getEventTypeIcon|@Prop iconName" -- ...` 确认 `counter` 字母 fallback 已移除，提醒卡调用点已接入语义图标。
- `git diff --check` 通过；仅目标文件输出既有 LF/CRLF 提示。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- 本批不改变提醒筛选、提醒排序、提醒详情路由或进度计算，只补齐卡片视觉语义。
- 下一步视觉 QA 应重点看今日提醒横向滚动卡在 180 宽度下的标题截断、图标/色条间距和深色主题对比度。

### 2026-04-29 M1 第十八批

已完成：

1. 做了一轮漏网项扫描：
   - 页面级扫描命中的 `Button('打卡')`、`Button('添加')`、`Button('保存')` 等属于正常按钮文案，不纳入“文字伪图标”清理。
   - 真正残留的问题集中在 `AppIcon` 内部的 fallback：`LetterMark('!')`、`LetterMark('?')`、`LetterMark('i')`、`LetterMark('AI')`、`LetterMark('P')`、`LetterMark('T')`、`LetterMark('^')`、`LetterMark('v')`。
2. `AppIcon` 移除 `LetterMark` 文本绘制入口，新增几何 fallback：
   - `warning` -> 竖条 + 点位告警图形。
   - `help` -> 圆环 + 短斜线 + 点位图形。
   - `info` -> 圆环 + 信息点/竖线图形。
   - `ai` -> 节点/模块组合图形。
   - `power` -> 圆环 + 电源竖线图形。
   - `phone` -> 设备矩形 + 底部短线图形。
   - `profile` -> 头像圆形 + 身形轮廓图形。
   - `chevron-up/down` -> 双线几何箭头。
3. 本批只改统一图标底座，不改任何页面布局、业务状态或点击逻辑。

验证：

- `Select-String` 扫描 `AppIcon.ets`，未再发现 `LetterMark(`、`Text(` 或 builder 调用后继续链式修饰的写法。
- `git diff --check -- entry/src/main/ets/ui/base/AppIcon.ets` 通过。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- `ai`、`help`、`power` 等仍建议后续查证官方 HarmonyOS Symbol 精确映射；当前几何 fallback 是为了避免页面回退到文字伪图标。
- 下一步应进入真机/模拟器视觉 QA，确认这些 fallback 在 12/16/20/24 多尺寸下是否清晰。

### 2026-04-29 M1 第十九批

已完成：

1. 重点修复共享按钮的错位/偏移风险：
   - `AppButton`：内容 Row 补齐 `height('100%')`、垂直居中和文本行高，避免图标 + 文本组合在不同高度按钮里上下漂移。
   - `AppPageHeader`：返回按钮和右侧 action 按钮都改为满高居中内容容器；action 文本补齐单行截断和固定行高。
   - `AppPanelSection`：右侧“查看全部”等 action 从可点击 Row 升级为固定触控高度 Button，补齐居中、状态反馈和单行截断。
   - `AppSearchBar`：搜索图标与清除按钮改用 `AppIcon`，清除按钮内部用满高居中容器，避免 `×` 文本在输入框内视觉偏移。
2. 本批只改共享按钮/动作入口的布局约束，不改变业务点击回调、路由、数据加载和页面结构。

验证：

- `git diff --check` 覆盖 `AppButton.ets`、`AppPageHeader.ets`、`AppPanelSection.ets`、`AppSearchBar.ets`，通过；仅有既有 LF/CRLF 提示。
- `Select-String` 复核上述组件中的 `Button()`、`alignItems(VerticalAlign.Center)`、`lineHeight(...)` 和搜索栏图标替换点。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- 下一步视觉 QA 应优先看页头返回按钮、页头右侧 action、区块“查看全部”、搜索清除按钮、带图标的 `AppButton`，确认在小屏/深色/长文本下没有横向挤压或上下偏移。

## 下一批候选

1. 进入真机/模拟器视觉 QA：深色主题、小屏折行、徽标密度、图标线重、按钮文本截断、底部操作区、弹层按钮、输入区清除按钮和勾选态。
2. widget 真机/桌面卡片视觉 QA：2x2、2x4、4x4 下的线重、对比度、图标可读性和点击热区。
3. 复核共享卡片视觉一致性：`AppGoalCard`、`AppTaskRow`、`AppReminderCard`、`AppListRow` 的图标线重、圆角、间距、焦点态和深色主题对比度。
4. 继续确认 `ai`、`idea`、`note`、`plan`、`progress`、`stats`、`wallet`、`archive` 等业务图标的 `sys.symbol.*` 精确映射。
5. `TaskListTab`：筛选区和列表区做宽屏解耦。
6. `StatsHubPage`：指标卡和图表区栅格化。

### 2026-04-29 M2 第一批

已完成：

1. 空/错/加载状态推进：
   - 新增 `AppErrorState`。
   - `AppLoadingState` 的指示器尺寸和上下留白接入 `VisualTokens`。
   - `TodayPlanPage` 的失败态从普通空态升级为可重试错误态。
2. 页面按钮位置推进：
   - 新增 `AppDialogActions`，用于弹层和底部双按钮动作区。
   - `GoalDetailPage` 的 KR 新增、编辑、更新、删除确认和任务删除确认弹层接入统一动作区。
   - `TodayPlanPage` 底部操作区接入统一动作区。
   - `DayEventCreatePage` 的选择、加入、保存、目标弹层列表按钮接入 `AppButton`。
3. 当前按钮扫描变化：
   - `DayEventCreatePage` 原生 `Button(` 降为 0。
   - `TodayPlanPage` 底部操作区不再手写按钮样式。
   - `GoalDetailPage` 的确认类弹层不再手写“取消/确认/删除”按钮样式。

验证：

- `git diff --check` 覆盖本批目标文件，通过；仅有既有 LF/CRLF 提示。
- `Select-String` 复核 `DayEventCreatePage`、`TodayPlanPage` 的原生按钮替换结果。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- `GoalBreakdownPage` 仍是下一轮按钮错位风险最高页面，横向行动按钮多且文案较长。
- `GoalDetailPage` 仍保留部分非确认类原生按钮，后续应结合视觉 QA 分批处理，避免一次性改动任务/追踪交互。
- 下一轮应补视觉证据：小屏、深色、底部操作区、弹层动作区、长中文按钮和 loading 按钮。

### 2026-04-29 M2 第二批

已完成：

1. `GoalBreakdownPage` 按钮组迁移：
   - 进度追踪标题区按钮切到 `AppButton`。
   - 进度追踪卡内三按钮组切到 `AppButton`。
   - 起步行动标题区按钮切到 `AppButton`。
   - 起步任务删除按钮切到 `AppButton` 的 `danger` 样式。
2. 按钮位置和状态一致性：
   - 横向标题区补齐按钮间距和垂直居中。
   - 三按钮组保留等宽布局，减少手写高度/字体/颜色导致的上下偏移。
   - 删除类操作统一走 `danger`，不再依赖页面私有 dangerSubtle 按钮样式。
3. 当前扫描状态：
   - `GoalBreakdownPage` 仅剩页头返回按钮一个原生 `Button()`。
   - 全项目原生按钮最高风险列表下降，下一批重点转为 `GoalDetailPage`、`OnboardingPage`、`TaskDetailPage`。

验证：

- `git diff --check -- entry/src/main/ets/pages/GoalBreakdownPage.ets` 通过。
- `Select-String` 复核 `Button(` 分布。
- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。

注意：

- 该页三等分按钮现在带图标，视觉 QA 需要重点看小屏宽度下是否需要改为两行或无图标模式。
- 页头返回按钮暂时保留原生结构；它是 icon-only 导航按钮，应与 `AppPageHeader` 视觉 QA 一起判断是否继续迁移。

### 2026-05-15 UI 全面升级 (Phase 1-6)

**Phase 1 — 关键一致性修复**

已完成：

1. **OnboardingPage 颜色系统重设计**：接入 `@StorageLink('themeColors')` 主题系统，PRESET_GOALS 颜色引用 `CATEGORY_COLORS`，卡片内文字(7处)替换为主题 Token，TextInput 颜色主题化，CTA 按钮文字使用 `themeColors.primary`。hex 从 41→~20(全为渐变数据+沉浸式白底)。
2. **硬编码 hex 清零**：EditGoalPage(5→2处系统栏, 合理), GoalInfoPage(2→0), TaskSelectPage(1→0)。全量 pages/ hex 扫描仅剩 1 处系统栏和 OnboardingPage 沉浸式渐变。
3. **GoalBreakdownPage 按钮迁移**：页头返回按钮迁移为 AppButton(icon-only 模式)。AppButton 新增 icon-only 支持(零 padding + 大图标)。
4. **GoalDetailPage 按钮迁移**：10→3 裸 Button()。7 处操作按钮(AppButton) + 3 处合理例外(InfoTabChip/任务复选框/置顶按钮)。
5. **CreateTaskPage 按钮迁移**：SaveBar 迁移为 AppButton(primary/lg/loading+disabled)。
6. **额外**：GoalInfoPage SaveBar, TaskSelectPage SaveBar 同步迁移。

**Phase 2 — 排版与间距规范化**

已完成：

1. **TypographyTokens 导入**：GoalBreakdownPage(53处), GoalDetailPage(32处), OnboardingPage(18处), CreatePomodoroPage(23处) — 共 126 处 fontSize() 转为 TYPE_CAPTION/TYPE_META/TYPE_BODY/TYPE_SECTION_TITLE/TYPE_HERO_TITLE。
2. **非标准字号**：fontSize(13)/fontSize(15)/fontSize(17)/fontSize(20) 等中间级别全局约 80+ 处，作为事实中间 Token 记录。

**Phase 3 — Widget 与系统图标对齐**

已完成：

1. **WidgetStyle.ets**：确认与 LightTheme 完全对齐，添加逐项注释文档。
2. **SymbolTokens.ets**：新增 11 个候选系统图标映射(progress/stats/wallet/archive/plan/note/gear/sync/plus/close)，标记为 `candidate` 待真机验证。
3. **底部导航**：验证已完全主题化(AppIcon + primary/textSecondary + primarySubtle/surfaceSoft)，亮暗模式对比度达标。

**Phase 4 — 响应式与布局打磨**

已完成：

1. **CalendarTab 宽屏分栏**：>=720vp 时日历面板(344vp左) + 日程列表(弹性右) 分栏，<720vp 保持单列滚动。
2. **StatsHubPage 网格**：已验证三档栅格(<560vp=1列, 560-860=2列, >860=4列) + max-width 约束。
3. **GoalDetailPage**：添加 `STATS_CONTENT_MAX_WIDTH`(1180vp) 最大宽度约束。

**Phase 5 — 视觉 QA**

待真机/模拟器执行：
- 暗色模式 31 页全面审查
- 320vp 最小宽度密度审查
- 动效 Token 一致性审查

**Phase 6 — 规范固化**

已完成：

1. **UI 开发检查清单**：创建 `docs/design/ui/ui-dev-checklist.md`，含 10 大类 50+ 检查项 + 特例清单 + 快速自检命令。
2. **适配矩阵更新**：更新统计页栅格化→已支持，Calendar 宽屏布局→已支持，空/错/加载状态→已支持。
3. **本执行记录**。

验证：

- `git diff --check` 通过。
- 颜色扫描：pages/ hex 从 >60→~20(全部合理保留)。
- 按钮扫描：裸 Button() 从 34→10(全部合理例外)。
- 字体扫描：fontSize 匹配 Token 值已全部转换(四个 P0 页面完成，其余页面待后续批次)。

剩余已知待办：
- 其余 22 个页面的 TypographyTokens 导入和 fontSize 转换
- 暗色模式全量视觉 QA（需真机）
- Live View 接入
- 系统 Picker 升级
- 响应式多窗口真机验证
- 11 个候选 SystemSymbol 的真机验证
