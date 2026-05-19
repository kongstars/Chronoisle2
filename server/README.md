# Chronoisle Server

Chronoisle 的服务端代码，负责账号、同步、积分、会员、AI 规划、公告、埋点等接口。

## 当前环境

当前只有两套有效环境：

| 环境 | 地址 | MongoDB | PM2 进程 |
| --- | --- | --- | --- |
| 测试 | `http://114.55.135.35:3000` | `chronoisle_prod` | `chronoisle-server-prod` |
| 正式 | `http://116.62.6.179:3000` | `sishiqingdan_prod` | `sishiqingdan-server-prod` |

说明：

- 历史旧测试端口 `114.55.135.35:3001` 已下线，不应再出现在任何配置、脚本或部署流程中。
- 部署脚本只会连接上表中的两台服务器。

## 本地开发

推荐环境：

- Node.js `18+`
- npm `9+`
- MongoDB `6+`

安装依赖：

```bash
cd server
npm install
```

本地启动：

```bash
npm run dev
```

生产模式启动：

```bash
npm start
```

默认入口文件是 `index.js`。

## 环境变量

服务端启动至少需要这些变量：

- `NODE_ENV`
- `PORT`
- `MONGODB_URI`
- `JWT_SECRET`
- `ADMIN_USERNAME`
- `ADMIN_PASSWORD`
- `ADMIN_JWT_SECRET`

如果要启用语音、AI、华为账号或华为支付，还需要：

- `ALIBABA_CLOUD_ACCESS_KEY_ID`
- `ALIBABA_CLOUD_ACCESS_KEY_SECRET`
- `ALIBABA_CLOUD_SPEECH_APP_KEY`
- `ALIBABA_CLOUD_REGION`
- `ALIBABA_CLOUD_BAILIAN_API_KEY`
- `ALIBABA_CLOUD_BAILIAN_APP_ID`
- `DEEPSEEK_API_KEY`
- `DEEPSEEK_MODEL`
- `HUAWEI_CLIENT_ID`
- `HUAWEI_CLIENT_SECRET`
- `HUAWEI_REDIRECT_URI`
- `HUAWEI_PAY_CLIENT_ID`
- `HUAWEI_PAY_CLIENT_SECRET`
- `HUAWEI_IAP_PUBLIC_KEY`
- `HUAWEI_IAP_KEY_ID`
- `HUAWEI_IAP_PRIVATE_KEY_PATH`

华为应用内购买第一版只开放自动续期会员商品：

- `vip_monthly_continuous`
- `vip_yearly_continuous`

生产/沙盒的 AppGallery Connect 事件通知地址应分别配置到：

- 正式：`https://sishiqingdan.cn/api/iap/huawei/notify`
- 沙盒：`https://test-api.sishiqingdan.cn/api/iap/huawei/notify`

该通知接口由华为服务器调用，不需要用户 JWT；服务端会使用 `HUAWEI_IAP_PUBLIC_KEY` 验签并做订单幂等处理。

服务端 `.p8` 私钥文件只能放在服务器安全目录，通过 `HUAWEI_IAP_PRIVATE_KEY_PATH` 引用，不能提交到 Git。测试阶段可使用 AppGallery Connect 中名为 `test1` 的服务端密钥；正式上架前必须新建正式密钥并轮换配置。

说明：

- 本地示例变量见 `.env.example`。
- 仓库里的 `.env.development` 和 `.env.production` 反映的是当前测试/正式配置口径。
- 部署脚本打包时会忽略 `.env`、`.env.*`，远端服务器上的环境文件不会被本地脚本覆盖。

## 部署

测试环境部署：

```bash
cd server
npm run deploy:test
```

正式环境部署：

```bash
cd server
npm run deploy:prod
```

部署脚本位置：

- `scripts/deploy/deploy_test.js`
- `scripts/deploy/deploy_prod.js`
- `scripts/shared/serverTargets.js`

部署脚本会执行这些动作：

1. 把当前 `server/` 打成 zip 包
2. 上传到目标服务器
3. 解压到 `/opt/chronoisle-server`
4. 执行 `npm ci --omit=dev`
5. `pm2 restart ... --update-env`
6. 调用 `/health` 做健康检查

## 常用脚本

当前保留的运维脚本都在 `scripts/`：

- `deploy_test.js`: 部署到测试环境
- `deploy_prod.js`: 部署到正式环境
- `deploy_all.js`: 顺序部署两台机器
- `backup_and_deploy_all.js`: 先备份再部署
- `check.js`: 检查测试环境数据库连通性
- `check_everything.js`: 统一巡检两台服务器
- `clean_orphans.js`: 清理孤儿进程或残留发布物
- `wipe_again.js`: 再次执行清理动作
- `fix_db.js`: 修复积分统计字段
- `grant_vip_credits.js`: 给有效会员批量发放积分

如果要新增运维脚本，直接复用 `scripts/shared/serverTargets.js` 里的环境映射，不要在脚本里手写新的 IP、端口或库名。

## 接口与验证

基础健康检查：

```bash
curl http://127.0.0.1:3000/health
```

常见功能包括：

- 账号登录、注册、第三方登录
- 用户资料读写
- 云同步
- 积分账户与积分流水
- 会员购买与会员状态同步
- 今日计划、目标规划、AI 重排
- 公告系统
- Telemetry 事件上报

客户端当前默认测试地址见 `../entry/src/main/ets/Utils/AppConfig.ets`。

## 维护约束

- 不要恢复 `3001` 端口相关配置。
- 不要再引入 `chronoisle_dev`、`sishiqingdan_dev`、`sishiqingdan-server-dev` 等旧开发环境标识。
- 任何新的部署、巡检、修库脚本都应通过 `scripts/shared/serverTargets.js` 读取目标环境。
- 如果要调整线上地址，必须同时更新客户端 `../entry/src/main/ets/Utils/AppConfig.ets`、服务端环境文件和 `scripts/shared/serverTargets.js`。
