import type { Goal } from '../models/Goal';
import { db } from '../storage/Database';
import { authService, UserAccount } from '../services/AuthService';
import { themeService } from '../services/ThemeService';
import { ThemeMode, ThemeColors, LightTheme } from '../theme/AppTheme';
import { QuotaService, QuotaResult } from '../services/QuotaService';
import { DataExportService, DataExportResult } from '../services/DataExportService';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppChip } from '../ui/base/AppChip';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppListRow } from '../ui/base/AppListRow';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SECTION_GAP, SPACE_SM, SPACE_MD, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { COMFORTABLE_PAGE_PADDING, COMFORTABLE_SECTION_GAP } from '../foundation/tokens/PageTierTokens';

@Entry
@Component
struct UserPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @StorageLink('themeMode') currentThemeMode: ThemeMode = ThemeMode.SYSTEM;
  @State user: UserAccount | null = null;
  @State showAvatarPicker: boolean = false;
  @State showNicknamePicker: boolean = false;
  @State selectedNickname: string = '用户';
  @State aiTaskQuota: QuotaResult = { allowed: true, remaining: 20, limit: 20 };
  @State goalBreakdownQuota: QuotaResult = { allowed: true, remaining: 3, limit: 3 };
  @State todayPlanQuota: QuotaResult = { allowed: true, remaining: 5, limit: 5 };
  @State rescheduleQuota: QuotaResult = { allowed: true, remaining: 5, limit: 5 };
  @State voiceQuota: QuotaResult = { allowed: true, remaining: 0, limit: 0 };
  @State archivedGoalCount: number = 0;
  @State exportInProgress: boolean = false;

  private avatars: string[] = [
    'https://img.icons8.com/color/96/000000/user.png',
    'https://img.icons8.com/color/96/000000/user-group.png',
    'https://img.icons8.com/color/96/000000/robot.png',
    'https://img.icons8.com/color/96/000000/panda.png',
    'https://img.icons8.com/color/96/000000/cat.png',
    'https://img.icons8.com/color/96/000000/dog.png'
  ];

  private nicknames: string[] = ['用户', '达人', '先锋', '领航', '探索者', '追梦人', '奋斗者', '进取者'];

  aboutToAppear(): void {
    const context = (this.getUIContext().getHostContext() as Context);
    Promise.all([
      db.initialize(context),
      authService.initialize(context),
      themeService.initialize(context)
    ]).then(() => {
      this.loadUser();
      this.loadThemeMode();
      this.loadArchivedGoalsCount();
      this.loadQuotaData();
    });
  }

  onPageShow(): void {
    this.loadUser();
    this.loadThemeMode();
    this.loadArchivedGoalsCount();
    this.loadQuotaData();
  }

  private loadArchivedGoalsCount(): void {
    const goals: Goal[] = db.getAllGoals();
    this.archivedGoalCount = goals.filter((goal: Goal) => goal.isArchived).length;
  }

  private loadThemeMode(): void {
    this.currentThemeMode = themeService.getThemeMode();
  }

  private loadUser(): void {
    authService.getCurrentUser().then((user) => {
      this.user = user;
      if (user) {
        this.selectedNickname = user.nickname || user.account;
        authService.refreshUserFromServer().then((serverUser) => {
          if (serverUser) {
            this.user = serverUser;
            this.selectedNickname = serverUser.nickname || serverUser.account;
            this.loadQuotaData();
          }
        });
      }
    });
  }

  private loadQuotaData(): void {
    const context = (this.getUIContext().getHostContext() as Context);
    const refreshLocalValues = () => {
      QuotaService.checkAITaskQuota(context).then((result: QuotaResult) => {
        this.aiTaskQuota = result;
      });
      QuotaService.checkGoalBreakdownQuota(context).then((result: QuotaResult) => {
        this.goalBreakdownQuota = result;
      });
      QuotaService.checkTodayPlanQuota(context).then((result: QuotaResult) => {
        this.todayPlanQuota = result;
      });
      QuotaService.checkRescheduleQuota(context).then((result: QuotaResult) => {
        this.rescheduleQuota = result;
      });
      QuotaService.checkVoiceQuota(context).then((result: QuotaResult) => {
        this.voiceQuota = result;
      });
    };

    refreshLocalValues();
    QuotaService.syncWithCloud(context).then(() => {
      refreshLocalValues();
    });
  }

  private isPremiumActive(): boolean {
    return authService.isPremiumUser(this.user);
  }

  private getDisplayName(): string {
    return this.user?.nickname || this.user?.account || '用户';
  }

  private getDisplayId(): string {
    return this.user?.displayId || this.user?.userId || '--';
  }

  private getMembershipTitle(): string {
    if (!this.isPremiumActive()) {
      return '免费版';
    }
    if (this.user?.membershipProductId === 'vip_yearly_continuous' ||
      this.user?.membershipPlan === 'yearly_continuous') {
      return '已开通连续包年';
    }
    if (this.user?.membershipProductId === 'vip_monthly_continuous' ||
      this.user?.membershipPlan === 'monthly_continuous') {
      return '已开通连续包月';
    }
    return '高级会员';
  }

  private getMembershipDescription(): string {
    const renewAt = this.user?.membershipRenewAt || this.user?.membershipExpireAt || 0;
    if (this.isPremiumActive() && renewAt) {
      return `自动续费时间 ${new Date(renewAt).toLocaleDateString()}`;
    }
    return '开通后可获得更高 AI 配额、语音能力和更完整的数据统计。';
  }

  private getQuotaDisplayValue(quota: QuotaResult, treatAsMinutes: boolean = false): string {
    if (quota.limit > 9999) {
      return treatAsMinutes ? `已用 ${this.formatVoiceMinutes(quota.limit - quota.remaining)} 分钟` : `已用 ${quota.limit - quota.remaining}`;
    }
    if (treatAsMinutes) {
      return `${this.formatVoiceMinutes(quota.remaining)} / ${this.formatVoiceMinutes(quota.limit)} 分钟`;
    }
    return `${quota.remaining} / ${quota.limit}`;
  }

  private formatVoiceMinutes(seconds: number): string {
    const minutes = Math.floor(Math.max(0, seconds) / 60);
    return `${minutes}`;
  }

  private async switchTheme(mode: ThemeMode): Promise<void> {
    if (this.currentThemeMode === mode) {
      return;
    }
    this.currentThemeMode = mode;
    await themeService.setThemeMode(mode);
  }

  private isThemeSelected(mode: ThemeMode): boolean {
    return this.currentThemeMode === mode;
  }

  private openLoginPage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
  }

  private openMembershipPage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/MembershipPage' });
  }

  private openArchivedGoals(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchivedGoalsPage' });
  }

  private openHelpPage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/HelpPage' });
  }

  private openAboutPage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/AboutPage' });
  }

  private openAccountDeletionPage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/AccountDeletionPage' });
  }

  private async handleExportData(): Promise<void> {
    if (this.exportInProgress) {
      return;
    }
    this.exportInProgress = true;
    try {
      const result: DataExportResult = await DataExportService.export();
      if (result.status === 'success' && result.summary) {
        const summary = result.summary;
        this.getUIContext().getPromptAction().showToast({
          message: `导出成功：目标 ${summary.goals}、任务 ${summary.tasks}、提醒 ${summary.dayEvents}、专注 ${summary.pomodoros}`,
          duration: 4000
        });
      } else if (result.status === 'cancelled') {
        this.getUIContext().getPromptAction().showToast({ message: '已取消导出' });
      } else {
        this.getUIContext().getPromptAction().showToast({ message: result.message || '导出失败，请稍后重试' });
      }
    } finally {
      this.exportInProgress = false;
    }
  }

  private handleLogout(): void {
    authService.logout().then(() => {
      this.user = null;
      this.getUIContext().getRouter().back();
    });
  }

  private openAvatarPicker(): void {
    this.showAvatarPicker = true;
  }

  private showNicknameEditor(): void {
    this.showNicknamePicker = true;
  }

  private updateAvatar(avatar: string): void {
    authService.updateAvatar(avatar).then((user) => {
      if (user) {
        this.user = user;
        this.selectedNickname = user.nickname || this.selectedNickname;
        this.getUIContext().getPromptAction().showToast({ message: '头像已更新' });
      } else {
        this.getUIContext().getPromptAction().showToast({ message: '头像更新失败，请稍后重试' });
      }
    });
  }

  private updateNickname(nickname: string): void {
    authService.updateNickname(nickname).then((user) => {
      if (user) {
        this.user = user;
        this.selectedNickname = user.nickname || nickname;
        this.getUIContext().getPromptAction().showToast({ message: '昵称已更新' });
      } else {
        this.getUIContext().getPromptAction().showToast({ message: '昵称更新失败，请稍后重试' });
      }
    });
  }

  @Builder
  private ProfileCard() {
    AppCard({ spacing: 10, paddingLevel: 'md' }) {
      Row({ space: 10 }) {
        if (this.user?.avatar) {
          Image(this.user.avatar)
            .width(60)
            .height(60)
            .borderRadius(30)
            .backgroundColor(this.themeColors.surfaceSoft)
            .onClick(() => {
              this.openAvatarPicker();
            })
        } else {
          Image($r('app.media.startIcon'))
            .width(60)
            .height(60)
            .borderRadius(30)
            .backgroundColor(this.themeColors.surfaceSoft)
            .onClick(() => {
              this.openAvatarPicker();
            })
        }

        Column({ space: 6 }) {
          Row({ space: 10 }) {
            Text(this.getDisplayName())
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.isPremiumActive()) {
              AppStatusBadge({ text: '会员中', tone: 'premium', iconName: 'wallet' })
            } else {
              AppStatusBadge({ text: '基础版', tone: 'warning', iconName: 'warning' })
            }
          }
          .width('100%')

          Text(`ID: ${this.getDisplayId()}`)
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textMuted)
            .width('100%')

          Row({ space: 10 }) {
            AppButton({
              text: '换头像',
              variant: 'secondary',
              buttonSize: 'sm',
              iconName: 'profile',
              tapAction: () => { this.openAvatarPicker(); }
            })
            AppButton({
              text: '改昵称',
              variant: 'secondary',
              buttonSize: 'sm',
              iconName: 'note',
              tapAction: () => { this.showNicknameEditor(); }
            })
          }
          .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
  }

  @Builder
  private MembershipCard() {
    AppCard({ variant: this.isPremiumActive() ? 'premium' : 'soft', spacing: 10, paddingLevel: 'md' }) {
      Row() {
        Column({ space: 8 }) {
          Text(this.getMembershipTitle())
            .fontSize(TYPE_SECTION_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isPremiumActive() ? this.themeColors.premiumText : this.themeColors.textPrimary)
            .width('100%')
          Text(this.getMembershipDescription())
            .fontSize(TYPE_BODY)
            .lineHeight(18)
            .fontColor(this.isPremiumActive() ? this.themeColors.premiumText : this.themeColors.textSecondary)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        AppButton({
          text: this.isPremiumActive() ? '续费' : '开通',
          variant: this.isPremiumActive() ? 'premium' : 'primary',
          buttonSize: 'sm',
          iconName: 'wallet',
          tapAction: () => { this.openMembershipPage(); }
        })
      }
      .width('100%')

      Column({ space: 8 }) {
        this.QuotaRow('AI 创建任务', this.getQuotaDisplayValue(this.aiTaskQuota), this.isPremiumActive() ? '当前周期已用 / 总额度' : '当前剩余 / 月度总额')
        this.QuotaRow('目标拆解', this.getQuotaDisplayValue(this.goalBreakdownQuota), 'AI 目标规划与拆解配额')
        this.QuotaRow('今日计划', this.getQuotaDisplayValue(this.todayPlanQuota), '云端今日计划的剩余调用次数')
        this.QuotaRow('智能改期', this.getQuotaDisplayValue(this.rescheduleQuota), '一键重排与改期能力')
        this.QuotaRow('语音时长', this.getQuotaDisplayValue(this.voiceQuota, true), '语音识别与分析剩余额度')
      }
      .width('100%')
    }
  }

  @Builder
  private QuotaRow(title: string, value: string, hint: string) {
    Column({ space: 4 }) {
      Row() {
        Text(title)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
        Blank()
        Text(value)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.primary)
      }
      .width('100%')

      Text(hint)
        .fontSize(TYPE_META)
        .lineHeight(16)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(8)
    .backgroundColor(this.themeColors.surfaceLight)
    .borderRadius(12)
  }

  @Builder
  private ThemeCard() {
    AppCard({ spacing: 10, paddingLevel: 'md' }) {
      Text('主题偏好')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
      Text('浅色、深色和跟随系统都按统一主题 token 渲染。')
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      Row({ space: 8 }) {
        AppChip({
          label: '浅色',
          active: this.isThemeSelected(ThemeMode.LIGHT),
          tone: 'primary',
          iconName: 'today',
          tapAction: () => { void this.switchTheme(ThemeMode.LIGHT); }
        })
        AppChip({
          label: '深色',
          active: this.isThemeSelected(ThemeMode.DARK),
          tone: 'primary',
          iconName: 'focus',
          tapAction: () => { void this.switchTheme(ThemeMode.DARK); }
        })
        AppChip({
          label: '跟随系统',
          active: this.isThemeSelected(ThemeMode.SYSTEM),
          tone: 'primary',
          iconName: 'gear',
          tapAction: () => { void this.switchTheme(ThemeMode.SYSTEM); }
        })
      }
      .width('100%')
    }
  }

  @Builder
  private DataCard() {
    AppCard({ spacing: 0, paddingLevel: 'md' }) {
      Text('数据与更多')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
        .margin({ bottom: 8 })

      AppListRow({
        leadingIcon: 'archive',
        title: '已归档目标',
        subtitle: '回看已完成或暂时下线的目标',
        trailingText: `${this.archivedGoalCount} 个`,
        showDivider: true,
        tapAction: () => { this.openArchivedGoals(); }
      })
      AppListRow({
        leadingIcon: 'help',
        title: '帮助中心',
        subtitle: '查看使用说明和常见问题',
        trailingText: '说明',
        showDivider: true,
        tapAction: () => { this.openHelpPage(); }
      })
      AppListRow({
        leadingIcon: 'info',
        title: '关于我们',
        subtitle: '查看应用信息与恢复进度',
        trailingText: '详情',
        showDivider: false,
        tapAction: () => { this.openAboutPage(); }
      })
    }
  }

  @Builder
  private PrivacyCard() {
    AppCard({ spacing: 0, paddingLevel: 'md' }) {
      Text('账号与隐私')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
        .margin({ bottom: 8 })

      AppListRow({
        leadingIcon: 'archive',
        title: '导出我的数据',
        subtitle: '把目标、任务、提醒、专注记录导出为 JSON 文件',
        trailingText: this.exportInProgress ? '导出中' : '导出',
        showDivider: true,
        tapAction: () => { this.handleExportData(); }
      })
      AppListRow({
        leadingIcon: 'warning',
        title: '注销账号',
        subtitle: '提交注销申请，账号与业务数据将按隐私政策处理',
        trailingText: '前往',
        tone: 'danger',
        showDivider: false,
        tapAction: () => { this.openAccountDeletionPage(); }
      })
    }
  }

  @Builder
  private LoggedView() {
    Column({ space: COMFORTABLE_SECTION_GAP }) {
      this.ProfileCard()
      this.MembershipCard()
      this.ThemeCard()
      this.DataCard()
      this.PrivacyCard()

      Row() {
        AppButton({
          text: '退出登录',
          variant: 'danger',
          iconName: 'warning',
          tapAction: () => { this.handleLogout(); }
        })
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private NotLoggedInView() {
    Column({ space: COMFORTABLE_SECTION_GAP }) {
      AppEmptyState({
        iconName: 'profile',
        iconTone: 'info',
        title: '当前未登录',
        description: '登录后即可管理账户资料、会员权益、主题偏好和完整设置。',
        actionText: '前往登录',
        actionIconName: 'profile',
        onAction: () => { this.openLoginPage(); }
      })
      this.ThemeCard()
      this.DataCard()
    }
    .width('100%')
  }

  @Builder
  private AvatarOption(url: string, name: string, index: number) {
    Column({ space: SPACE_XS }) {
      Image(url)
        .width(52)
        .height(52)
        .borderRadius(26)
        .onClick(() => {
          this.updateAvatar(this.avatars[index]);
          this.showAvatarPicker = false;
        })
      Text(name)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
    }
    .width('30%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private AvatarPickerDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeColors.surfaceOverlay)
        .onClick(() => {
          this.showAvatarPicker = false;
        })

      Column() {
        AppCard({ spacing: 14 }) {
          Text('选择头像')
            .fontSize(TYPE_SECTION_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')

          Column({ space: SPACE_MD }) {
            Row() {
              this.AvatarOption(this.avatars[0], '默认', 0)
              this.AvatarOption(this.avatars[1], '群组', 1)
              this.AvatarOption(this.avatars[2], '机器人', 2)
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            Row() {
              this.AvatarOption(this.avatars[3], '熊猫', 3)
              this.AvatarOption(this.avatars[4], '猫咪', 4)
              this.AvatarOption(this.avatars[5], '狗狗', 5)
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
          }
          .width('100%')

          Row() {
            AppButton({
              text: '取消',
              variant: 'secondary',
              iconName: 'chevron-left',
              tapAction: () => {
                this.showAvatarPicker = false;
              }
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
        }
      }
      .width('88%')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private NicknamePickerDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeColors.surfaceOverlay)
        .onClick(() => {
          this.showNicknamePicker = false;
        })

      Column() {
        AppCard({ spacing: 14 }) {
          Text('选择昵称')
            .fontSize(TYPE_SECTION_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')

          Scroll() {
            Column({ space: SPACE_XS }) {
              ForEach(this.nicknames, (name: string) => {
                Row() {
                  Text(name)
                    .fontSize(TYPE_BODY)
                    .fontWeight(this.selectedNickname === name ? FontWeight.Medium : FontWeight.Normal)
                    .fontColor(this.selectedNickname === name ? this.themeColors.primary : this.themeColors.textPrimary)
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 12, bottom: 12 })
                .backgroundColor(this.selectedNickname === name ? this.themeColors.primarySubtle : this.themeColors.surfaceLight)
                .borderRadius(14)
                .onClick(() => {
                  this.updateNickname(name);
                  this.showNicknamePicker = false;
                })
              }, (name: string) => name)
            }
            .width('100%')
          }
          .align(Alignment.Top)
          .constraintSize({ maxHeight: 248 })
          .scrollBar(BarState.Off)
          .width('100%')

          Row() {
            AppButton({
              text: '取消',
              variant: 'secondary',
              iconName: 'chevron-left',
              tapAction: () => {
                this.showNicknamePicker = false;
              }
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
        }
      }
      .width('88%')
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      Column() {
        AppPageHeader({
          title: '个人中心',
          subtitle: '账户、权益、主题和帮助入口的统一管理中心',
          onBack: () => {
            this.getUIContext().getRouter().back();
          }
        })

        Scroll() {
          Column({ space: COMFORTABLE_SECTION_GAP }) {
            if (this.user) {
              this.LoggedView()
            } else {
              this.NotLoggedInView()
            }
          }
          .width('100%')
          .padding({ left: COMFORTABLE_PAGE_PADDING, right: COMFORTABLE_PAGE_PADDING, bottom: COMFORTABLE_PAGE_PADDING + 16 })
        }
        .align(Alignment.Top)
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeColors.background)

      if (this.showAvatarPicker) {
        this.AvatarPickerDialog()
      }

      if (this.showNicknamePicker) {
        this.NicknamePickerDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
