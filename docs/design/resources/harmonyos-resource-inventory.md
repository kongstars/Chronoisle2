# HarmonyOS 设计资源采用清单

更新日期：2026-04-29

资源来源：`C:\Users\fangj\Downloads\鸿蒙设计资源`

关联方案：`docs/design/harmonyos/harmonyos-vnext-resource-adoption-plan.md`

本文档用于追踪本地 HarmonyOS 设计资源包中每类资源是否进入 Chronoisle2 工程、如何进入、适用场景、限制条件和 fallback。后续新增资源必须先登记到本清单，再进入 `entry/src/main/resources` 或 ArkUI 代码。

## 1. 状态定义

| 状态 | 含义 | 处理要求 |
| --- | --- | --- |
| `adopted` | 已进入项目并有明确运行时用途 | 需要记录目标路径、license 和验收方式 |
| `candidate` | 候选采用，但尚未进入运行时 | 需要明确前置条件 |
| `reference-only` | 仅作为设计参考 | 不复制进 `resources` |
| `brand-limited` | 品牌限定素材 | 只允许在对应品牌业务场景使用 |
| `deferred` | 暂缓 | 记录原因和复评条件 |
| `rejected` | 不采用 | 记录原因，避免重复评估 |

## 2. 总览

| 目录 | 文件类型 | 状态 | 运行时入包 | 负责场景 | 结论 |
| --- | --- | --- | --- | --- | --- |
| `HarmonyOS Sans 字体` | `.ttf`、`.txt` | `adopted` | 部分入包 | 全局中文字体 | 只保留 SC Regular/Medium/Bold |
| `HarmonyOS+Sans+字体` | `.ttf`、`.txt` | `rejected` | 否 | 无 | 与上一目录重复，不重复打包 |
| `HarmonyOS 应用图标` | `.pix`、`.sketch` | `reference-only` | 否 | App 图标设计复核 | 作为导出规范参照 |
| `HarmonyOS 服务组件库` | `.pix`、`.sketch` | `reference-only` | 否 | Widget 视觉规范 | 转译到 WidgetStyle，不直接入包 |
| `手机折叠屏平板` | `.pix`、`.sketch` | `reference-only` | 否 | 响应式布局 | 转译到断点和页面布局 |
| `启动页设计资源` | `.pix`、`.sketch` | `candidate` | 暂不入包 | Starting Window | P6 处理 |
| `实况窗设计资源` | `.pix`、`.sketch` | `candidate` | 暂不入包 | Live View | P8 处理 |
| `使用华为账号登录` | `.png`、`.svg`、`.gif`、`.pix`、`.sketch` | `brand-limited` | 部分入包 | 华为账号登录 | `huaweilogo2.png` 已用于 LoginPage，其他素材不入包 |
| `华为支付图标` | `.png`、`.svg`、`.ai` | `brand-limited` | 条件入包 | 华为支付 | 只用于真实支付入口 |
| `元服务静默登录默认头像` | `.png`、`.svg` | `candidate` | 暂不入包 | 默认头像 | 等元服务/静默登录策略确认 |

## 3. 已采用资源

### 3.1 HarmonyOS Sans SC 字体

状态：`adopted`

当前项目路径：

| 文件 | 目标用途 | 说明 |
| --- | --- | --- |
| `entry/src/main/resources/rawfile/fonts/HarmonyOS_SansSC_Regular.ttf` | 正文、列表、说明 | 默认中文字重 |
| `entry/src/main/resources/rawfile/fonts/HarmonyOS_SansSC_Medium.ttf` | 按钮、分区标题、标签 | 中等强调 |
| `entry/src/main/resources/rawfile/fonts/HarmonyOS_SansSC_Bold.ttf` | 页面标题、关键数字 | 强强调 |

对应代码：

- `entry/src/main/ets/foundation/tokens/TypographyTokens.ets`

采用理由：

1. 当前产品以中文界面为主。
2. Regular/Medium/Bold 足够覆盖主要层级。
3. 避免打包 Thin、Light、Black、Italic、Condensed、Arabic、TC 等非必要字重。
4. 和 HarmonyOS 设计语言一致，能提升中文排版稳定性。

限制条件：

1. 字体文件不得修改。
2. 需要保留 HarmonyOS Sans Fonts License。
3. 需要在第三方声明中说明使用 HarmonyOS Sans Fonts。
4. 不得把字体作为独立资源分发或转售。

License 记录：

- `docs/reference/third-party-notices.md`
- `docs/licenses/HarmonyOS-Sans-Fonts-License.txt`

验收：

- 构建通过。
- 大字号模式不裁剪。
- 深浅主题下文本可读。
- 包体变化可接受。

### 3.2 华为账号登录 Logo

状态：`brand-limited`

当前项目路径：

| 文件 | 来源文件 | 目标用途 | 说明 |
| --- | --- | --- | --- |
| `entry/src/main/resources/base/media/huawei_login_logo_white.png` | `使用华为账号登录/logo/PNG/huaweilogo2.png` | LoginPage 华为账号登录按钮 | 仅用于华为账号登录入口，不作为通用装饰 |

对应代码：

- `entry/src/main/ets/pages/LoginPage.ets`

采用理由：

1. 登录页当前只开放华为账号登录，使用官方品牌素材能减少临时字母标识。
2. 只引入一份白色 logo，避免将 Pixso、Sketch、SVG、loading GIF 和备用 PNG 全量打包。
3. 使用场景与素材目录语义一致，符合 brand-limited 约束。

限制条件：

1. 不得在普通按钮、会员卡片、装饰背景或非华为账号业务入口使用。
2. 不得修改 logo 形状、颜色或比例。
3. 如果后续新增账号绑定、退出重登、授权中 loading，需要先复核对应素材和交互规范。

验收：

- `hvigor assembleApp -p product=default -p buildMode=debug` 通过。
- 登录按钮 logo 清晰，不挤压按钮文字。
- 深色/浅色主题下按钮对比度可读。

## 4. 候选资源

### 4.1 启动页设计资源

状态：`candidate`

目录：

- `启动页设计资源`

文件：

- `Starting Window Component.pix`
- `Starting Window Component.sketch`

用途：

- 更新 HarmonyOS Starting Window / Splash 视觉。
- 统一冷启动第一屏和主应用首页的视觉衔接。

不立即入包原因：

1. 文件是设计源，不是运行时资源。
2. 当前启动页已经通过 `module.json5` 配置 `startWindowIcon` 和 `startWindowBackground`。
3. 需要先确定 App 图标、背景色和深色模式策略。

下一步：

1. 提取启动页视觉规则。
2. 复核 `entry/src/main/resources/base/media/startIcon.png`。
3. 复核 `entry/src/main/resources/base/element/color.json` 的 `start_window_background`。
4. 需要时重新导出 PNG/分层图资源。

验收：

- 冷启动无白屏。
- 深色模式不刺眼。
- 启动页和首页视觉连续。

### 4.2 实况窗设计资源

状态：`candidate`

目录：

- `实况窗设计资源`

文件：

- `实况窗_实况胶囊组件库.pix`
- `实况窗_实况胶囊组件库.sketch`

用途：

- P8 Live View 设计参照。

适合场景：

1. 番茄钟/专注计时。
2. 用户主动开始的今日计划执行。
3. 耗时较长的 AI 重排任务。

不适合场景：

1. 普通任务提醒。
2. 目标进度展示。
3. 短时间 AI 请求。

下一步：

- 新增 `LiveViewService.ets` 前先完成系统 API 调研和真机权限验证。

### 4.3 元服务静默登录默认头像

状态：`candidate`

目录：

- `元服务静默登录默认头像`

文件：

- `PNG/元服务静默登录默认头像.png`
- `SVG/元服务静默登录默认头像.svg`

用途：

- 元服务或静默登录场景下的默认头像。

暂缓原因：

1. 当前 `module.json5` 中 `installationFree` 为 `false`。
2. Chronoisle2 当前主流程不是元服务形态。
3. 默认头像不能替代用户账户体系设计。

复评条件：

- 产品策略转向元服务。
- 登录流程引入静默账号态。

## 5. 仅设计参考资源

### 5.1 HarmonyOS 应用图标

状态：`reference-only`

目录：

- `HarmonyOS 应用图标`

文件：

- `HarmonyOS App Icons.pix`
- `HarmonyOS App Icons.sketch`

用途：

- 复核 Chronoisle2 App 图标是否符合 HarmonyOS 图标规范。
- 指导 `background.png`、`foreground.png`、`layered_image.json` 的分层策略。

当前项目相关资源：

- `entry/src/main/resources/base/media/background.png`
- `entry/src/main/resources/base/media/foreground.png`
- `entry/src/main/resources/base/media/layered_image.json`
- `entry/src/main/resources/base/media/icon_appgallery_216.png`
- `entry/src/main/resources/base/media/icon_appgallery_512.png`
- `entry/src/main/resources/base/media/icon_appgallery_1024.png`
- `entry/src/main/resources/base/media/startIcon.png`

不直接入包原因：

- 资源包提供的是设计源，不是 Chronoisle2 品牌图标成品。

### 5.2 HarmonyOS 服务组件库

状态：`reference-only`

目录：

- `HarmonyOS 服务组件库`

文件：

- `HarmonyOS Service Widget library.pix`
- `HarmonyOS Service Widget library.sketch`

用途：

- 桌面卡片布局、密度、状态和尺寸参考。

当前项目相关文件：

- `entry/src/main/resources/base/profile/form_config.json`
- `entry/src/main/ets/widget/pages/WidgetStyle.ets`
- `entry/src/main/ets/widget/pages/WidgetGlyph.ets`
- `entry/src/main/ets/widget/pages/MainWidget.ets`
- `entry/src/main/ets/widget/pages/DashboardWidget.ets`
- `entry/src/main/ets/widget/pages/TodoWidget.ets`
- `entry/src/main/ets/widget/pages/TodayPlanWidget.ets`
- `entry/src/main/ets/widget/pages/FocusWidget.ets`
- `entry/src/main/ets/widget/pages/VoiceWidget.ets`

转译要求：

1. Widget 页面保持 bind-only。
2. 视觉值进入 `WidgetStyle.ets`，不散落到各 widget 页面。
3. 图标语义和主应用 `AppIcon` 对齐。
4. 小尺寸卡片优先单动作，大尺寸卡片再承载概览。

### 5.3 手机折叠屏平板组件库

状态：`reference-only`

目录：

- `手机折叠屏平板`

文件：

- `HarmonyOS Component Library.pix`
- `HarmonyOS Component Library.sketch`

用途：

- 响应式布局和组件密度参考。

当前项目相关文件：

- `entry/src/main/ets/foundation/tokens/PageDensityTokens.ets`
- `entry/src/main/ets/components/TodayTab.ets`
- `entry/src/main/ets/components/TaskListTab.ets`
- `entry/src/main/ets/components/CalendarTab.ets`
- `entry/src/main/ets/pages/StatsHubPage.ets`

转译要求：

1. 手机竖屏保持单列。
2. 720vp 以上逐步进入主辅布局。
3. 960vp 以上进入平板/折叠屏展开态布局。
4. 1200vp 以上限制内容最大宽度。

## 6. 品牌限定资源

### 6.1 使用华为账号登录

状态：`brand-limited`

目录：

- `使用华为账号登录`

文件：

- `logo/PNG/huaweilogo1.png`
- `logo/PNG/huaweilogo2.png`
- `logo/svg/huaweilogo1.svg`
- `logo/svg/huaweilogo2.svg`
- `loading-36x36/loading-36x36.gif`
- `logo/pixso/huaweilogo.pix`
- `logo/sketch/huaweilogo.sketch`

允许使用场景：

- 华为账号登录按钮。
- 华为账号绑定入口。
- 华为账号登录 loading。

禁止使用场景：

- 普通用户头像。
- 普通页面装饰。
- 会员权益卡片装饰。
- 非华为账号登录的第三方登录按钮。

当前相关代码：

- `entry/src/main/ets/pages/LoginPage.ets`
- `entry/src/main/ets/services/ThirdPartyAuthService.ets`
- `entry/src/main/ets/services/AuthService.ets`

下一步：

1. 复核登录按钮视觉。
2. 复核失败/取消/loading 状态。
3. 只在确认品牌规范后导入必要 PNG/SVG。

### 6.2 华为支付图标

状态：`brand-limited`

目录：

- `华为支付图标`

文件：

- `PNG/资源 1@4x.png`
- `PNG/资源 2@3x.png`
- `PNG/资源 3@2x.png`
- `PNG/资源 4@1x.png`
- `SVG/图标资源.svg`
- `源文件Adobe Illustrator/华为支付logo.ai`

允许使用场景：

- 真实华为支付入口。
- 支付方式选择。
- 支付结果页中标识支付渠道。

禁止使用场景：

- 会员卡片装饰。
- 非支付状态提示。
- 与其他支付方式混淆的按钮。

当前相关代码：

- `entry/src/main/ets/pages/MembershipPage.ets`
- `entry/src/main/ets/services/IAPService.ets`
- `server/routes/iap.js`
- `server/services/HuaweiIapService.js`

下一步：

1. 先确认支付链路状态。
2. 再决定是否导入 PNG/SVG。
3. 不导入 `.ai` 到运行时资源。

## 7. 不采用资源

### 7.1 重复字体目录

状态：`rejected`

目录：

- `HarmonyOS+Sans+字体`

不采用原因：

1. 与 `HarmonyOS Sans 字体` 内容重复。
2. 当前项目已采用必要的 SC Regular/Medium/Bold。
3. 重复导入会增加包体并制造维护混乱。

处理：

- 保留在下载目录。
- 不复制进项目。
- 不进入资源构建。

## 8. 后续登记规则

任何新资源进入项目前，必须在本文件补充：

1. 来源目录。
2. 原始文件名。
3. 目标路径。
4. 状态。
5. 使用场景。
6. license 或品牌限制。
7. fallback。
8. 验收方式。

新增运行时资源后，必须同步检查：

```powershell
git diff --check
hvigor assembleApp -p product=default -p buildMode=debug
```
