import { db, toSyncDataSet } from '../storage/Database';
import { authService, CodeResult } from '../services/AuthService';
import { cloudSyncService, type SyncDataSet } from '../services/CloudSyncService';
import { AppErrorService } from '../services/AppErrorService';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SECTION_GAP, SPACE_MD, SPACE_SM } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { RADIUS_MD } from '../foundation/tokens/RadiusTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('RegisterPage');

@Entry
@Component
struct RegisterPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State phone: string = '';
  @State code: string = '';
  @State tip: string = '';
  @State sending: boolean = false;
  @State registering: boolean = false;
  @State currentAccountLabel: string = '未登录';

  aboutToAppear(): void {
    const context = (this.getUIContext().getHostContext() as Context);
    Promise.all([
      db.initialize(context),
      authService.initialize(context),
      cloudSyncService.initialize(context)
    ]).then(() => {
      authService.getCurrentUser().then((user) => {
        if (user) {
          this.currentAccountLabel = `手机号：${user.account}`;
        }
      });
    });
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: SECTION_GAP }) {
          AppPageHeader({
            title: '手机号注册',
            subtitle: '用手机号创建账号，完成后直接进入首页',
            onBack: () => {
              this.getUIContext().getRouter().back();
            }
          })

          Column({ space: SECTION_GAP }) {
            AppCard({ variant: 'soft', spacing: SPACE_SM }) {
              Row({ space: 8 }) {
                AppStatusBadge({ text: '当前状态', tone: 'info', iconName: 'profile' })
                Text(this.currentAccountLabel)
                  .fontSize(TYPE_META)
                  .fontColor(this.themeColors.textSecondary)
              }
            }

            AppCard({ variant: 'base', spacing: SPACE_MD }) {
              Text('手机号')
                .fontSize(TYPE_META)
                .fontColor(this.themeColors.textSecondary)

              TextInput({
                placeholder: '请输入 11 位手机号',
                text: this.phone
              })
                .width('100%')
                .height(52)
                .fontSize(TYPE_BODY)
                .fontColor(this.themeColors.textPrimary)
                .padding({ left: 16, right: 16 })
                .backgroundColor(this.themeColors.inputBackground)
                .borderRadius(RADIUS_MD)
                .type(InputType.PhoneNumber)
                .onChange((value: string) => {
                  this.phone = value;
                })

              Text('验证码')
                .fontSize(TYPE_META)
                .fontColor(this.themeColors.textSecondary)

              Row({ space: 10 }) {
                TextInput({
                  placeholder: '请输入短信验证码',
                  text: this.code
                })
                  .layoutWeight(1)
                  .height(52)
                  .fontSize(TYPE_BODY)
                  .fontColor(this.themeColors.textPrimary)
                  .padding({ left: 16, right: 16 })
                  .backgroundColor(this.themeColors.inputBackground)
                  .borderRadius(RADIUS_MD)
                  .type(InputType.Number)
                  .onChange((value: string) => {
                    this.code = value;
                  })

                AppButton({
                  text: this.sending ? '发送中...' : '发送验证码',
                  variant: 'secondary',
                  buttonSize: 'sm',
                  iconName: 'phone',
                  disabled: this.sending,
                  tapAction: () => {
                    void this.sendCode();
                  }
                })
              }
              .width('100%')

              AppButton({
                text: this.registering ? '注册中...' : '完成注册',
                iconName: 'success',
                loading: this.registering,
                tapAction: () => {
                  void this.registerAndSync();
                }
              })

              if (this.tip.trim().length > 0) {
                Text(this.tip)
                  .fontSize(TYPE_BODY)
                  .lineHeight(22)
                  .fontColor(this.tip.includes('成功') ? this.themeColors.success : this.themeColors.danger)
                  .width('100%')
              }
            }

            AppCard({ variant: 'soft', spacing: SPACE_SM }) {
              Text('注册后会发生什么')
                .fontSize(TYPE_SECTION_TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.themeColors.textPrimary)

              Text('注册完成后会直接进入首页，账号初始化和数据处理会在后台自动完成。')
                .fontSize(TYPE_BODY)
                .lineHeight(22)
                .fontColor(this.themeColors.textSecondary)
                .width('100%')
            }

            Row({ space: 6 }) {
              Text('已有账号？')
                .fontSize(TYPE_BODY)
                .fontColor(this.themeColors.textSecondary)
              Text('立即登录')
                .fontSize(TYPE_BODY)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.themeColors.primary)
                .onClick(() => {
                  this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
                })
            }
          }
          .width('100%')
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: 32 })
        }
        .width('100%')
      }
      .align(Alignment.Top)
      .backgroundColor(this.themeColors.background)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }

  private async sendCode(): Promise<void> {
    const account = this.phone.trim();
    if (account === '') {
      this.tip = '请先输入手机号';
      return;
    }
    this.sending = true;
    const result: CodeResult = await authService.sendVerificationCode('phone', account);
    this.sending = false;
    if (!result.success) {
      this.tip = AppErrorService.fromMessage(result.message, '验证码发送失败');
      return;
    }
    this.tip = '验证码已发送，请注意查收';
  }

  private async registerAndSync(): Promise<void> {
    const account = this.phone.trim();
    if (account === '' || this.code.trim() === '') {
      this.tip = '请完整填写手机号和验证码';
      return;
    }
    this.registering = true;
    const result = await authService.register('phone', account, this.code);
    if (!result.success || !result.user) {
      this.registering = false;
      this.tip = AppErrorService.fromMessage(result.message, '注册失败，请稍后重试');
      return;
    }

    const refreshedUser = await authService.refreshUserFromServer();
    const activeUser = refreshedUser ? refreshedUser : result.user;
    this.currentAccountLabel = `手机号：${account}`;

    try {
      const localData: SyncDataSet = toSyncDataSet(db.exportData());
      const hasHistory = await cloudSyncService.hasCloudHistory();

      if (hasHistory) {
        const cloudData: SyncDataSet = await cloudSyncService.fetchCloudData();
        const mergedData: SyncDataSet = cloudSyncService.mergeData(localData, cloudData);
        await db.replaceAllData(mergedData.goals, mergedData.tasks);
        await cloudSyncService.uploadData(mergedData);
      } else {
        await cloudSyncService.uploadData(localData);
      }
    } catch (error) {
      logger.error('RegisterPage automatic sync failed', error as Object);
    }

    this.registering = false;
    this.tip = '注册成功';
    this.code = '';
    setTimeout(() => {
      this.getUIContext().getRouter().replaceUrl({
        url: 'pages/MainPage',
        params: { userId: activeUser.userId }
      });
    }, 100);
  }
}
