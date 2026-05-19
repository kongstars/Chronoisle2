# Chronoisle2 UI 规范与风格指南 V2

更新日期：2026-04-28

适用范围：`entry/src/main/ets/` 下的 HarmonyOS ArkUI 主端界面。

优先级：
1. 本文档
2. `entry/src/main/ets/theme/AppTheme.ets`
3. `entry/src/main/ets/foundation/tokens/*`
4. `entry/src/main/ets/ui/base/*`
5. 页面级局部样式

参考来源：
- `docs/design/harmonyos/harmonyos-vnext-resource-adoption-plan.md`
- `docs/design/harmonyos/harmonyos-next-ui-upgrade-plan.md`
- `docs/design/harmonyos/harmonyos-next-adaptation-matrix.md`
- `docs/design/ui/theme-token-spec.md`
- `docs/design/ui/ui-global-style-system-2026.md`
- `docs/design/ui/ui-visual-token-spec.md`
- `docs/design/ui/ui-page-spec.md`
- `docs/design/ui/primary-page-wireframes.md`

说明：
- `docs/design/*` 继续保留为历史设计资料。
- 本文档作为当前可执行的统一 UI 主规范，优先解决文档分散、部分设计文档编码兼容性差、页内样式口径不一致的问题。
- 当前 UI 升级优先收口规范和基础组件状态，不改业务逻辑。

HarmonyOS NEXT 适配关系：
- `docs/design/harmonyos/harmonyos-vnext-resource-adoption-plan.md` 是最新版 HarmonyOS 设计资源采用方案，负责把官方设计指南、HarmonyOS Symbol、本地资源包和 Chronoisle2 工程落点串成可执行路径。
- `docs/design/harmonyos/harmonyos-next-ui-upgrade-plan.md` 是多期 UI 升级总纲，负责定义升级目标、分期、验收和风险。
- `docs/design/harmonyos/harmonyos-next-adaptation-matrix.md` 是执行追踪表，负责记录每项新规范的状态、落点、优先级和豁免原因。
- 本文档仍是 ArkUI 页面日常开发的直接样式规范；当页面级规则与 HarmonyOS NEXT 总纲冲突时，先按总纲判断产品方向，再把可执行规则沉淀回本文档。

## 1. 当前实现基线

### 1.1 已有设计系统结构

当前代码已经形成三层 UI 基础设施：

1. 主题层：`entry/src/main/ets/theme/AppTheme.ets`
2. Token 层：`entry/src/main/ets/foundation/tokens/*`
3. 基组件层：`entry/src/main/ets/ui/base/*`

当前已经存在的高频基组件：
- `AppCard`
- `AppButton`
- `AppSearchBar`
- `AppSegmentTabs`
- `AppStatusBadge`
- `AppChip`
- `AppPageHeader`
- `AppPanelSection`
- `AppHeroPanel`
- `AppTaskRow`
- `AppReminderCard`
- `AppGoalCard`
- `AppListRow`
- `AppEmptyState`

### 1.2 已有页面骨架

当前主导航实际结构来自 `pages/MainPage.ets`：
- `Today`
- `任务`
- `打卡`
- `我的`
- 中央悬浮创建按钮 `FAB`

当前主 Tab 的实际内容骨架：
- `components/TodayTab.ets`
  - 顶部问候
  - 搜索栏
  - 今日提醒横向卡片
  - 今日计划 Hero
  - 正在推进的目标
- `components/TaskListTab.ets`
  - 页头
  - 搜索
  - 状态筛选
  - 目标筛选
  - AI 重排提示
  - 任务列表
- `components/CalendarTab.ets`
  - 页头
  - 模式切换
  - 日历格
  - 当日提醒 / 任务列表
- `components/MeTab.ets`
  - 账户
  - 权益
  - 数据中心
  - 主题偏好
  - 更多

### 1.3 当前可改进点

以下判断基于实际代码，不是推测：

1. Token 与 legacy 常量并存。
   - `foundation/tokens/*` 已经是主 token 层。
   - `common/AppStyle.ets` 仍保留旧尺寸常量。
   - `pages/GoalBreakdownPage.ets` 还在引用 `common/AppStyle.ets`。

2. 页内仍有大量手写尺寸。
   - `TodayTab.ets`
   - `TaskListTab.ets`
   - `CalendarTab.ets`
   - `MeTab.ets`
   - `VoiceCreateOverlay.ets`
   - `CreateTaskPage.ets`
   - `CreatePomodoroPage.ets`

3. 基组件已经存在，但相似卡片仍有局部重复实现。
   - 空状态卡
   - AI 提示卡
   - 任务状态行
   - 小统计块

4. 色彩、圆角、密度基本统一，但还不够“收口”。
   - 大标题和 Hero 的尺寸偏松
   - 页内存在 12 / 14 / 16 / 18 / 20 / 22 / 24 多档混用
   - 动效 token 尚未形成统一口径

## 2. 新的视觉方向

### 2.1 风格关键词

- 清晰
- 紧凑
- 美观
- 轻科技感
- 克制
- 可执行

### 2.2 目标气质

Chronoisle2 不应该像“花哨的 AI 运营页”，而应该像“安静、精确、持续可用的个人执行控制台”。

界面感受必须满足：
- 首屏重点一眼可见
- 信息密度高但不拥挤
- 色彩冷静，不靠大面积高饱和来制造存在感
- 科技感来自秩序、对齐、细边框、微层次和反馈节奏

### 2.3 视觉占比

页面色彩占比按以下原则控制：
- 80% 中性色和表面层
- 15% 主色和功能强调
- 5% 风险、成功、会员等状态色

禁止：
- 整屏高亮蓝
- 大面积渐变铺底
- 粗描边、粗图标、重阴影
- 同屏出现过多不同颜色的 badge / chip

## 3. 设计系统命名策略

规范层统一采用 CSS 变量命名，ArkUI 落地时映射到现有 token 文件。

命名规则：
- 颜色：`--ui-color-*`
- 字体：`--ui-font-*`
- 行高：`--ui-line-*`
- 间距：`--ui-space-*`
- 圆角：`--ui-radius-*`
- 描边：`--ui-border-*`
- 阴影：`--ui-shadow-*`
- 尺寸：`--ui-size-*`
- 动效：`--ui-motion-*`

映射规则：
- 颜色变量映射到 `AppTheme.ets`
- 非颜色变量映射到 `foundation/tokens/*`
- 页面禁止直接新增新的“私有视觉常量”，优先补到 token 层

## 4. 色彩体系

### 4.1 核心变量

```css
:root {
  --ui-color-primary: #3E7BFA;
  --ui-color-primary-strong: #2F63DB;
  --ui-color-primary-soft: #EAF2FF;
  --ui-color-accent: #27C1A3;

  --ui-color-bg-page: #F4F8FD;
  --ui-color-bg-surface: #FFFFFF;
  --ui-color-bg-surface-soft: #F6FAFF;
  --ui-color-bg-surface-raised: #FFFFFF;
  --ui-color-bg-overlay: rgba(14, 24, 39, 0.18);

  --ui-color-text-1: #142033;
  --ui-color-text-2: #5D708A;
  --ui-color-text-3: #8FA2BC;
  --ui-color-text-on-primary: #FFFFFF;

  --ui-color-border: #DCE6F2;
  --ui-color-divider: #E2EAF4;

  --ui-color-success: #2FB879;
  --ui-color-success-soft: #EAF8F2;
  --ui-color-warning: #F2AE45;
  --ui-color-warning-soft: #FFF5E6;
  --ui-color-danger: #F05D63;
  --ui-color-danger-soft: #FFF1F1;
  --ui-color-info: #3E7BFA;
  --ui-color-info-soft: #EEF5FF;

  --ui-color-premium: #CFA24A;
  --ui-color-premium-soft: #FFF7E2;
  --ui-color-premium-text: #71511A;
  --ui-color-premium-border: #E7C87E;
}

[data-theme="dark"] {
  --ui-color-primary: #6E9BFF;
  --ui-color-primary-strong: #4D76E5;
  --ui-color-primary-soft: #213251;
  --ui-color-accent: #3AC8AC;

  --ui-color-bg-page: #121A28;
  --ui-color-bg-surface: #182233;
  --ui-color-bg-surface-soft: #1D2A3E;
  --ui-color-bg-surface-raised: #1B283B;
  --ui-color-bg-overlay: rgba(0, 0, 0, 0.28);

  --ui-color-text-1: #F4F7FB;
  --ui-color-text-2: #B1BED2;
  --ui-color-text-3: #8594AA;
  --ui-color-text-on-primary: #FFFFFF;

  --ui-color-border: #293750;
  --ui-color-divider: rgba(255, 255, 255, 0.08);

  --ui-color-success: #48C78A;
  --ui-color-success-soft: #1F362B;
  --ui-color-warning: #F2B85B;
  --ui-color-warning-soft: #392D18;
  --ui-color-danger: #FF7275;
  --ui-color-danger-soft: #3A2027;
  --ui-color-info: #8EB0FF;
  --ui-color-info-soft: #1D2E47;

  --ui-color-premium: #E1BA65;
  --ui-color-premium-soft: #302615;
  --ui-color-premium-text: #F5DDA1;
  --ui-color-premium-border: #927233;
}
```

### 4.2 使用规则

1. `--ui-color-primary` 只用于主操作、主链接、选中态、关键进度。
2. `--ui-color-primary-soft` 只用于 AI 区块、选中浅底、轻提示面。
3. `--ui-color-bg-page` 用于页面底。
4. `--ui-color-bg-surface` 用于标准卡片、输入框、底部导航承载面。
5. `--ui-color-bg-surface-soft` 用于轻卡片、占位、次级区块。
6. 风险色只用于状态判断，不用于页面主装饰。
7. 会员色独立使用，不与主系统蓝混用。

### 4.3 示例

```css
.hero-ai {
  background: var(--ui-color-primary-soft);
  border: 1px solid color-mix(in srgb, var(--ui-color-primary) 28%, white);
  color: var(--ui-color-text-1);
}

.danger-banner {
  background: var(--ui-color-danger-soft);
  border: 1px solid var(--ui-color-danger);
}
```

## 5. 字体与排印

### 5.1 字体变量

```css
:root {
  --ui-font-family-base: "HarmonyOS Sans SC", "PingFang SC", "Microsoft YaHei", sans-serif;

  --ui-font-page-title: 22px;
  --ui-font-hero-title: 18px;
  --ui-font-section-title: 16px;
  --ui-font-body: 14px;
  --ui-font-meta: 12px;
  --ui-font-micro: 11px;
  --ui-font-numeric-lg: 28px;
  --ui-font-numeric-md: 22px;

  --ui-line-tight: 16px;
  --ui-line-body: 20px;
  --ui-line-relaxed: 22px;

  --ui-weight-regular: 400;
  --ui-weight-medium: 500;
  --ui-weight-semibold: 600;
  --ui-weight-bold: 700;
}
```

### 5.2 排印规则

1. 页面主标题默认 `22px / 600`，不再默认使用 `24px / 700`。
2. Hero 标题默认 `18px / 600`，最多两行。
3. 区块标题统一 `16px / 500-600`。
4. 正文统一 `14px`，任务名、提醒名、目标名都不再自由漂移。
5. 次要信息统一 `12px`。
6. Badge、辅助说明、计数尾标统一 `11px`。
7. 数字需要强调时用 `28px` 或 `22px`，同一卡片只允许一个主数字。

### 5.3 示例

```css
.page-title {
  font: var(--ui-weight-semibold) var(--ui-font-page-title) / var(--ui-line-relaxed) var(--ui-font-family-base);
  color: var(--ui-color-text-1);
}

.task-meta {
  font: var(--ui-weight-regular) var(--ui-font-meta) / var(--ui-line-tight) var(--ui-font-family-base);
  color: var(--ui-color-text-2);
}
```

## 6. 间距系统

### 6.1 间距变量

```css
:root {
  --ui-space-2xs: 4px;
  --ui-space-xs: 6px;
  --ui-space-sm: 8px;
  --ui-space-md: 12px;
  --ui-space-card: 16px;
  --ui-space-lg: 18px;
  --ui-space-xl: 22px;
  --ui-space-2xl: 28px;

  --ui-page-padding-x: 18px;
  --ui-page-padding-y: 18px;
  --ui-section-gap: 18px;
  --ui-content-gap: 12px;
  --ui-panel-gap: 14px;
  --ui-grid-columns: 4;
  --ui-grid-gutter: 12px;
}
```

### 6.2 使用规则

1. 页面左右边距统一 `18px`。
2. 主模块之间统一 `18px`。
3. 卡片内部主 padding 默认 `16px`。
4. 列表行、筛选条、次级卡的内部节奏以 `8 / 12 / 16` 为主。
5. 页面不要再随意使用 `24 / 26 / 30+` 的大留白来“做高级感”。

### 6.3 示例

```css
.page-shell {
  padding: var(--ui-page-padding-y) var(--ui-page-padding-x);
  display: grid;
  gap: var(--ui-section-gap);
}

.card-body {
  padding: var(--ui-space-card);
  gap: var(--ui-space-sm);
}
```

## 7. 圆角、边框、阴影

### 7.1 变量

```css
:root {
  --ui-radius-sm: 8px;
  --ui-radius-md: 12px;
  --ui-radius-lg: 16px;
  --ui-radius-xl: 20px;
  --ui-radius-pill: 999px;

  --ui-border-subtle: 0.5px;
  --ui-border-default: 1px;
  --ui-border-active: 1.5px;

  --ui-shadow-card: 0 3px 8px rgba(20, 38, 63, 0.10);
  --ui-shadow-raised: 0 6px 14px rgba(20, 38, 63, 0.10);
  --ui-shadow-float: 0 10px 20px rgba(20, 38, 63, 0.10);
}

[data-theme="dark"] {
  --ui-shadow-card: 0 3px 8px rgba(2, 10, 24, 0.24);
  --ui-shadow-raised: 0 6px 14px rgba(2, 10, 24, 0.24);
  --ui-shadow-float: 0 10px 20px rgba(2, 10, 24, 0.24);
}
```

### 7.2 使用规则

1. 普通卡片统一 `16px` 圆角。
2. 搜索栏、次级操作按钮、返回按钮统一 `20px` 或 pill 体系。
3. chip、badge、状态点统一 pill。
4. 阴影只用于层级，不用于装饰。
5. 大面积卡片禁止 2px 以上粗边框。
6. 交互激活态优先提颜色，不靠加粗描边。

### 7.3 示例

```css
.surface-card {
  background: var(--ui-color-bg-surface);
  border: var(--ui-border-default) solid var(--ui-color-border);
  border-radius: var(--ui-radius-lg);
  box-shadow: var(--ui-shadow-card);
}
```

## 8. 尺寸与密度

### 8.1 变量

```css
:root {
  --ui-size-header-compact: 56px;
  --ui-size-header-default: 64px;
  --ui-size-search-bar: 40px;
  --ui-size-search-badge: 22px;
  --ui-size-list-row: 56px;
  --ui-size-reminder-card-h: 92px;
  --ui-size-reminder-card-min-w: 180px;
  --ui-size-hero-compact: 208px;
  --ui-size-hero-expanded: 240px;
  --ui-size-goal-card-h: 188px;
  --ui-size-button-sm: 36px;
  --ui-size-button-md: 40px;
  --ui-size-button-lg: 44px;
  --ui-size-fab: 56px;
  --ui-size-bottom-bar: 86px;
  --ui-size-nav-icon: 28px;
}
```

### 8.2 规则

1. 默认触控高度不低于 `36px`，主按钮不低于 `40px`。
2. 任务行默认视觉高度控制在 `54-60px`。
3. Hero 是全页唯一高密度例外区，不允许多个 Hero 堆叠。
4. FAB 保持 `56px`，不再膨胀。
5. 底部导航整体高度保持 `86px`，但视觉重点应落在图标和标签，而不是厚重背景。

## 9. 组件规范

### 9.1 AppPageHeader

用途：详情页、次级页、Tab 顶部标题。

规范：
- 标题：`--ui-font-page-title`
- 副标题：`--ui-font-meta`
- 返回按钮：表面白底 + 细边框 + `20px` 圆角
- 右侧操作：只保留一个最重要入口

示例：

```css
.page-header {
  padding: 12px var(--ui-page-padding-x) 8px;
}
```

### 9.2 AppSearchBar

用途：全局搜索、任务检索、带筛选提示的搜索入口。

规范：
- 高度固定 `40px`
- 左侧图标 `16px`
- 容器圆角 `20px`
- 白底、细边框、无厚阴影
- 未输入时只显示占位，不额外堆解释文字

示例：

```css
.search-bar {
  height: var(--ui-size-search-bar);
  border-radius: var(--ui-radius-xl);
  background: var(--ui-color-bg-surface);
  border: 1px solid var(--ui-color-border);
}
```

### 9.3 AppButton

按钮分型：
- `primary`
- `secondary`
- `ghost`
- `danger`
- `premium`

规则：
- 主按钮：纯色高对比，默认 `40px`
- 次按钮：白底细边
- 危险按钮：只在确认操作中使用
- 会员按钮：只在会员场景使用金色体系

### 9.4 AppCard

卡片分型：
- `base`
- `soft`
- `raised`
- `danger`
- `premium`
- `accent`

规则：
- 业务页面默认 `base`
- 解释性区块优先 `soft`
- 需要浮起或弹层承载时才用 `raised`
- `danger` 和 `premium` 只作为语义场景，不作为装饰皮肤乱用

### 9.5 AppPanelSection

统一分区语法：

```text
标题                         操作
数量 / 状态 / 时间
```

规则：
- 标题必须说明内容类型
- 副标题优先数量、状态、时间
- 一个分区最多一个右侧操作

### 9.6 AppHeroPanel

用途：
- 今日计划
- AI 结果总览
- 强引导状态

规则：
- 一个页面最多一个 Hero
- Hero 不做大面积重渐变
- AI 场景默认使用 `primary soft` 体系
- Hero 内的统计块必须紧凑，避免二次膨胀成“大卡中卡”

### 9.7 AppChip / AppStatusBadge

规则：
- 统一 pill 轮廓
- `11-12px` 文字
- 状态 badge 优先小面积点缀
- 同一行建议不超过 3 个

### 9.8 AppTaskRow / AppReminderCard / AppGoalCard / AppListRow

这些是当前仓库最重要的业务组件，规范如下：

1. 标题优先级固定高于一切辅助信息。
2. 标题最多 1-2 行，次要信息最多 1 行。
3. 左侧状态点、勾选框、色条都应细而稳定，不要继续加粗。
4. 目标卡、提醒卡、任务卡必须共享同一套圆角、边框、文本层级。
5. 空状态优先复用 `AppEmptyState`，不要页内重复造卡。

## 10. 布局规范

### 10.1 全局布局

页面统一采用三层信息结构：

1. L1 决策层
   - 今日计划 Hero
   - 关键倒计时
   - AI 结果总览
2. L2 工作层
   - 列表
   - 表单
   - 分区卡片
3. L3 解释层
   - 说明
   - 原因
   - 风险
   - 帮助信息

规则：
- L1 每页最多 1 个主焦点
- L2 承载主要操作
- L3 默认弱化

### 10.2 MainPage 与底部导航

基于 `pages/MainPage.ets`，统一规范如下：
- 底部栏高度：`86px`
- 图标尺寸：`28px`
- 标签字号：`11px`
- 图标与标签间距：`6px`
- 中央 FAB：`56px`
- FAB 上浮但不遮挡内容主要操作
- 底部栏背景应比页面底略亮，不要出现重玻璃、重发光

### 10.3 Today 页

保留现有顺序，但进一步收紧为：
1. 问候与日期
2. 搜索
3. 今日提醒
4. 今日计划 Hero
5. 正在推进的目标

规则：
- 提醒区横向卡片只承载“今天要处理什么”
- Hero 是唯一强焦点
- 目标区默认显示 3 个以内
- 空状态卡不再比真实内容卡更抢眼

### 10.4 Task 页

保留现有结构：
1. 页头
2. 搜索
3. 状态筛选
4. 目标筛选
5. AI 重排提示
6. 任务列表

规则：
- 筛选区必须横向紧凑
- AI 重排 banner 只在有逾期任务时强调
- 列表默认优先信息密度，不增加无意义留白

### 10.5 Calendar 页

规则：
- 日历格承担定位，不承担大段阅读
- 真正的信息承载放在当日列表
- 模式切换和筛选不能压过日期本身
- 提醒 / 任务的样式沿用 Today / Task 既有组件语法

### 10.6 Me 页

保留现有“账户 / 权益 / 数据中心 / 主题偏好 / 更多”五段结构。

规则：
- 会员卡允许更精致，但不能破坏整体密度
- 列表项优先 `AppListRow`
- 主题切换使用 `AppChip`
- 不要把每个入口都做成独立大卡

## 11. 图标与插图风格

### 11.1 图标

```css
:root {
  --ui-icon-xs: 12px;
  --ui-icon-sm: 16px;
  --ui-icon-md: 18px;
  --ui-icon-lg: 20px;
  --ui-icon-xl: 24px;

  --ui-icon-stroke-sm: 1;
  --ui-icon-stroke-md: 1.25;
  --ui-icon-stroke-lg: 1.5;
}
```

规则：
- 全局优先线性图标
- 同页不要混用粗细完全不同的图标
- Tab 图标、列表图标、操作图标保持同一家族观感
- 激活态主要靠颜色，不靠图标变粗一整级

### 11.2 插图

适用场景：
- onboarding
- empty state
- 无数据提示

风格规则：
- 双色或三色以内
- 主色只作局部点缀
- 线稿 + 轻几何块面
- 不做 3D、霓虹、玻璃拟态

## 12. 动效与过渡原则

### 12.1 动效变量

```css
:root {
  --ui-motion-fast: 140ms;
  --ui-motion-base: 200ms;
  --ui-motion-slow: 260ms;
  --ui-ease-standard: cubic-bezier(0.2, 0.8, 0.2, 1);
  --ui-ease-exit: cubic-bezier(0.4, 0, 1, 1);
  --ui-scale-press: 0.98;
  --ui-shift-enter-y: 8px;
}
```

### 12.2 规则

1. 默认动效必须短，服务反馈，不制造表演感。
2. 页面内优先使用透明度、轻位移、轻缩放。
3. 列表项、卡片点击只允许轻压感，不做弹跳。
4. Hero、Banner、Bottom Sheet 才允许更完整的进入过渡。
5. 风险和失败状态禁止用强烈抖动或高频闪动。

### 12.3 示例

```css
.interactive-card {
  transition:
    transform var(--ui-motion-fast) var(--ui-ease-standard),
    box-shadow var(--ui-motion-fast) var(--ui-ease-standard),
    opacity var(--ui-motion-fast) var(--ui-ease-standard);
}

.interactive-card:active {
  transform: scale(var(--ui-scale-press));
}

.sheet-enter {
  transform: translateY(var(--ui-shift-enter-y));
  opacity: 0;
}
```

## 13. ArkUI 落地规则

### 13.1 文件归属

新增或调整样式时，按以下顺序归位：

1. 颜色进入 `theme/AppTheme.ets`
2. 尺寸、字号、圆角、阴影进入 `foundation/tokens/*`
3. 共性样式进入 `ui/base/*`
4. 只属于单页且无法复用的微差异，才留在页面内

### 13.2 禁止项

1. 禁止继续往 `common/AppStyle.ets` 增加新视觉常量。
2. 禁止页面直接写新的“专属色盘”。
3. 禁止为了显眼而引入重阴影、重渐变、重描边。
4. 禁止在同一页面内同时出现多套圆角体系。
5. 禁止空状态卡比真实数据卡更高对比。

### 13.3 推荐收敛顺序

后续如果继续做 UI 收敛，顺序应为：

1. 先清理 `common/AppStyle.ets` 的视觉常量依赖
2. 再收敛 `TodayTab / TaskListTab / CalendarTab / MeTab` 页内硬编码
3. 再补 `motion` token
4. 最后统一详情页和创建页的卡片、筛选器、空状态

## 14. 验收清单

新页面或改版页面上线前，至少自查以下问题：

1. 这个页面是否只有一个主焦点区域？
2. 是否优先用了 `AppTheme + foundation/tokens + ui/base`？
3. 是否出现了新的私有颜色、私有圆角、私有阴影？
4. 是否存在 24px 以上的大标题滥用？
5. 是否出现了多张“尺寸接近 Hero”的卡片竞争注意力？
6. 是否有同类信息在不同页面用了不同语法？
7. 空状态是否比真实内容更抢眼？
8. 深色模式下边框、文字、图标是否仍然清楚？
9. 同屏的 badge / chip 数量是否过多？
10. 交互反馈是否简短、克制、稳定？

## 15. 结论

Chronoisle2 的新 UI 方向不是再造一套炫技视觉，而是把现有的主题层、token 层和基组件层真正收口成一套一致的、偏紧凑的、带轻科技感的执行型界面系统。

后续所有 UI 调整，默认以本文档为准。
