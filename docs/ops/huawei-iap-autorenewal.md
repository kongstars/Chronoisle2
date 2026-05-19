# 华为应用内购买自动续期接入说明

本文记录四时清单第一版华为 IAP 自动续期会员接入口径。

## 商品范围

第一版只开放两个自动续期商品：

| 商品 ID | 类型 | 本地权益 |
| --- | --- | --- |
| `vip_monthly_continuous` | 自动续期月卡 | 高级会员 + 当月会员积分 |
| `vip_yearly_continuous` | 自动续期年卡 | 高级会员 + 当月会员积分 |

不再使用 `vip_monthly`、`vip_yearly` 作为正式会员商品。

## 端侧流程

1. `MembershipPage` 调用 `AppConfig.getMembershipProductIds()` 获取商品 ID。
2. `IAPService.queryProducts()` 只按 `ProductType.AUTORENEWABLE` 查询商品。
3. 用户购买后，端侧调用华为 `createPurchase()`。
4. 端侧把 `jwsPurchaseOrder` 和 `productId` 提交到 `/api/iap/verifyOrder`。
5. 服务端验签、入库、幂等发货，并返回最新会员状态。

当前 `AppConfig.useMockMembershipPurchase()` 默认为 `false`，测试环境也会走华为沙盒链路。

## 服务端接口

### 用户主动校验订单

`POST /api/iap/verifyOrder`

需要用户 JWT。

请求体：

```json
{
  "jwsPurchaseOrder": "华为返回的签名订单",
  "productId": "vip_monthly_continuous"
}
```

处理逻辑：

- 使用 `HUAWEI_IAP_PUBLIC_KEY` 验签。
- 只接受 `vip_monthly_continuous`、`vip_yearly_continuous`。
- 写入 `IapOrder`。
- 同一 `orderId` 或同一 JWS 重试不会重复发货。
- 发货后更新 `User.membershipType`、`User.membershipExpireAt`。
- 发放当月会员积分，并重置当月用量统计。

### 华为事件通知

`POST /api/iap/huawei/notify`

不需要用户 JWT。

处理逻辑：

- 接收华为订单/订阅关键事件通知。
- 使用签名载荷验签。
- 写入 `IapEvent` 并按事件 ID/JWS 做幂等。
- 续费/购买事件会补发会员权益。
- 取消自动续期只记录状态，会员保留到当前周期结束。
- 退款/撤销/过期事件会重新计算会员状态。
- 无法匹配本地订单的事件会标记为 `needs_manual_review`。

## AppGallery Connect 配置

在“应用内购买服务”中配置：

| 配置项 | 建议值 |
| --- | --- |
| 生产环境服务器地址 | `https://sishiqingdan.cn/api/iap/huawei/notify` |
| 沙盒环境服务器地址 | `https://test-api.sishiqingdan.cn/api/iap/huawei/notify` |
| 商品类型 | 自动续期订阅 |
| 商品 ID | 与上方商品范围一致 |

### 测试环境 HTTPS 域名配置

由于华为后台要求订单/订阅关键事件通知地址必须是 `https`，测试环境不能直接填写 `http://114.55.135.35:3000/...`。

当前推荐测试地址：

```text
https://test-api.sishiqingdan.cn/api/iap/huawei/notify
```

落地方式：

1. DNS A 记录：`test-api.sishiqingdan.cn -> 114.55.135.35`
2. 安全组放行 `80/TCP`、`443/TCP`
3. 在测试服务器安装 Nginx 并反代到本机 `127.0.0.1:3000`
4. 证书文件放在：

```text
/opt/chronoisle-server/cert/test-api.sishiqingdan.cn.pem
/opt/chronoisle-server/cert/test-api.sishiqingdan.cn.key
```

5. Nginx 配置模板见：

```text
server/nginx_test.conf
```

## 服务器环境变量

测试服和正式服都需要配置：

```bash
HUAWEI_PAY_CLIENT_ID=...
HUAWEI_PAY_CLIENT_SECRET=...
HUAWEI_IAP_PUBLIC_KEY=...
HUAWEI_IAP_KEY_ID=...
HUAWEI_IAP_PRIVATE_KEY_PATH=...
```

`HUAWEI_IAP_PUBLIC_KEY` 可以是完整 PEM，也可以是不带头尾的 Base64 公钥内容。

测试阶段当前使用 AppGallery Connect 服务端密钥：

| 项 | 值 |
| --- | --- |
| 密钥名称 | `test1` |
| 密钥 ID | `12fbf26a-6724-4fe7-a762-1a570e490907` |
| 本机私钥文件 | `C:/Users/fangj/Downloads/IAPKey_12fbf26a-6724-4fe7-a762-1a570e490907.p8` |

私钥文件不进入仓库，不在聊天或文档中粘贴内容。部署到测试服务器时，把 `.p8` 放到服务器安全目录，再通过 `HUAWEI_IAP_PRIVATE_KEY_PATH` 配置绝对路径。

## 上架前密钥轮换提醒

正式上架前必须执行：

1. 在 AppGallery Connect 重新创建正式服务端密钥。
2. 替换测试服和正式服的 `HUAWEI_IAP_KEY_ID`、`HUAWEI_IAP_PRIVATE_KEY_PATH`。
3. 用正式密钥完成一次沙盒/生产前验证。
4. 确认无回滚需求后，撤销或停用 `test1` 测试密钥。

## 验收清单

- `test1` 测试密钥仅用于联调，不用于正式上架。
- 会员页能查询到两个自动续期商品。
- 沙盒月卡购买后会员立即生效。
- 沙盒年卡购买后会员立即生效。
- 同一订单重复提交不会重复延长会员。
- 取消自动续期通知能入库，会员不提前失效。
- 退款/撤销通知能入库，并重新计算会员状态。
- 过期通知能入库，并将无有效订单的用户降为基础版。
