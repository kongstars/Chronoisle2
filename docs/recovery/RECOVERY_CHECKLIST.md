# 本地恢复清单

更新时间：2026-04-21

判定依据：
- 已通读 `server` 目录下的路由、模型、服务、中间件和后台资源。
- 已对照 `entry/src/main/ets` 下的页面、组件、服务、数据模型和启动链路。
- 已重新执行本地构建；当前最新结果为 `assembleApp -p product=default -p buildMode=debug` 成功。

当前状态总览：
- 已修复：19 项
- 部分修复：0 项
- 完全缺失：0 项（以 Harmony 主端核心用户功能为口径）
- 当前整包状态：`BUILD SUCCESSFUL`
- 当前明确阻塞：无新的编译阻塞；当前主要工作转为功能回归和真机验收

说明：
- “已修复”指本地已经具备明确入口，并形成“页面/交互 -> 服务调用 -> 数据落地”的主链路。
- “部分修复”指已有代码和入口，但链路中仍有断点、占位实现、埋点不完整，或只完成了半结构化恢复。
- “完全缺失”指服务端已有能力，但主端本地没有入口、没有调用，或仍然是明显占位。
- “暂不纳入”指主要面向后台 Web 或备用开发链路，不属于当前 Harmony 主端核心恢复范围。

## 已修复

- 账号基础登录注册
  服务端：`/api/auth/send-code`、`/api/auth/register`、`/api/auth/login`、`/api/auth/me`
  本地：`LoginPage`、`RegisterPage`、`AuthService`
  结论：手机号/邮箱验证码注册登录、登录态持久化、启动后刷新用户信息的主链路已经接回。

- 第三方登录
  服务端：`/api/auth/oauth/url`、`/api/auth/wechat/callback`、`/api/auth/qq/callback`、`/api/auth/verify`、`/api/auth/huawei-login`
  本地：`LoginPage`、`ThirdPartyLoginPage`、`ThirdPartyAuthService`
  结论：微信、QQ、华为登录链路都已有本地接入。

- 云同步主链路
  服务端：`/api/sync/data`
  本地：`CloudSyncService`、`EntryAbility`、`LoginPage`、`RegisterPage`、`MeTab`
  结论：目标、任务、提醒、倒计时、番茄钟等核心数据的拉取、合并、上传和前后台自动同步已接回。

- 会员支付主链路
  服务端：`/api/iap/verifyOrder`
  本地：`MembershipPage`、`IAPService`
  结论：华为 IAP 商品查询、下单、服务端校验、会员状态刷新已接回。

- AI 任务自动补全
  服务端：`/api/agent/completion`
  本地：`CreateTaskPage`、`AgentService`
  结论：创建任务页的 AI 补全链路已接回。

- AI 目标规划主流程
  服务端：`/api/goal-planning/start`、`/api/goal-planning/clarification`、`/api/goal-planning/progress`、`/api/goal-planning/actions`、`/api/goal-planning/review`、`/api/goal-planning/apply`、`/api/goal-planning/session/save`、`/api/goal-planning/session/:id`
  本地：`GoalBreakdownPage`、`GoalPlanningService`、`GoalPlanningApplyService`
  结论：目标理解、追问、进度跟进、行动方案、采纳并落地到本地 `Goal/Task/DayEvent` 的主链路已经接回。

- 云端 AI 今日计划
  服务端：`/api/plan/today`、`/api/plan/save`、`/api/plan/adopted`
  本地：`TodayPlanService`、`TodayPlanPage`、`TaskSelectPage`、`MainPage`、`TodayTab`
  结论：云端计划读取、采纳、回写、本地缓存同步，以及采纳时的真实消费与 adopt usage 上报都已接回。

- AI 一键重排
  服务端：`/api/agent/completion`、`/api/credit/spend`、`/api/usage/report`
  本地：`ReschedulePage`、`RescheduleService`、`TaskListTab`
  结论：逾期任务分析、AI 重排建议、建议采纳、真实消费和 adopt usage 上报已接回。

- 积分余额展示
  服务端：`/api/credit/balance`
  本地：`AuthService`、`MeTab`
  结论：会员页和“我的”页已能读取当前积分余额和会员有效状态。

- 积分流水明细
  服务端：`/api/credit/transactions`
  本地：`CreditService`、`CreditTransactionsPage`、`MeTab`
  结论：积分明细分页、收入/支出筛选、累计获得/累计消耗展示和入口跳转已接回。

- 积分与配额计费闭环
  服务端：`/api/credit/precheck`、`/api/credit/spend`、`/api/usage/report`、`/api/usage/my`
  本地：`QuotaService`、`MembershipPage`、`UserPage`、`ReschedulePage`、`VoiceCreateOverlay`、`MainPage`、`GoalBreakdownPage`、`TodayPlanPage`
  结论：`voice_task`、`reschedule`、`goal_breakdown`、`today_plan` 的真实消费与 usage 上报闭环均已接回；会员页和用户页的额度读取链路与当前实现一致。

- 用户资料编辑
  服务端：`/api/auth/profile`
  本地：`UserPage`、`AuthService.updateAvatar`、`AuthService.updateNickname`、`MeTab`、`TodayTab`
  结论：昵称/头像更新已经接入云端持久化，更新后会刷新本地登录态并在“我的”页和首页回显，主链路已接回。

- 公告系统
  服务端：`/api/announcements/active`
  本地：`AnnouncementService`、`AnnouncementsPage`、`TodayTab`、`MainPage`
  结论：首页公告横幅和公告列表页已接回。

- Onboarding 与目标规划会话衔接
  服务端：匿名 `visitorId` + `/api/goal-planning/start` + `/api/goal-planning/session/:id`
  本地：`OnboardingPage`、`GoalBreakdownPage`、`GoalPlanningService`
  结论：引导期匿名起步后会沿用同一 `sessionId` 继续完整规划流程，不再中途掉回旧页丢失服务端会话。

- 真实语音识别 SDK 链路
  服务端：`/api/speech/token`
  本地：`VoiceRecognitionService`、`TokenService`、`VoiceCreateOverlay`、`MainPage`、`entry/libs/neonui.har`
  结论：`neonui` SDK、Token 获取、录音采集与实时识别主链路已接回，工程依赖和构建也已打通。

- 智能语音创建
  服务端：`/api/voice-create/analyze`
  本地：`VoiceCreateOverlay`、`VoiceCreateService`、`MainPage`、`DayEventCreatePage`
  结论：录音识别、服务端意图分析和 `task/goal/focus/reminder` 全部分流已接回；`reminder` 现在会返回周期提醒、习惯、重要日子、纪念日、倒计时的结构化字段，并已在测试环境 `116.62.6.179:3000` 真实接口验证通过，可直接预填到提醒创建页。

- 目标规划 Trace 视图
  服务端：`/api/goal-planning/trace/:id`
  本地：`GoalPlanningService.getTrace()`、`GoalPlanningTracePage`、`GoalBreakdownPage`、`main_pages.json`
  结论：Trace 页面、路由和入口已重新接回；当前页面可加载服务端 Trace、支持按类型/状态/顺序/数量筛选，能查看会话概览、统计摘要和单条 Trace 详情，整包构建已恢复通过。

- Telemetry 初始化与业务埋点
  服务端：`/api/telemetry/event`、`/api/telemetry/batch`
  本地：`EntryAbility`、`TelemetryService`、`TelemetryHelper`、`MembershipPage`、`TodayPlanPage`、`GoalBreakdownPage`、`ReschedulePage`、`CreateTaskPage`、`TaskDetailPage`、`GoalDetailPage`、`SearchPage`、`VoiceCreateOverlay`、`VoiceCreateService`、`AnnouncementsPage`、`AnnouncementService`、`CreditTransactionsPage`、`CreditService`、`MainPage`、`MeTab`
  结论：初始化、会话事件、会员、AI 任务、目标规划、重排、搜索、语音创建、公告、积分流水和相关入口/页面曝光埋点已接回；`/api/voice-create/analyze`、`/api/announcements/active`、`/api/credit/transactions` 的失败也已纳入 Telemetry。

## 部分修复

- 当前无部分修复项。

## 完全缺失

- 当前无完全缺失项。

## 暂不纳入 Harmony 主端恢复范围

- 管理后台 Web
  服务端：`/api/admin/*`、`/api/telemetry/admin/*`、`server/admin/*`
  结论：这是后台管理能力，不属于当前主端 App 核心恢复范围，建议单独作为后台恢复任务处理。

- 模拟会员购买接口
  服务端：`/api/subscription/buy`
  本地现状：`AuthService.purchaseMembership()` 存在，但当前会员页主链路实际走的是华为 IAP
  结论：这是备用/开发链路，不是当前生产支付入口。

## 当前建议优先级

1. 对 `目标规划 Trace` 做一次真机或模拟器完整回归。
   原因：Trace 页面刚完成重建，当前已可编译且能拉服务端数据，下一步最需要确认的是从 `GoalBreakdownPage` 入口进入后的加载、筛选和详情弹层体验。

2. 补充智能语音创建的真机端到端验收记录。
   原因：服务端真实接口已验证通过，下一步更适合补充设备侧录音到落页的回归验收，而不是继续改主链路。

3. 梳理当前 ArkTS 警告和过时 API 替换计划。
   原因：整包已恢复通过，但仍有大量 `deprecated` 和 `Function may throw exceptions` 告警，后续会影响稳定性和升级成本。

4. 继续梳理剩余页面和后台辅助能力的收尾项。
   原因：当前核心主链路已经全部接回，后续更适合做验收、观测性和技术债收边。

## 2026-04-21 复核结论

- 当前清单相较 2026-04-19 已过期；最新工作区已经重新回到 `BUILD SUCCESSFUL`，此前的 `HttpClient.ets`、`TelemetryHelper.ets`、`AuthService.ets` ArkTS 阻塞已清除。
- `用户资料编辑` 已经接上 `/api/auth/profile`，应从“部分修复”调整为“已修复”。
- `目标规划 Trace 视图` 已重新接回页面、路由和入口，并以更小的页面结构恢复服务端 Trace 加载、筛选、摘要和详情查看，当前应从“完全缺失”调整为“已修复”。
- `智能语音创建` 已完成提醒类结构化恢复，并已发布到测试环境 `116.62.6.179:3000` 用真实 `/api/voice-create/analyze` 做了接口验证，应从“部分修复”调整为“已修复”。
- `Telemetry` 已补齐语音创建、公告、积分流水和相关页面/入口曝光；当前整包重新回到 `BUILD SUCCESSFUL`，不再有新的编译级硬阻塞。

## 2026-04-19 更新

- 本轮补齐了 `GoalBreakdownPage` 与 `TodayPlanPage` 的真实消费和 usage 上报闭环，`积分与配额计费闭环` 已从“部分修复”调整为“已修复”。
- 并行工作区里一度缺失的 `components/CalendarTab.ets` 已补回，当前整包重新回到 `BUILD SUCCESSFUL`。
- 当前 Harmony 主端核心恢复工作已经从“补缺入口”阶段，进入“补齐剩余半恢复模块和稳定性/观测性收口”阶段。

## 2026-04-19 登录与账号修复补充

- App 默认构建环境已切到真实测试环境：`entry/src/main/ets/Utils/AppConfig.ets` 现在默认指向 `http://116.62.6.179:3000`，并关闭了离线账号兜底，避免把真实登录失败伪装成本地登录成功。
- 手机号登录已从“登录或自动注册”改为严格登录；注册入口独立保留在 `LoginPage` -> `RegisterPage`，已有账号不会再被误判成新账号流程。
- 会员页在测试环境下已切到 `/api/subscription/buy` 的测试购买链路，生产环境仍保留华为 IAP；因此“模拟会员购买接口”不再只是备用链路，而是测试环境的正式入口。
- 用户资料编辑已接入新的服务端接口 `/api/auth/profile`，昵称和头像会持久化到云端，`UserPage`/`MeTab`/`TodayTab` 已优先展示 `nickname`，不再通过篡改 `account` 字段伪装昵称。
- 上述资料编辑修复依赖将当前 `server/routes/auth.js` 重新部署到真实测试环境 `116.62.6.179:3000`；客户端代码已接好，服务端配置也已同步切回这台测试机。
- 服务端测试环境的 `HUAWEI_REDIRECT_URI` 已同步改到 `116.62.6.179:3000`；手机号登录/注册已可直接走测试环境，第三方 OAuth 仍依赖服务端配置实际部署到测试机。
- 误用的旧测试环境 `114.55.135.35:3001` 已完成下线和仓库清理：远端 PM2 进程、开发库和本地错误运维脚本均已移除，避免后续再把账号写进错误环境。
