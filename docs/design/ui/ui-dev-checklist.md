# UI 开发检查清单 (PR 门禁)

> Chronoisle2 前端代码合入前必须全部通过。检查方：代码审查者或 AI 辅助审查。

---

## 1. 颜色规范

- [ ] **零裸 hex 值**：页面文件中不出现 `#XXXXXX` 格式的颜色字符串（系统栏 `statusBarContentColor` 除外）
- [ ] **主题 Token**：所有颜色通过 `this.themeColors.xxx` 或 `this.theme.xxx` 引用
- [ ] **语义化颜色**：状态色使用 `success`/`warning`/`danger`/`info`，而非直接的绿色/黄色/红色
- [ ] **分类颜色**：目标分类颜色引用 `CATEGORY_COLORS[GoalCategory.XXX]`，不硬编码
- [ ] **半透明叠加**：仅在全屏沉浸式页面（如 OnboardingPage）的渐变背景上使用 `rgba()` 值

## 2. 排版规范

- [ ] **使用 Token**：所有 `.fontSize()` 使用 `TYPE_PAGE_TITLE`(22) / `TYPE_HERO_TITLE`(18) / `TYPE_SECTION_TITLE`(16) / `TYPE_BODY`(14) / `TYPE_META`(12) / `TYPE_CAPTION`(11) / `TYPE_NUMERIC_LG`(28) / `TYPE_NUMERIC_MD`(22)
- [ ] **非标准字号**：`fontSize(13)` / `fontSize(15)` / `fontSize(17)` / `fontSize(20)` 等中间级别需在 PR 描述中说明理由，或调整为最近 Token 值
- [ ] **字重**：使用 `FontWeight.Regular`(400) / `FontWeight.Medium`(500) / `FontWeight.Bold`(700)，不裸写数字
- [ ] **字体族**：使用 `FONT_FAMILY_SC` / `FONT_FAMILY_SC_MEDIUM` / `FONT_FAMILY_SC_BOLD`

## 3. 间距规范

- [ ] **使用 Token**：所有 `padding` / `margin` 数值使用 `SpacingTokens` 常量
- [ ] **页面内边距**：`PAGE_PADDING`(18) 用于页面级左右内边距
- [ ] **区块间距**：`SECTION_GAP`(18) 或 `PANEL_GAP`(14) 用于区块间间距
- [ ] **卡片间距**：`CONTENT_GAP`(12) 或 `SPACE_SM`(8) 用于卡片间/列表项间距
- [ ] **卡片内边距**：通过 `AppCard` 的 `paddingLevel` 属性控制，不使用裸 padding

## 4. 组件规范

- [ ] **按钮**：所有操作按钮使用 `AppButton`，不裸用 `Button()`（特例见下文）
- [ ] **页面头**：使用 `AppPageHeader` 作为页面顶部导航
- [ ] **卡片**：使用 `AppCard` 承载内容区块，指定合适的 `variant` 和 `paddingLevel`
- [ ] **状态视图**：空态/错误/加载分别使用 `AppEmptyState` / `AppErrorState` / `AppLoadingState`
- [ ] **图标**：所有图标通过 `AppIcon` 渲染，使用 `name` 参数指定语义图标名
- [ ] **徽标/标签**：状态标记使用 `AppStatusBadge`，筛选切换使用 `AppChip`

## 5. Button() 特例（允许直接使用原生 Button 的场景）

以下场景可以保留原生 `Button()`，但需在代码旁加简短注释说明原因：

1. **品牌按钮**：包含第三方品牌 Image 的登录按钮（如华为账号登录）
2. **特化控件**：任务复选框、自定义 Tab Chip（带计数徽标）、FAB 等非标准操作按钮
3. **极小图标按钮**：24x24 及以下的清除/删除图标按钮
4. **沉浸式页面**：OnboardingPage 渐变背景上的 CTA 按钮（需要特定的 rgba 样式）
5. **浮动操作菜单**：带阴影的浮动上下文操作按钮组

## 6. 暗色模式

- [ ] 页面在亮色和暗色模式下均可读
- [ ] 文字对比度：`textSecondary` 在背景上可读，`textMuted` 在 surface 上可读
- [ ] 边框在暗色背景下可见
- [ ] 图标在两种模式下均可辨识
- [ ] 空/错/加载状态在暗色模式下可读
- [ ] Badge/Chip 颜色在暗色背景下不融入

## 7. 响应式与布局

- [ ] 页面在 320vp 最小宽度下无元素截断或溢出
- [ ] 主要操作触摸目标 ≥ 40vp
- [ ] 使用 `PageDensityTokens` 中的断点常量和尺寸常量
- [ ] 新增 Tab 页面需支持 >=720vp 宽屏分栏

## 8. 动效

- [ ] 动画时长使用 `MOTION_DURATION_FAST`(140) / `MOTION_DURATION_BASE`(200) / `MOTION_DURATION_SLOW`(260)
- [ ] 缓动曲线使用 `MOTION_CURVE_STANDARD`(入场/展开) / `MOTION_CURVE_EXIT`(退场/收起)
- [ ] 无不带动画的突变式布局变化
- [ ] 无裸毫秒值或 `Curve.Linear`

## 9. 边界状态

每个数据驱动的页面必须覆盖以下状态：
- [ ] **加载中**：`AppLoadingState` 或骨架屏
- [ ] **空数据**：`AppEmptyState` 含图标、标题、描述、可选操作按钮
- [ ] **错误**：`AppErrorState` 含图标、错误描述、重试按钮
- [ ] **正常数据**：核心内容渲染正确

## 10. L3 层次结构

- [ ] L1 层（决策层）：页面最核心的主焦点信息突出显示
- [ ] L2 层（工作层）：主要列表、表单、操作区信息密度高
- [ ] L3 层（说明层）：辅助说明、规则、风险提示使用次要颜色和更小字号

---

## 快速自检命令

```bash
# 检查裸 hex 颜色（排除系统栏和主题定义文件）
grep -rn '#[0-9A-Fa-f]\{6\}' entry/src/main/ets/pages/ \
  | grep -v 'statusBarContentColor\|navigationBarContentColor'

# 检查裸 Button()（排除 AppButton、函数名）
grep -rn 'Button(' entry/src/main/ets/pages/ \
  | grep -v 'AppButton\|ActionButton\|CompleteButton\|FloatingButton\|MainFabButton'

# 检查非 Token fontSize（排除已使用 TYPE_ 的）
grep -rn '\.fontSize(' entry/src/main/ets/pages/ \
  | grep -v 'TYPE_\|fontSize(11)\|fontSize(12)\|fontSize(14)\|fontSize(16)\|fontSize(18)\|fontSize(22)\|fontSize(28)'
```
