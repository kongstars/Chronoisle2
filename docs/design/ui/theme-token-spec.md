# Chronoisle UI System V2 Theme Token 映射规范

> 本文档用于指导如何将 V2 (高密精工版) 的设计语言转化为具体的 ArkUI Theme Token 代码。开发者应严格遵守此表。

## 1. 颜色 Token (Color Tokens)

在 ArkTS 中，我们将提供一套完整的主题色彩，所有 UI 组件必须且只能从 `themeColors` 中获取颜色。

| Token 名称 | 浅色模式 (Light) | 深色模式 (Dark) | 用途说明 |
| :--- | :--- | :--- | :--- |
| `bgBase` | `#F0F2F7` | `#0D0E12` | 页面最底层背景 (深色下偏深蓝黑) |
| `bgPattern` | `rgba(0,0,0,0.03)` | `rgba(255,255,255,0.04)` | 点阵网格底纹颜色 (20vp 间距) |
| `surfaceBase` | `#FFFFFF` | `#1A1B23` | 卡片、弹窗的默认背景色 |
| `surfacePressed` | `#F4F5F8` | `#22242E` | 列表项、按钮按压时的底色 |
| `surfaceGradient` | `Linear(180deg, #FFFFFF, #FAFBFC)` | `Linear(180deg, #1E1F29, #15161D)` | 高级卡片使用的微渐变背景 |
| `textPrimary` | `#14151A` | `#F3F4F8` | 主标题、重要正文 |
| `textSecondary` | `#525666` | `#A0A4B8` | 副标题、说明文本 |
| `textMuted` | `#8E93A6` | `#6B6F85` | 极弱文本 (如日期、时间标签) |
| `brandPrimary` | `#5B5CE6` | `#7A7CFF` | 主品牌色 (深色下提高亮度以发光) |
| `brandLight` | `rgba(91,92,230,0.08)` | `rgba(122,124,255,0.15)` | 主色底板 (用于选中的 Tag、打卡按钮背景) |
| `semanticSuccess`| `#05A660` | `#05C973` | 成功态、完成态、运营类标签 |
| `semanticDanger` | `#E63946` | `#FF4D5E` | 危险操作、过期提醒、高优提示 |
| `semanticWarning`| `#D97706` | `#FBBF24` | 警告态、研发类标签 |
| `aiGradient` | `Linear(135deg, #5B5CE6, #00C6FF)` | `Linear(135deg, #7A7CFF, #00D4FF)` | AI 专属渐变 (用于进度条高亮、呼吸灯) |
| `borderLight` | `rgba(0,0,0,0.05)` | `rgba(255,255,255,0.06)` | 极细的普通边框线 |
| `borderHighlight` | `(无)` | `rgba(255,255,255,0.12)` | 深色模式下特殊的组件高亮边缘 |

## 2. 阴影 Token (Shadow Tokens)

ArkUI 的默认阴影过于生硬，V2 规范要求使用复杂的自定义 `box-shadow`。在 ArkTS 中，我们将使用 `ShadowOptions` 组合实现。

### 浅色阴影
- **`shadowCardLight`**:
  - 外投影: `offsetX: 0, offsetY: 2, radius: 8, color: rgba(0,0,0,0.02)`
  - 核心质感: 必须通过叠加内阴影实现高光边缘 (由于 ArkUI 限制，可通过给卡片加 1px 的纯白上边框模拟)。
- **`shadowBtnLight`**:
  - 彩色投影: `offsetX: 0, offsetY: 2, radius: 4, color: rgba(91,92,230,0.15)`

### 深色阴影
- **`shadowCardDark`**:
  - 沉重外投影: `offsetX: 0, offsetY: 8, radius: 16, color: rgba(0,0,0,0.4)`
  - 边缘微光 (Rim Light): 极度重要！深色模式下，卡片必须带有一层 `rgba(255,255,255,0.06)` 的微光描边，以从背景中浮现。
- **`shadowBtnDark`**:
  - 霓虹发光: `offsetX: 0, offsetY: 4, radius: 12, color: rgba(122,124,255,0.3)`

## 3. 尺寸与间距 Token (Dimension Tokens)

V2 是“高密版”，严格控制留白。

| Token 名称 | 数值 | 用途说明 |
| :--- | :--- | :--- |
| `pagePadding` | `14vp` | 页面左右侧安全距离 (取代原 16/20vp) |
| `sectionGap` | `16vp` | 大模块之间的纵向间距 (取代原 24vp) |
| `cardPadding` | `12vp` | 卡片内部留白 (取代原 16vp) |
| `itemGap` | `10vp` | 卡片内相邻元素的间距 |
| `radiusLg` | `14vp` | 最外层大容器圆角 (如“今日计划”的大白板) |
| `radiusMd` | `10vp` | 独立卡片圆角 (如“今日提醒”卡片) |
| `radiusSm` | `6vp` | 极小元素 (复选框、小标签) |

## 4. 排版 Token (Typography Tokens)

为了避免开发时字号和字重随意散落，必须严格使用以下常量映射。

| Token 名称 | ArkTS 字号 (`fp`) | 字重 (`FontWeight`) | 用途说明 |
| :--- | :--- | :--- | :--- |
| `TYPE_HERO_TITLE` | `20fp` | `Bold (700)` | 页面最顶部大标题 (如“早安，天辰”) |
| `TYPE_SECTION_TITLE`| `14fp` | `Medium (500)` 或 `SemiBold (600)` | 模块小标题 (如“今日计划”) |
| `TYPE_BODY` | `14fp` | `Regular (400)` 或 `Medium (500)` | 列表正文、任务标题、输入框 |
| `TYPE_META` | `13fp` | `Medium (500)` | 次要文本、卡片描述 |
| `TYPE_CAPTION` | `11fp` | `Medium (500)` | 极小标签、分类 Tag 文字 |
| `TYPE_NUMERIC_LG` | `32fp` | `Bold (700)` | 数据面板大数字 (必须应用等宽特性) |
| `TYPE_NUMERIC_MD` | `11fp` | `Medium (500)` | 时间、日期、提醒 (必须应用等宽特性) |

**等宽字体在 ArkTS 中的实现方式：**
由于鸿蒙默认可能不包含 `SF Mono`，请使用 `.fontFamily('HarmonyOS Sans')` 并开启字体特性，或者在数字文本上使用类似 `Text('16:30').fontFeature("\"tnum\" 1")` 确保数字等宽对齐。