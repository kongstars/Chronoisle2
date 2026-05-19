# 四时清单 — 华为应用市场上架 & 订阅收费上线清单

> 当前状态：**开发阶段**，部分基础设施已就位  
> 目标市场：**中国大陆 (CN)**  
> App ID: `6917602250875461286` | Bundle: `com.sishiqingdan.app`

---

## 一、AppGallery Connect 注册与配置

- [ ] **1.1 注册华为开发者账号**
  - 访问 [developer.huawei.com](https://developer.huawei.com) 注册企业/个人账号
  - 企业账号需提供营业执照；个人账号需实名认证（身份证+人脸）
  - 一次性注册费：企业约 ¥800，个人约 ¥300（以官方为准）
  - 审核周期：1-3 个工作日

- [ ] **1.2 开通 AppGallery Connect 服务**
  - 登录 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)
  - 创建项目 → 添加应用 → 填写包名 `com.sishiqingdan.app`
  - 开通以下 Kit 服务：
    - [ ] **IAP Kit** (应用内支付) — 订阅商品必须
    - [ ] **Account Kit** (华为账号登录) — 如使用华为第三方登录
    - [ ] **Analytics Kit** — 数据分析
    - [ ] **Crash Service** — 崩溃监控
    - [ ] **Cloud DB / Cloud Functions** — 若后端托管在华为云

- [ ] **1.3 配置应用信息**
  - 设置应用分类：工具 / 效率
  - 设置应用标签：时间管理、效率、清单、待办、番茄钟
  - 设置年龄分级
  - 填写隐私政策 URL

- [ ] **1.4 开通商户服务（订阅支付必须）**
  - 在 AppGallery Connect → 我的应用 → 选择应用 → 增长 → 应用内支付
  - 签署《华为应用内支付服务协议》
  - 绑定商户银行账户（企业：对公账户；个人：储蓄卡）
  - 银行审核周期：3-7 个工作日

---

## 二、应用签名 (Release Signing) 🔴 高优先级

> 当前 `build-profile.json5` 中 release 签名全为 TODO，**不解决无法提交审核**。

- [ ] **2.1 生成 Release 密钥库**
  - 在 DevEco Studio: Build → Generate Key and CSR
  - 或使用 keytool 命令行生成 .p12 密钥库
  - 密钥算法：`SHA256withECDSA`
  - 妥善保管密钥库文件和密码（丢失后无法更新应用）

- [ ] **2.2 上传证书至 AppGallery Connect**
  - 在 AppGallery Connect → 我的应用 → 选择应用 → 开发 → 证书管理
  - 上传 .csr 文件 → 下载签发的 .cer 数字证书
  - 同时下载 .p7b Profile 文件

- [ ] **2.3 配置 build-profile.json5 release 签名**
  - 文件路径：`build-profile.json5` (L51-63)
  - 替换所有 5 个 TODO 字段：
    ```
    certpath: 华为签发的 .cer 文件路径
    keyAlias: 生成 CSR 时设置的别名
    keyPassword: 密钥密码
    profile: .p7b 文件路径
    storeFile: .p12 密钥库文件路径
    storePassword: 密钥库密码
    ```

- [ ] **2.4 验证 Release 构建**
  - `assembleHap --mode release` 构建成功
  - 安装到测试设备验证签名有效

---

## 三、IAP / 订阅商品配置 🔴 高优先级

> 当前代码中已定义两个产品 ID：`vip_monthly_continuous` / `vip_yearly_continuous`

- [ ] **3.1 在 AppGallery Connect 创建订阅商品**
  - 路径：AppGallery Connect → 我的应用 → 增长 → 应用内支付 → 订阅商品
  - 创建两个自动续期订阅：

| 产品 ID | 名称 | 价格建议 | 续期周期 | 免费试用 |
|---------|------|----------|----------|----------|
| `vip_monthly_continuous` | 月度连续会员 | ¥25/月 | 1 个月 | 可设 3 天 |
| `vip_yearly_continuous` | 年度连续会员 | ¥198/年 | 1 年 | 可设 7 天 |

- [ ] **3.2 配置订阅商品属性**
  - 设置商品显示名称（多语言：zh-CN / en-US）
  - 设置商品描述
  - 设置价格（含税）
  - 设置订阅组（将两个商品归入同一订阅组，支持升级/降级）
  - 上传订阅商品图标 (512×512 PNG)

- [ ] **3.3 验证商品 ID 一致性**
  - 确认代码中 `AppConfig.getMembershipProductIds()` 返回的 ID
  - 与 AppGallery Connect 后台配置的 ID **完全一致**
  - 文件：`entry/src/main/ets/Utils/AppConfig.ets` (L37-38)

- [ ] **3.4 实现订阅流转逻辑确认**
  - 月→年：升级（按比例退款剩余天数）
  - 年→月：降级（当前年度到期后切换为月度）
  - 代码参考：`MembershipPage.ets` 中的 plan switching 逻辑

- [ ] **3.5 确认 IAP 环境可用**
  - 华为 IAP Kit 要求设备登录华为账号且地区为中国大陆
  - 代码验证：`IAPService.checkEnvironment()` (L86)
  - 沙箱测试：使用华为 IAP 沙箱环境测试购买流程

---

## 四、服务端准备

> 当前已有后端 API (server/ 目录)，需确认以下端点在线上环境可用

- [ ] **4.1 IAP 订单验证端点**
  - `POST /api/iap/verifyOrder` — 验证 JWS 购买凭证
  - 此端点必须调用华为 IAP 服务端 API 验证订单真实性
  - 华为 IAP 服务端验证文档：[服务端订单验证](https://developer.huawei.com/consumer/cn/doc/development/HMSCore-References/server-api-0000001050033288)
  - 验证成功后写入数据库：`membershipType`, `membershipExpireAt`, `membershipProductId` 等

- [ ] **4.2 订阅状态管理**
  - `GET /api/auth/me` — 返回用户会员状态（已有）
  - `GET /api/credit/balance` — 返回积分余额（已有）
  - `POST /api/credit/spend` — 扣减积分（已有）
  - [ ] 新增：华为订阅状态变更通知接收端点 (SUBS_NOTIFY_URL)
    - 处理续期成功、续期失败、取消订阅、退款等事件
    - 华为服务器会主动推送这些事件到你的后端

- [ ] **4.3 数据库/存储确认**
  - User 表包含完整的 membership 字段
  - 支持事务性更新（购买与积分变更的原子性）
  - 订阅到期自动降级任务（定时任务/Cron）

- [ ] **4.4 服务端部署**
  - 确认服务端部署到生产环境
  - HTTPS 证书配置
  - 域名备案（如服务器在中国大陆）
  - 华为 IAP 回调地址白名单配置

---

## 五、应用内待完善项

> 已发现的问题需要在上架前修复

- [x] **5.1 🔴 修复 MembershipReminderService 包名错误** ✅
  - 文件：`entry/src/main/ets/services/MembershipReminderService.ets` L67
  - ~~`'com.example.timelogger'`~~ → `'com.sishiqingdan.app'`

- [x] **5.2 🔴 接入 MembershipReminderService** ✅
  - 已完成以下接入：
    - [x] 用户购买成功后 → `IAPService.purchase()` 和 `restoreMembershipFromHuawei()` 中调用 `scheduleExpiryReminders()`
    - [x] 应用启动时 → `EntryAbility.onForeground()` 中调用 `checkExpiryOnLaunch()`，到期提醒 toast 展示

- [x] **5.3 隐私政策 & 用户协议** ✅ (已有)
  - `PrivacyPolicyPage` 含 4 条款：收集信息、使用方式、信息保护、你的选择
  - `TermsOfServicePage` 含 4 条款：功能使用、账户责任、会员服务、服务变更
  - [ ] 仍需确认：内容须经法务审核，且页面 URL 需在 AGC 后台填写

- [ ] **5.4 应用权限说明**
  - 当前声明的权限：
    - `ohos.permission.INTERNET` — 网络访问
    - `ohos.permission.PUBLISH_AGENT_REMINDER` — 系统提醒
    - `ohos.permission.MICROPHONE` — 语音创建
    - `ohos.permission.READ_CALENDAR` / `WRITE_CALENDAR` — 日历集成
  - [ ] 在应用中向用户解释每个权限的用途（华为审核要求）
  - [ ] 确认权限申请时机合理（非启动时一次性请求所有权限）

- [ ] **5.5 应用图标 & 启动页**
  - 当前图标：`$media:layered_image`
  - [ ] 提供 1024×1024 应用图标（前景 + 背景分层）
  - [ ] 启动页品牌展示

- [x] **5.6 用户协议弹窗** ✅
  - `OnboardingPage` Step 0 增加隐私政策 + 用户协议勾选同意
  - 未同意时"开始创建第一个目标"按钮置灰不可点击
  - 提供《隐私政策》和《用户协议》链接跳转

- [x] **5.7 付费功能引导** ✅ (已有)
  - `MembershipPage` 展示会员权益对比
  - `QuotaService` 超出免费额度时弹出升级引导弹窗
  - `MeTab` 展示当前会员状态与权益入口

- [x] **5.8 取消订阅指引** ✅
  - `HelpPage` FAQ 新增 3 项：
    - 高级会员功能与订阅方式
    - 如何取消自动续费（含华为应用市场路径）
    - 换手机后如何恢复购买

---

## 六、应用商店物料准备

- [ ] **6.1 应用截图**
  - 至少 3 张（建议 5-8 张）
  - 分辨率要求：华为应用市场当前要求的尺寸（通常 1080×2340 或类似比例）
  - 覆盖核心功能场景：
    - [ ] 首页（今日视图 + AI 计划）
    - [ ] 任务列表与创建
    - [ ] AI 一键重排
    - [ ] 番茄专注
    - [ ] 会员权益页

- [ ] **6.2 应用描述**
  - [ ] 一句话简介（≤30 字）
  - [ ] 详细描述（≥200 字），突出核心卖点：
    - AI 驱动的任务规划与重排
    - 目标管理与关键结果追踪
    - 番茄钟 + 白噪音专注
    - 语音创建任务
    - 日历视图 + 提醒系统
  - [ ] 更新日志（首版本写 "首次发布"）

- [ ] **6.3 宣传视频 (建议)**
  - 16:9 横屏，1080p 以上
  - 展示核心操作流程（30-90 秒）

- [ ] **6.4 应用分类 & 标签**
  - 主分类：工具 → 效率
  - 标签：待办、时间管理、计划、番茄钟、AI 助手

- [ ] **6.5 关键词 (SEO)**
  - 研究华为应用市场搜索关键词
  - 中文：清单、待办、时间管理、番茄钟、AI 计划、日程提醒、效率工具
  - 合理覆盖长尾关键词

---

## 七、测试验证

- [ ] **7.1 IAP 沙箱测试**
  - 在华为 IAP 沙箱环境中完成完整购买流程
  - 测试场景：
    - [ ] 首次订阅（月度）
    - [ ] 首次订阅（年度）
    - [ ] 从月度升级到年度
    - [ ] 从年度降级到月度
    - [ ] 自动续费成功
    - [ ] 自动续费失败（余额不足）
    - [ ] 取消订阅
    - [ ] 恢复购买（换设备/重装）
    - [ ] 购买过程中断网
    - [ ] 购买取消（用户取消支付）

- [ ] **7.2 付费权限验证**
  - [ ] 免费用户功能限制生效（AI 次数、目标数量等）
  - [ ] 购买后立即解锁所有付费功能
  - [ ] 订阅到期后自动回退为基础会员
  - [ ] 积分系统与会员状态联动

- [ ] **7.3 IAPRetryQueue 测试**
  - 模拟验证失败 → 确认进入重试队列
  - 确认重试间隔正确（5min / 30min / 2h）
  - 确认 3 次失败后订单被丢弃

- [ ] **7.4 兼容性测试**
  - 覆盖 HarmonyOS 6.1.0+ 设备
  - 测试不同屏幕尺寸（手机 + 折叠屏）
  - 测试横竖屏切换（如支持）

- [ ] **7.5 性能测试**
  - 应用冷启动时间 ≤ 2s
  - 页面切换流畅（无卡顿）
  - 内存占用合理（≤ 200MB）

- [ ] **7.6 隐私合规测试**
  - 首次启动展示隐私弹窗
  - 权限请求在合理时机触发
  - 未授权权限时功能正常降级（非崩溃）

- [ ] **7.7 Release 构建全流程测试**
  - Release 签名构建
  - 安装到真机
  - 全部功能走查
  - IAP 沙箱购买

---

## 八、提交审核

- [ ] **8.1 最终检查清单**
  - [ ] Release 签名配置完成
  - [ ] IAP 商品在 AppGallery Connect 配置并启用
  - [ ] 服务端所有 API 在生产环境正常运行
  - [ ] 隐私政策 URL 可访问
  - [ ] 应用内所有 TODO / 占位内容已移除
  - [ ] mock 开关确认关闭 (`MOCK_MEMBERSHIP_PURCHASE = false`)
  - [ ] 版本号与管理后台一致

- [ ] **8.2 上传应用包**
  - 在 AppGallery Connect → 我的应用 → 版本管理
  - 上传 Release HAP/HAPC 包
  - 填写版本号与更新内容

- [ ] **8.3 提交审核**
  - 填写审核备注（提供给审核人员的说明）
  - 提供测试账号（如需登录才能体验完整功能）
  - 如有付费功能，提供沙箱测试说明

- [ ] **8.4 审核周期**
  - 通常 3-7 个工作日
  - 如被驳回，根据驳回原因逐条修改，重新提交

---

## 九、上线后运维

- [ ] **9.1 订阅数据监控**
  - 搭建订阅转化漏斗监控
  - 关键指标：曝光 → 点击 → 购买 → 续费
  - 监控订阅流失率 (Churn Rate)

- [ ] **9.2 服务端监控**
  - IAP 验证成功率
  - 订单异常告警（验证失败率突增）
  - 华为订阅状态通知处理成功率

- [ ] **9.3 客服准备**
  - 准备常见问题 FAQ（退款、取消订阅、恢复购买）
  - 华为要求提供客服联系方式

- [ ] **9.4 版本更新计划**
  - 确定更新迭代节奏
  - 提前规划新功能与 bug 修复版本

---

## 优先级总览

| 优先级 | 类别 | 关键事项 |
|--------|------|----------|
| 🔴 P0 | 签名 | Release 签名配置 |
| 🔴 P0 | IAP | 订阅商品创建与配置 |
| 🔴 P0 | 后端 | IAP 验证端点 + 订阅状态通知 |
| 🔴 P0 | Bug | MembershipReminderService 包名修复 |
| 🔴 P0 | Bug | MembershipReminderService 接入 |
| 🟡 P1 | 合规 | 隐私政策 + 用户协议完善 |
| 🟡 P1 | 物料 | 截图、描述、图标 |
| 🟡 P1 | 测试 | IAP 沙箱全流程测试 |
| 🟢 P2 | 运维 | 监控、客服、FAQ |
| 🟢 P2 | 营销 | 关键词优化、宣传视频 |

---

> 📅 建议时间线: P0 事项 1-2 周 → P1 事项 1 周 → 提交审核 → 2 周缓冲 → 上线
