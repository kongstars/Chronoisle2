const express = require('express');
const {
  HuaweiIapError,
  fulfillPurchase,
  processHuaweiNotification,
  getSupportedProductIds,
  getIapRequestDiagnostics
} = require('../services/HuaweiIapService');

const router = express.Router();
const GENERIC_IAP_SERVER_ERROR = '服务器支付配置不完整或内部错误';

function shouldExposeIapError() {
  const flag = String(process.env.IAP_DEBUG_ERRORS || '').toLowerCase();
  return flag === '1' || flag === 'true' || flag === 'yes' || process.env.NODE_ENV !== 'production';
}

function getIapClientMessage(error, statusCode) {
  if (statusCode < 500) {
    return error.message;
  }
  return shouldExposeIapError() ? (error.message || GENERIC_IAP_SERVER_ERROR) : GENERIC_IAP_SERVER_ERROR;
}

const checkUser = require('../middleware/checkUser');

/**
 * 校验并处理华为 IAP 订单。
 * POST /api/iap/verifyOrder
 * body: { jwsPurchaseOrder: string, productId?: string }
 */
router.post('/verifyOrder', checkUser, async (req, res) => {
  try {
    const result = await fulfillPurchase({
      userId: req.user.userId,
      jwsPurchaseOrder: req.body?.jwsPurchaseOrder,
      purchaseData: req.body?.purchaseData,
      clientProductId: req.body?.productId
    });

    res.json({
      success: true,
      message: result.alreadyProcessed ? '订单已处理，会员状态已同步' : '发货成功，会员已开通',
      data: {
        membershipType: result.user.membershipType,
        membershipPlan: result.user.membershipPlan || '',
        membershipProductId: result.user.membershipProductId || '',
        membershipExpireAt: result.user.membershipExpireAt,
        membershipRenewAt: result.user.membershipRenewAt || result.user.membershipExpireAt || 0,
        pendingMembershipPlan: result.user.pendingMembershipPlan || '',
        pendingMembershipProductId: result.user.pendingMembershipProductId || '',
        pendingMembershipEffectiveAt: result.user.pendingMembershipEffectiveAt || 0,
        orderId: result.order.orderId,
        productId: result.order.productId,
        alreadyProcessed: result.alreadyProcessed
      }
    });
  } catch (error) {
    const statusCode = error instanceof HuaweiIapError ? error.statusCode : 500;
    console.error('Huawei IAP verifyOrder failed:', {
      statusCode,
      message: error.message || String(error),
      diagnostics: getIapRequestDiagnostics({
        jwsPurchaseOrder: req.body?.jwsPurchaseOrder,
        purchaseData: req.body?.purchaseData,
        clientProductId: req.body?.productId
      }),
      stack: statusCode >= 500 ? error.stack : undefined
    });
    res.status(statusCode).json({
      success: false,
      message: getIapClientMessage(error, statusCode)
    });
  }
});

/**
 * 华为订单/订阅关键事件通知。
 * POST /api/iap/huawei/notify
 *
 * 该接口由华为服务器调用，不走用户 JWT。服务端会验证通知签名并做幂等处理。
 */
router.post('/huawei/notify', async (req, res) => {
  try {
    const result = await processHuaweiNotification(req.body || {});
    res.json({
      success: true,
      data: {
        processed: result.processed,
        duplicate: !!result.duplicate,
        needsManualReview: !!result.needsManualReview,
        ignored: !!result.ignored
      },
      message: result.message || '通知已接收'
    });
  } catch (error) {
    console.error('Huawei IAP notification failed:', {
      message: error.message || String(error),
      diagnostics: getIapRequestDiagnostics({
        jwsPurchaseOrder: req.body?.jwsNotification || req.body?.jwsPurchaseOrder ||
          req.body?.signedPayload || req.body?.signedContent || req.body?.notification || req.body?.payload,
        purchaseData: req.body
      }),
      stack: error.stack
    });
    res.status(500).json({ success: false, message: '通知处理失败' });
  }
});

router.get('/products', checkUser, (req, res) => {
  res.json({
    success: true,
    data: {
      productIds: getSupportedProductIds()
    }
  });
});

module.exports = router;
