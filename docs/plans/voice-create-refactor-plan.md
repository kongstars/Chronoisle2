# 语音创建功能评审与系统化优化方案

更新时间：2026-04-27

本文基于当前代码状态评审语音创建链路，并把优化范围从“浮层交互”扩大为“语音创建系统”：入口、识别、意图分类、字段抽取、创建页 AI 填入、服务端契约、可观测性和回归测试一起纳入。

本轮已先落地 P0 风险修正，并继续推进 P1/P2：语音浮层新增转写确认态，默认改为 classify 快路径进入创建页；任务、提醒、专注页接入各自的后台 `parseFields()`；AI 填入提示的“清除”语义先改为“隐藏提示”；新增共享 `AppAIFillBanner` / `AppAIFillIndicator`；补上 `VoiceCreateSession` 和端到端 `traceId`；服务端 parse 缓存改为文本 hash，classify/parse/analyze 日志改为截断文本；并拆出 classify/parse 模型配置、超时配置和标准 `errorCode`。

体验层本轮继续优化：`VoiceCreateOverlay` 已收敛为“稳定状态面板 + 固定语音操作条”的结构，录音、确认转写、AI 理解、完成预览使用同一张卡片承载；转写框高度固定，意图切换和结果预览改为紧凑行内结构，入口标识去掉 emoji，统一成轻量技术感文字标识，降低状态切换时的闪动感。

## 1. 总体判断

语音创建应该被定位为高效率输入方式，而不是“新建内容”列表里的一个普通类型。它的产品目标不是展示更多 AI 过程，而是让用户更快把一句话转成可编辑、可保存的结构化内容。

当前代码已经完成了一部分底座：

- 服务端已经拆出 `/api/voice-create/classify` 和 `/api/voice-create/parse`。
- 客户端 `VoiceCreateService` 已经有 `preClassify()`、`classify()`、`parseFields()`。
- `VoiceCreateOverlay` 已经改为“转写确认 -> classify -> 快速路由”，并支持结果意图切换后重新解析。
- `MainPage` 已能把语音结果路由到任务、提醒、目标、专注创建页。
- 任务、提醒、专注创建页已经开始出现 AI 横幅和字段标识；提醒和专注页本轮已补上后台字段抽取。

但当前链路仍然不够“系统化”：AI 填入状态模型还不统一，服务端超时和模型拆分还没做，`traceId` 串联和回归样例集也还缺。这些问题会影响后续稳定性、排障效率和多页面扩展。

## 2. 当前代码事实

| 模块 | 当前事实 | 结论 |
| --- | --- | --- |
| `server/routes/voiceCreate.js` | 有 `/analyze`、`/classify`、`/parse`；parse 缓存已加入 `userId` 维度并使用文本 hash；classify/parse/analyze 已接收并返回 `traceId`；已拆 classify/parse 模型和超时配置 | 主体可用，仍需固定样例回归和更多错误码细分 |
| `VoiceCreateService.ets` | 有语气词清洗、规则预分类、classify、parseFields、`VoiceCreateSession` 与 `traceId` 参数 | 可作为客户端语音中台继续扩展 |
| `VoiceCreateOverlay.ets` | 状态已包含 `review`；录音结束先展示可编辑转写；默认只做 classify；完成后 650ms 自动路由；意图切换仍可 parse；会生成并传递 `VoiceCreateSession` | P0 快路径已落地，后续需补更完整低置信度策略 |
| `MainPage.ets` | 根据 `output.intent` 路由到对应创建页，传递已解析字段、`voiceRawText / voiceIntent` 和会话追踪字段 | 可用，后续可继续减少手写分支重复 |
| `CreateTaskPage.ets` | 已支持语音 `voiceRawText` 快路径进入；后台 `parseFields(task)` 补齐字段；接入共享 AI 横幅和字段标识 | P0/P1 局部完成，后续需抽统一状态模型 |
| `DayEventCreatePage.ets` | 根据路由参数先填原文/标题，随后自行调用 `parseFields(reminder)` 补齐字段 | P0 已接回，后续需统一字段状态和撤销 |
| `CreatePomodoroPage.ets` | 根据路由参数先填主题，随后自行调用 `parseFields(focus)` 补时长和关联任务 | P0 已接回，后续需统一字段状态和撤销 |
| `GoalBreakdownPage.ets` | 能接收语音原文进入目标规划 | 可用，但没有语音专属状态 |

## 3. 对当前改动的挑刺与状态

### 3.1 浮层重新承担了完整 parse，和“快速进入创建页”目标冲突

状态：本轮已修正主路径。`VoiceCreateOverlay` 现在默认只做 `classify(cleanedText)`，不再把完整 `parseFields()` 放在进入创建页之前。

仍需注意：

- 低置信度场景现在仍偏保守，后续应明确何时停留在确认页、何时直接 fallback 到任务页。
- 意图切换仍会在浮层内重新 parse，这是用户主动操作路径，可以保留，但必须继续确保并发保护。

建议：

- 继续保留“默认只 classify”的主路径。
- 仅在低置信度、用户停留预览、或者用户主动切换 intent 时，浮层内执行 parse 生成更完整预览。

### 3.2 900ms 自动跳转仍是人为延迟

状态：本轮已从 900ms 降到 650ms，并补了 `hasEmittedResult` 防重复路由。

建议：

- 规则命中或 classify 成功后立即提供“进入创建页”。
- 自动跳转保留为可取消的 600-800ms 进度条，但不要阻塞用户手动进入。
- 后续可以把 650ms 自动跳转改成明确进度条或“正在进入”，减少用户误判。

### 3.3 转写不可编辑，ASR 错误会被直接带入 AI

状态：本轮已增加 `review` 确认态，使用固定高度文本框展示原始转写，用户可编辑后再触发 AI 理解。

建议：

- 继续保持原始转写完整展示，不删除“喂喂喂”等内容。
- AI 分析时使用 `buildAnalysisText()` 清洗文本，但不反向改写转写框，避免页面闪烁。
- 后续增加“直接进入”快捷动作，给高频用户少点一次确认的选择。

### 3.4 意图切换后会立刻重新 parse，但缺少取消与并发保护

状态：本轮已加入 `overrideRequestToken`，只接受最后一次切换意图后的 parse 结果。

建议：

- 切换 intent 后先显示“将按 X 类型重新理解”，不要继续展示旧摘要。
- 用户点击“立即进入”时，如果正在重新解析，应允许走原文 fallback，而不是强制等待。

### 3.5 DayEvent / Pomodoro 的 AI 填入仍不是独立能力

状态：本轮已接入。`DayEventCreatePage` 和 `CreatePomodoroPage` 都会在收到 `voiceRawText` 后自行调用对应 intent 的 `parseFields()`。

建议：

- 解析只填空字段，用户已修改字段不得覆盖。
- 后续需要用统一 `AIFillState` 记录字段快照，否则无法严格判断“AI 后到结果是否覆盖了用户编辑”。

### 3.6 “清除 AI 填入内容”现在更像清除标识

状态：本轮先采用保守方案，把提醒页和专注页文案改为“隐藏提示”，避免误导用户以为字段值已撤销。

建议二选一：

- 如果只隐藏标识：文案改成“已隐藏 AI 填入提示”。
- 如果真的清除内容：需要记录字段快照，只恢复未被用户编辑过的 AI 字段。

### 3.7 `Set<string>` 不适合作为长期 AI 字段状态模型

当前 `aiFilledFields: Set<string>` 只能表达“有没有 AI 标识”，不能表达 pending、failed、edited、cleared，也不利于 ArkUI 响应式刷新。

建议：

- 改成统一的状态对象或数组。
- 抽出共享组件，避免三个创建页各写一套 AI 横幅和字段标识。

## 4. 扩大后的目标架构

语音创建拆成 5 层，而不是集中在一个 Overlay：

```text
入口层
  MainPage FAB / 全局语音快捷入口 / 创建页局部语音入口

采集层
  VoiceCreateOverlay：录音、转写展示、确认编辑、意图预览

理解层
  VoiceCreateService：preClassify / classify / parseFields / traceId

填入层
  CreateTaskPage / DayEventCreatePage / CreatePomodoroPage / GoalBreakdownPage
  负责后台 parse、字段回填、AI 标识、撤销和用户编辑保护

服务端层
  voiceCreate.js：分类、解析、缓存、模型、超时、样例回归
```

核心原则：

- 浮层负责“听清楚 + 判断去哪”，创建页负责“填清楚”。
- 原始转写用于展示，清洗文本用于 AI，不互相覆盖。
- parse 结果永远不能覆盖用户已经手动改过的字段。
- AI 填入必须有来源、状态、可撤销规则。
- 所有语音链路必须能被 traceId 串起来定位问题。

## 5. 推荐的双路径交互

### 5.1 快路径：效率优先

适用于规则命中或 classify 高置信度。

```text
录音结束
  -> 显示转写
  -> 规则预分类 / classify
  -> 立即进入对应创建页
  -> 创建页显示标题或原文
  -> 后台 parseFields
  -> 字段逐步补齐
```

用户感知目标：松手到进入创建页小于 2 秒。

### 5.2 确认路径：准确优先

适用于低置信度、网络异常、用户主动停留预览、或者用户切换意图。

```text
录音结束
  -> 转写确认，可编辑
  -> 用户确认
  -> classify
  -> 展示意图选择
  -> 用户可切换
  -> 进入创建页或在浮层补充预览
```

用户感知目标：不强迫用户等待完整 parse，但允许用户纠错。

## 6. 建议新增的共享模型

### 6.1 VoiceCreateSession

```ts
interface VoiceCreateSession {
  traceId: string;
  rawText: string;
  analysisText: string;
  intent: 'task' | 'reminder' | 'goal' | 'focus' | 'unknown';
  intentSource: 'rule' | 'llm' | 'manual' | 'fallback';
  confidence: number;
  titleCandidate: string;
  startedAt: number;
}
```

用途：

- Overlay、MainPage、创建页、服务端日志使用同一个 traceId。
- 创建页无需从零拼 `voiceRawText / voiceIntent / voiceTitle`。
- 后续可支持语音创建历史、失败重试和问题排查。

### 6.2 AIFillState

```ts
type AIFillFieldStatus = 'pending' | 'filled' | 'edited' | 'cleared' | 'failed';

interface AIFillState {
  source: 'voice' | 'manual_ai';
  parsing: boolean;
  errorMessage: string;
  fields: Record<string, AIFillFieldStatus>;
  snapshot: Record<string, string | number | boolean>;
}
```

用途：

- 统一 AI 横幅。
- 统一字段右侧 AI 标识。
- 支持“隐藏 AI 提示”和“撤销 AI 填入”两个不同动作。

## 7. 服务端优化范围

| 项 | 当前问题 | 建议 |
| --- | --- | --- |
| 模型 | 已支持 `VOICE_CLASSIFY_MODEL`、`VOICE_PARSE_MODEL` | 后续可按线上耗时和准确率调整模型 |
| 超时 | 已支持 classify 5s、parse 10s、analyze 15s 配置 | 后续按 telemetry p95 调整 |
| 缓存 | parse 已按 `userId:intent:hash(analysisText)` 隔离 | 后续可改 Redis，避免多实例缓存不一致 |
| 日志 | classify/parse/analyze 已使用 traceId 和 80 字截断日志 | 后续补更多结构化字段 |
| 错误码 | 已返回 `errorCode`，覆盖 `empty_analysis_text / classify_timeout / parse_timeout` 等主错误 | 后续扩展到更细的模型响应结构错误 |
| 回归 | 已建立 `server/tests/fixtures/voice-create-cases.json` 固定样例集 | 后续接自动化断言脚本，覆盖规则分流与字段抽取 |

## 8. 客户端优化范围

| 文件 | 建议动作 |
| --- | --- |
| `VoiceCreateOverlay.ets` | 恢复转写确认态；默认只 classify；补 `hasEmittedResult`；切换 intent 加 request token |
| `VoiceCreateService.ets` | 已增加 `traceId` 参数，并透出 `errorCode / traceId` |
| `MainPage.ets` | 已路由传 `VoiceCreateSession` 字段；后续减少手写分支重复 |
| `CreateTaskPage.ets` | 保留后台 parse，改用共享 `AIFillState` |
| `DayEventCreatePage.ets` | 接入后台 `parseFields(reminder)`，并复用 `AIFillState` |
| `CreatePomodoroPage.ets` | 接入后台 `parseFields(focus)`，并复用 `AIFillState` |
| `GoalBreakdownPage.ets` | 显示语音来源横幅，保留原始语音文本 |
| `ui/base/AIFillBanner.ets` | 新增共享横幅：解析中、已填入、失败、已编辑 |
| `ui/base/AIFillIndicator.ets` | 新增字段标识：pending、filled、edited |

## 9. 扩大后的落地顺序

### P0：修正当前链路风险

1. 已完成：`VoiceCreateOverlay` 增加 `hasEmittedResult`，防止重复跳转。
2. 已完成：默认链路改成 classify 后进入创建页。
3. 已完成：增加转写确认态，支持编辑文本和重新录音。
4. 已完成：`DayEventCreatePage` 接入 `parseFields(reminder)`。
5. 已完成：`CreatePomodoroPage` 接入 `parseFields(focus)`。
6. 已完成：提醒页和专注页先把“清除 AI 填入内容”改为“隐藏 AI 提示”。
7. 待继续：任务页同类文案与 AI 字段状态也应一起统一。

### P1：统一 AI 填入架构

1. 已完成：新增 `VoiceCreateSession`。
2. 待完成：新增 `AIFillState`。
3. 已完成：抽 `AppAIFillBanner` 和 `AppAIFillIndicator`。
4. 进行中：三个创建页统一字段状态、失败展示、用户编辑保护。
5. 意图切换使用 request token，避免旧 parse 覆盖新结果。

### P2：服务端契约和性能

1. 已完成：`callAgent()` 支持 timeout 参数。
2. 已完成：classify/parse 拆模型配置。
3. 已完成：parse cache key 改成 `userId:intent:hash(analysisText)`。
4. 已完成：服务端响应增加 `errorCode`，客户端服务层同步透出。
5. 已完成：classify/parse/analyze 日志只记录截断文本、traceId、intent 和 latency。
6. 已完成：新增 `server/tests/fixtures/voice-create-cases.json`，沉淀语音创建固定回归样例。

### P3：入口和体验扩展

1. 增加全局语音快捷入口，但不要破坏当前 FAB 新建逻辑。
2. 创建页标题栏增加“语音补充”入口，用于局部填字段。
3. 接入真实 RMS 后再做低音量提示。
4. 增加最长录音时长和倒计时。
5. 增加语音创建历史和失败重试入口。

## 10. 验收标准

### 功能

- “明天下午三点提醒我提交报告”进入提醒页，并补齐标题、类型、时间。
- “专注写周报 45 分钟”进入专注页，并补齐主题和时长。
- “喂喂喂，明天上午九点开会提醒我”转写框保留原文，AI 分析时过滤语气词。
- 预览页切换 intent 后，只接受最后一次 parse 结果。
- parse 失败时，创建页仍保留原文并允许手动保存。

### 交互

- 录音、确认、预览三个阶段面板宽度稳定，不因转写内容闪动。
- 用户可以在 AI 分析前修改转写文本。
- 用户修改某个 AI 字段后，该字段 AI 标识消失。
- “清除 AI 填入”行为和文案一致。

### 性能

- 规则命中：松手到进入创建页小于 1 秒。
- LLM classify：松手到进入创建页 p95 小于 2.5 秒。
- parse：进入创建页后 p95 5 秒内完成。
- parse 超时或失败不阻塞保存。

### 可观测性

- 每次语音创建有唯一 traceId。
- 能分别看到录音耗时、classify 耗时、parse 耗时、最终 intent、用户是否修改字段。
- 服务端能按 traceId 查到 classify 和 parse 日志。

## 11. 本轮性能与响应优化

- 长按启动延迟从 260ms 降到 180ms，减少“按住没反应”的体感等待。
- 录音前优先使用本地账号缓存做语音创建权益快检；缓存可用时不再等待云端预检，提交后仍用 `spendCredit()` 做真实扣费。
- 本地 `preClassify()` 规则命中时直接生成 `VoiceCreateSession` 并进入创建页，不再等待 `/api/voice-create/classify`。
- 规则未命中时仍走服务端 classify，保持复杂语句的理解能力。
- 客户端 classify 超时从 5s/8s 压到 3s/5s，parse 超时从 5s/10s 压到 3s/8s，避免长时间卡在 AI 理解态。
- 自动进入创建页等待从 650ms 降到 360ms；用户仍可手动点击进入。
- `voice_create_classified` 增加 `classifyMs`、`usedLocalRule`、`routeDelayMs`，后续可按真实 p95 继续调优。

验收口径：规则命中的“提醒 / 目标 / 专注”语句应主要受转写和扣费耗时影响，不再受 classify 网络耗时影响；复杂语句仍保留服务端分类兜底。

## 12. 不建议现在继续做的事

- 不建议继续把完整 parse 放在浮层主路径里，否则会牺牲效率工具最重要的速度。
- 不建议在没有真实 RMS 数据前做“声音太小”提示。
- 不建议让 AI parse 覆盖用户已经编辑的字段。
- 不建议每个创建页继续复制 AI 横幅和字段标识逻辑，后续维护成本会快速上升。
- 不建议把语音入口一下铺到所有页面。先把主链路做稳，再扩页面级入口。
