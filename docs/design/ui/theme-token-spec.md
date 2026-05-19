# Chronoisle 深浅色主题 Token 规范

更新时间：2026-04-19

适用对象：设计、前端、测试

关联文档：

- [精致效率 UI 风格规范](</docs/design/ui/ui-style-guide-efficiency.md>)
- [视觉 Token 与组件外观规范](</docs/design/ui/ui-visual-token-spec.md>)

## 1. 文档目标

本文档用于把 Chronoisle 的浅色模式与深色模式主题规范单独沉淀出来，作为后续设计稿、组件开发、视觉走查和真机测试的共同基线。

这份文档解决四个问题：

- 设计知道哪些颜色和层级是“语义 token”，哪些只是业务内容。
- 前端知道哪些颜色可以直接使用，哪些必须通过主题映射间接使用。
- 测试知道深色模式和浅色模式该验什么，而不是只看“能不能切换”。
- 后续新页面不会继续把主题做成“页面自己拼颜色”。

## 2. 适用范围

本规范覆盖：

- 主端 Harmony 页面
- 底部 Tab
- 顶部状态条
- 卡片、按钮、输入框、列表
- AI 生成与结果预览态
- 会员、积分、公告、同步等系统模块

本规范不覆盖：

- App 图标和市场物料
- 后台 Web
- 品牌宣传图

## 3. 基本原则

### 3.1 双模式是正式交付，不是后补项

- 浅色模式和深色模式都属于正式交付范围。
- 所有 P0 页面必须在两种模式下都能通过评审和测试。
- 所有基础组件必须具备双模式能力后才能进入可复用层。

### 3.2 使用语义 token，不直接使用页面私色

页面和组件应该优先表达“语义”，例如：

- `primary`
- `surface`
- `surfaceRaised`
- `textPrimary`
- `danger`
- `premium`

而不是直接表达某个具体十六进制颜色。

### 3.3 深色模式不是颜色反相

深色模式必须重新校准以下要素：

- 背景亮度层级
- 表面层级
- 边框和分隔线强度
- 文字对比
- 图标激活与未激活对比
- 阴影和高亮透明度

### 3.4 小尺寸优先

底部 Tab、badge、弱图标、分隔线、输入框边框等元素，必须按小尺寸真实场景来定义 token，而不是只看放大设计稿。

## 4. 当前实现基线

当前代码中的主题主入口位于：

- [AppTheme.ets](</D:/code/Chronoisle2/entry/src/main/ets/theme/AppTheme.ets:1>)
- [ThemeService.ets](</D:/code/Chronoisle2/entry/src/main/ets/services/ThemeService.ets:1>)

当前已有主题字段：

- `primary`
- `primaryLight`
- `primaryDark`
- `accent`
- `background`
- `surface`
- `surfaceLight`
- `textPrimary`
- `textSecondary`
- `textMuted`
- `divider`
- `success`
- `warning`
- `danger`
- `info`
- `cardShadow`
- `navBackground`
- `cardBackground`
- `inputBackground`
- `borderColor`

这套字段已经够当前版本落地，但从规范角度还不够精细，后续建议补一层更明确的语义 token 映射。

## 5. Token 分类

建议按 7 大类组织主题 token。

### 5.1 Brand Token

品牌与主系统色。

| Token | 用途 | Light | Dark |
| --- | --- | --- | --- |
| `primary` | 主动作、主激活态、底部 Tab 激活态 | `#4B7BF7` | `#5E8BFF` |
| `primaryLight` | 主色浅层背景、选中底色 | `#6D94FF` | `#87A6FF` |
| `primaryDark` | 主色深层强调、hover/pressed | `#345FE4` | `#4C72E3` |
| `info` | 信息提示、轻提示组件 | `#4B7BF7` | `#7AA3FF` |

### 5.2 Surface Token

背景和层级表面。

| Token | 用途 | Light | Dark |
| --- | --- | --- | --- |
| `background` | 页面主背景 | `#F4F7FB` | `#0E1624` |
| `surface` | 一级表面，如二级页头、底栏背景 | `#FFFFFF` | `#151F30` |
| `surfaceLight` | 次级表面、弱背景、轻卡片底 | `#F8FAFD` | `#1C293D` |
| `cardBackground` | 标准卡片背景 | `#FFFFFF` | `#151F30` |
| `inputBackground` | 输入框、搜索框背景 | `#F8FAFD` | `#1C293D` |
| `navBackground` | 导航背景 | `#F4F7FB` | `#0E1624` |

### 5.3 Text Token

文字与图标通用中性色。

| Token | 用途 | Light | Dark |
| --- | --- | --- | --- |
| `textPrimary` | 主标题、正文主信息 | `#162033` | `#F5F7FB` |
| `textSecondary` | 次级说明、模块描述 | `#60708A` | `#A9B7CB` |
| `textMuted` | 占位、未激活、弱提示、底部 Tab 未选中图标 | `#97A3B6` | `#78859A` |

### 5.4 Border & Divider Token

边框和分隔层级。

| Token | 用途 | Light | Dark |
| --- | --- | --- | --- |
| `borderColor` | 输入框、卡片、底栏顶边、chip 描边 | `#E4EAF3` | `#253249` |
| `divider` | 分隔线、列表弱分界 | `#E6EBF3` | `rgba(255, 255, 255, 0.08)` |

### 5.5 Feedback Token

状态色。

| Token | 用途 | Light | Dark |
| --- | --- | --- | --- |
| `success` | 成功、已完成、会员有效 | `#2FBE72` | `#35C37B` |
| `warning` | 风险提醒、轻警告 | `#FFB547` | `#FFBD59` |
| `danger` | 错误、逾期、破坏性动作 | `#FF5C54` | `#FF6B63` |

### 5.6 Effect Token

阴影与氛围效果。

| Token | 用途 | Light | Dark |
| --- | --- | --- | --- |
| `cardShadow` | 卡片阴影 | `rgba(15, 23, 42, 0.08)` | `rgba(2, 6, 23, 0.38)` |

### 5.7 Business Semantic Token

这类 token 当前代码里还没有完整拆开，但规范上建议新增。

| 推荐 Token | 用途 | 说明 |
| --- | --- | --- |
| `premium` | 会员权益主色 | 建议独立于 `primary`，避免和系统建议混用 |
| `premiumSurface` | 会员卡背景层 | 浅色和深色都要单独校准 |
| `riskSurface` | 风险卡弱背景 | 不直接拿 `danger` 降透明度凑 |
| `announcementSurface` | 公告 Banner 背景 | 与风险和会员区分开 |
| `syncSuccessSurface` | 同步成功弱背景 | 用于顶部同步状态条 |
| `syncErrorSurface` | 同步失败弱背景 | 用于同步异常状态 |

## 6. 目标语义层级

为了让设计和前端对“背景层级”理解一致，建议再补一个抽象层。

### 6.1 Surface Level

| 语义层级 | 说明 | Light 推荐映射 | Dark 推荐映射 |
| --- | --- | --- | --- |
| `background` | 页面大背景 | `background` | `background` |
| `surfaceBase` | 一级容器背景 | `surface` | `surface` |
| `surfaceRaised` | 强调卡片、悬浮区域 | `cardBackground` | `surfaceLight` |
| `surfaceSoft` | 搜索框、轻分区、弱面板 | `surfaceLight` | `inputBackground` |
| `surfaceOverlay` | 弹层、底部 Sheet 背板 | `surface` | `surface` |

### 6.2 Text Emphasis

| 语义层级 | 用途 | 推荐映射 |
| --- | --- | --- |
| `high` | 主标题、关键数字、主按钮文字 | `textPrimary` |
| `medium` | 描述、标签说明、二级导航 | `textSecondary` |
| `low` | 占位、提示、未选中图标与标签 | `textMuted` |

## 7. 组件取色规则

### 7.1 页面背景

- 页面根背景优先使用 `background`
- 二级页头背景优先使用 `surface` 或 `background`，不要混乱

### 7.2 标准卡片

- 默认卡片背景：`cardBackground`
- 默认卡片边框：`borderColor`
- 默认卡片阴影：`cardShadow`
- 弱卡片背景：`surfaceLight`

### 7.3 输入框与搜索框

- 背景：`inputBackground`
- 文本：`textPrimary`
- 占位：`textMuted`
- 边框：`borderColor`
- 激活态：边框和高亮使用 `primary`

### 7.4 按钮

| 按钮类型 | 背景 | 文字 | 边框 |
| --- | --- | --- | --- |
| 主按钮 | `primary` | 浅色/深色都需高对比白字 | 无或弱描边 |
| 次按钮 | `surfaceLight` / `surface` | `textPrimary` | `borderColor` |
| 危险按钮 | `danger` 或 `riskSurface` | 高对比文字 | 按危险态规范 |
| 会员按钮 | `premium` | 高对比文字 | 不使用 `primary` |

### 7.5 底部 Tab

底部 Tab 是本次必须重点约束的组件。

规则：

- 背景：`surface`
- 顶部分隔：`borderColor`
- 选中图标：`primary`
- 未选中图标：`textMuted`
- 选中文字：`primary`
- 未选中文字：`textSecondary`
- 不允许在底部 Tab 上使用重阴影、重发光、厚渐变

### 7.6 Badge / Chip

- 默认文字：`textSecondary`
- 默认描边：`borderColor`
- 选中态文字：`primary`
- 选中态背景：`primaryLight` 的弱化表面，不直接写死蓝底
- 风险 Chip 不直接使用鲜红底，优先弱背景 + 危险文字

### 7.7 公告 Banner

- 不使用危险红或会员金，避免语义混淆
- 建议采用独立 `announcementSurface`
- 文案主色使用 `textPrimary`
- 次级说明使用 `textSecondary`

### 7.8 会员权益卡

- 必须独立于主系统蓝
- 建议增加 `premium / premiumSurface / premiumBorder`
- 深色模式下禁止继续使用浅色金渐变直接套用

### 7.9 风险卡与逾期卡

- 主色：`danger`
- 弱背景建议使用 `riskSurface`
- 深色模式下要避免红底过暗导致文字沉没

## 8. 底部 Tab 与图标专项规范

### 8.1 图标原则

- 统一使用极简线性语言
- 优先保证 24x24 和 28x28 下的识别度
- 每个图标只保留 1 个主轮廓 + 1 个识别特征

### 8.2 图标状态

| 状态 | 图标色 | 标签色 | 说明 |
| --- | --- | --- | --- |
| default | `textMuted` | `textSecondary` | 未选中 |
| active | `primary` | `primary` | 当前页 |
| disabled | 弱于 `textMuted` | 弱于 `textMuted` | 尽量少用于 Tab |
| pressed | `primaryDark` 或轻透明覆盖 | `primary` | 短暂交互态 |

### 8.3 深色模式要求

- 未选中图标不能陷入背景
- 激活态图标不能过亮到抢正文
- 标签与图标层级要统一
- 底栏分隔线必须可见但不刺眼

## 9. 设计交付约束

### 9.1 设计师必须输出

- 浅色模式 token 表
- 深色模式 token 表
- 语义层级说明
- 关键组件双模式稿
- 重点页面双模式稿

### 9.2 设计稿标注必须包含

- token 名称
- 组件所在 surface level
- 文字层级 high/medium/low
- 激活态与未激活态差异
- 深色模式下如有单独透明度修正，必须标出来

## 10. 前端实现约束

### 10.1 可以做的

- 通过 `themeColors` 和语义 token 派生颜色
- 使用统一方法计算激活态与未激活态
- 通过 token 控制深色模式下的表面、描边和文本对比

### 10.2 不可以做的

- 在页面组件里继续写大量 hex 颜色
- 使用“浅色模式颜色 + 统一降透明度”伪造深色模式
- 不经 token 体系直接为业务卡片手调颜色
- 让图标、边框、分隔线在深色模式下靠肉眼猜测可见度

### 10.3 建议新增代码层

建议在 `foundation/tokens/` 下补：

- `ColorTokens.ets`
- `SurfaceTokens.ets`
- `TextTokens.ets`
- `StateTokens.ets`

建议在 `theme/` 下补：

- `ThemeSemanticMap.ets`

## 11. 双模式验收清单

### 11.1 页面级

- Today 首页在浅色和深色下都能清晰分出背景、卡片、Hero、风险区
- Goals / Calendar / Me 在两种模式下都保持清晰层级
- Overlay、Sheet、底栏在两种模式下都不突兀

### 11.2 组件级

- 按钮在两种模式下对比足够
- 输入框边框在深色模式下不丢失
- badge / chip 在两种模式下仍有明显选中态
- 会员卡与风险卡语义不混淆
- 底部 Tab 激活和未激活一眼可分

### 11.3 真机级

- 室内暗光下深色模式可读
- 强光下浅色模式不发灰
- OLED 设备上深色模式不会因为纯黑/近黑层级错误导致结构消失
- 低亮度下底栏图标和标签仍可辨认

## 12. 推荐后续动作

建议按以下顺序继续：

1. 把当前 `ThemeColors` 映射整理成代码层 token 文件
2. 优先改底部 Tab、按钮、卡片、输入框四类基础组件
3. 再清理 Today / Me / Membership 三个 P0 页面里的硬编码颜色
4. 真机截图沉淀一套浅色/深色对照基线
