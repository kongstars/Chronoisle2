# Third-Party Notices

更新日期：2026-04-29

本文档记录 Chronoisle2 当前随应用分发或计划随应用分发的第三方/外部资源。新增字体、图标、品牌素材、SDK 或素材包前，需要先补充本文件或对应 license 文件。

## HarmonyOS Sans Fonts

来源：`C:\Users\fangj\Downloads\鸿蒙设计资源\HarmonyOS Sans 字体`

项目内文件：

- `entry/src/main/resources/rawfile/fonts/HarmonyOS_SansSC_Regular.ttf`
- `entry/src/main/resources/rawfile/fonts/HarmonyOS_SansSC_Medium.ttf`
- `entry/src/main/resources/rawfile/fonts/HarmonyOS_SansSC_Bold.ttf`

版权方：Huawei Device Co., Ltd.

授权文件：

- `docs/licenses/HarmonyOS-Sans-Fonts-License.txt`

采用范围：

- Chronoisle2 HarmonyOS ArkUI 主应用中文界面字体。
- 当前仅采用简体中文 Regular、Medium、Bold 三个字重。

使用约束：

1. 字体文件保持未修改状态。
2. 软件中明确记录使用了 HarmonyOS Sans Fonts。
3. 不把 HarmonyOS Sans Fonts 作为独立字体产品转售或单独分发。
4. 在字体副本中保留版权声明和授权协议。

工程落点：

- `entry/src/main/ets/foundation/tokens/TypographyTokens.ets`

## Huawei Brand Assets

来源：`C:\Users\fangj\Downloads\鸿蒙设计资源`

涉及目录：

- `使用华为账号登录`
- `华为支付图标`
- `元服务静默登录默认头像`

当前状态：

- 已按需导入 `entry/src/main/resources/base/media/huawei_login_logo_white.png`，用于 `LoginPage` 华为账号登录按钮。
- 未作为通用运行时资源批量导入，后续只允许在对应品牌/业务场景中按需导入。

使用约束：

1. 华为账号素材只用于华为账号登录、绑定和登录 loading。
2. 华为支付素材只用于真实华为支付入口、支付方式和支付结果。
3. 元服务默认头像素材只用于对应元服务/静默登录默认头像场景。
4. 不得将品牌素材用作普通 UI 装饰、会员卡片装饰或非对应业务图标。

采用追踪：

- `docs/design/resources/harmonyos-resource-inventory.md`


## 第三方 SDK 清单（2026-05-19 更新）

> 用途说明：本节供合规、隐私政策披露和华为审核 reference 使用。每次新增/移除 SDK 都要同步本节，并刷新隐私政策中的「第三方 SDK」段。

### 华为系（系统/应用市场内置）

| SDK 名称 | 提供方 | 用途 | 收集字段 | 进程位置 | 隐私政策入口 |
| --- | --- | --- | --- | --- | --- |
| AGConnect Core (`@hw-agconnect/hmcore`) | 华为软件技术有限公司 | 应用与华为云后端连接的基础库，账号/分析/支付等 Kit 都依赖它 | App ID、设备标识、网络信息 | 客户端 | https://developer.huawei.com/consumer/cn/doc/start/privacy-statement-0000001050042021 |
| Account Kit (`@kit.AccountKit`) | 华为 | 华为账号一键登录，登录页 `LoginPage` 触发 | OpenID / UnionID、昵称、头像、华为账号 ID | 客户端 | https://developer.huawei.com/consumer/cn/doc/development/HMSCore-Guides/account-introduction-0000001050048870 |
| IAP Kit (`@kit.IAPKit`) | 华为 | 应用内订阅与购买，会员页 `MembershipPage` 触发 | 订单号、商品 ID、购买凭证 | 客户端 + 服务端 | 同上 |
| Audio Kit (`@kit.AudioKit`) | 华为系统 | 录音采集，配合阿里云 NUI 做语音识别 | 麦克风音频流（仅在用户主动按下录音按钮时） | 客户端，仅本地 | 系统权限 |
| AbilityKit / BasicServicesKit | 华为系统 | 提供 ability 上下文、错误码、Common 类型 | 不收集 | 客户端 | — |
| Reminder Agent (`@ohos.reminderAgentManager`) | 华为系统 | 系统级提醒（会员到期、任务提醒） | 提醒标题、时间 | 客户端 | 系统级 |

> 备注：还未启用的能力——Analytics Kit / Crash Service / Push Kit 在 AGC 后台开通后，要把对应 SDK 加到这张表，并补隐私披露。

### 第三方系

| SDK 名称 | 提供方 | 用途 | 收集字段 | 进程位置 | 隐私政策入口 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| neonui ASR（阿里云智能语音 NUI SDK） | 阿里云 | 实时语音识别，支撑语音创建任务 | 用户主动触发的语音转写文本、设备 ID（用于 token 鉴权）、采样率信息 | 客户端 SDK + 阿里云 NLS 服务端 | https://help.aliyun.com/document_detail/76777.html | 通过服务端 `/api/speech/token` 拿临时凭证；停止录音后即停止采集 |

### 自研服务（非第三方 SDK，但走出客户端的网络出口）

| 名称 | 主体 | 用途 | 字段 | 域名 | 加密 |
| --- | --- | --- | --- | --- | --- |
| 四时清单 API | 浙ICP备2026021379号 主体 | 账号、目标、任务、AI 计划、AI 重排、语音解析、IAP 验证、积分等 | 账号、目标、任务、AI 输入文本、订单凭证 | `api.sishiqingdan.cn` / `test-api.sishiqingdan.cn` | TLS 1.2+ |
| 四时清单埋点 | 同上 | App 启动、关键行为埋点 | 事件名、属性、设备 ID、Token | 同上 `/api/telemetry/*` | TLS 1.2+ |

### 触发时机与同意流程

- 用户在 `OnboardingPage` 勾选《隐私政策》和《用户协议》之前，**任何 SDK 的初始化和网络请求都不会发起**（由 `PrivacyConsentService` 网关统一管理 AGConnect、TelemetryService、`auth/me` 等敏感初始化）。
- 麦克风权限按需申请：用户点击语音按钮时才弹申请，并在停止后立即停止采集。
- 日历读写权限按需申请：用户开启日历同步或在创建提醒时弹出申请。

### 维护规则

1. 新增依赖前先在 PR 中补本表条目，列出收集字段和隐私政策链接。
2. 删除依赖时同步删除条目，并更新隐私政策。
3. 每次发版前复核本表与 `entry/oh-package.json5` 的依赖列表是否一致。
