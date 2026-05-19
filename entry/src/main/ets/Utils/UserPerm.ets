import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from './Logger';

const logger = Logger.create('UserPerm');

const MICROPHONE_PERMISSION: Permissions = 'ohos.permission.MICROPHONE';

async function getAccessTokenId(): Promise<number> {
  const bundleInfo = await bundleManager.getBundleInfoForSelf(
    bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
  );
  return bundleInfo.appInfo.accessTokenId;
}

async function hasPermission(permission: Permissions): Promise<boolean> {
  const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  const tokenId = await getAccessTokenId();
  const grantStatus = await atManager.checkAccessToken(tokenId, permission);
  return grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
}

export async function hasMicrophonePermission(): Promise<boolean> {
  try {
    return await hasPermission(MICROPHONE_PERMISSION);
  } catch (error) {
    const err = error as BusinessError;
    logger.error('[UserPerm] 麦克风权限检查失败 code=${err.code} message=${err.message}');
    return false;
  }
}

export async function requestMicrophonePermission(context: Context): Promise<boolean> {
  const uiContext = context as common.UIAbilityContext;
  const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();

  try {
    if (await hasMicrophonePermission()) {
      return true;
    }

    const result = await atManager.requestPermissionsFromUser(uiContext, [MICROPHONE_PERMISSION]);
    return result.authResults.length > 0 && result.authResults[0] === 0;
  } catch (error) {
    const err = error as BusinessError;
    logger.error('[UserPerm] 麦克风权限申请失败 code=${err.code} message=${err.message}');
    return false;
  }
}

export async function checkPermissions(context: Context): Promise<boolean> {
  return await requestMicrophonePermission(context);
}
