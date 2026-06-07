import { ThemeColors, LightTheme } from '../theme/AppTheme';
import {
  GoalRescheduleService,
  type GoalRescheduleContext,
  type GoalReschedulePreview,
  type GoalRescheduleReminderPreviewItem,
  type GoalRescheduleTaskPreviewItem
} from '../services/GoalRescheduleService';
import { DayEventType } from '../models/DayEvent';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppDialogActions } from '../ui/base/AppDialogActions';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SECTION_GAP, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_HERO_TITLE, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { Logger } from '../Utils/Logger';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';

const logger = Logger.create('GoalReschedulePage');
const DAY_MS: number = 24 * 60 * 60 * 1000;

type GoalRescheduleStep = 'setup' | 'preview' | 'confirm';
type GoalAdjustTargetType = 'task' | 'reminder';

interface GoalRescheduleRouteParams {
  goalId?: string;
}

@Entry
@Component
struct GoalReschedulePage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State pageData: GoalRescheduleContext | null = null;
  @State preview: GoalReschedulePreview | null = null;
  @State step: GoalRescheduleStep = 'setup';
  @State isLoading: boolean = true;
  @State isApplying: boolean = false;
  @State confirmChecked: boolean = false;
  @State nextStartDate: number = Date.now() + DAY_MS;
  @State previewRevision: number = 0;
  @State showAdjustDialog: boolean = false;
  @State adjustTargetType: GoalAdjustTargetType = 'task';
  @State adjustTargetId: string = '';
  @State adjustTargetTitle: string = '';
  @State adjustOriginalDate: number = Date.now();
  @State adjustSuggestedDate: number = Date.now();
  @State adjustSelectedDate: number = Date.now();
  @State adjustManualAdjusted: boolean = false;
  private goalId: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as GoalRescheduleRouteParams;
    if (params && params.goalId) {
      this.goalId = params.goalId;
      this.loadContext();
    } else {
      this.isLoading = false;
    }
  }

  private async loadContext(): Promise<void> {
    try {
      this.isLoading = true;
      const data = await GoalRescheduleService.loadContext(getContext(this), this.goalId);
      this.pageData = data;
      if (data.earliestPendingDate !== undefined) {
        this.nextStartDate = GoalRescheduleService.getSuggestedStartDate(data);
      }
    } catch (error) {
      logger.error('loadContext failed', error as Object);
    } finally {
      this.isLoading = false;
    }
  }

  private async generatePreview(): Promise<void> {
    if (!this.pageData) {
      return;
    }
    try {
      this.isLoading = true;
      const preview = await GoalRescheduleService.buildPreview(
        getContext(this),
        this.goalId,
        this.nextStartDate,
        true
      );
      this.preview = preview;
      this.previewRevision += 1;
      if (preview) {
        this.step = 'preview';
      }
    } catch (error) {
      logger.error('generatePreview failed', error as Object);
      void promptAction.showToast({ message: '生成预览失败，请稍后重试' });
    } finally {
      this.isLoading = false;
    }
  }

  private getCompletionRatioText(): string {
    if (!this.pageData) {
      return '--';
    }
    return `${this.pageData.completedTaskCount}/${this.pageData.totalTaskCount}`;
  }

  private getCompletionPercentText(): string {
    if (!this.pageData || this.pageData.totalTaskCount === 0) {
      return '0%';
    }
    const pct = Math.round((this.pageData.completedTaskCount / this.pageData.totalTaskCount) * 100);
    return `${pct}%`;
  }

  private formatDate(ts?: number): string {
    if (!ts) {
      return '--';
    }
    const d = new Date(ts);
    return `${d.getFullYear()}/${(d.getMonth() + 1).toString().padStart(2, '0')}/${d.getDate().toString().padStart(2, '0')}`;
  }

  private formatDateTime(ts?: number): string {
    if (!ts) {
      return '--';
    }
    const d = new Date(ts);
    const date = `${d.getFullYear()}/${(d.getMonth() + 1).toString().padStart(2, '0')}/${d.getDate().toString().padStart(2, '0')}`;
    const time = `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
    return `${date} ${time}`;
  }

  private showToast(message: string): void {
    promptAction.showToast({ message });
  }

  private getShiftSummaryText(): string {
    if (!this.preview) {
      return '';
    }
    if (this.preview.manualAdjustedTaskCount > 0 || this.preview.manualAdjustedReminderCount > 0) {
      const taskPart = this.preview.manualAdjustedTaskCount > 0 ? `${this.preview.manualAdjustedTaskCount} 个任务` : '';
      const joiner = this.preview.manualAdjustedTaskCount > 0 && this.preview.manualAdjustedReminderCount > 0 ? '、' : '';
      const reminderPart = this.preview.manualAdjustedReminderCount > 0 ? `${this.preview.manualAdjustedReminderCount} 个提醒` : '';
      return `系统已生成整体重排建议，你又手动调整了 ${taskPart}${joiner}${reminderPart}。最终会按你确认后的结果执行。`;
    }
    if (this.preview.offsetDays > 0) {
      return `本次会将 ${this.preview.movedTaskCount} 个任务整体后移 ${this.preview.offsetDays} 天。`;
    }
    if (this.preview.offsetDays < 0) {
      return `本次会将 ${this.preview.movedTaskCount} 个任务整体前移 ${Math.abs(this.preview.offsetDays)} 天。`;
    }
    return `本次不会改动任务日期，但会修正提醒与旧待办。`;
  }

  private getReminderTypeLabel(type: DayEventType): string {
    switch (type) {
      case DayEventType.PERIODIC:
        return '周期提醒';
      case DayEventType.HABIT:
        return '习惯提醒';
      case DayEventType.MILESTONE:
        return '里程碑';
      case DayEventType.COUNTDOWN:
        return '倒计时';
      case DayEventType.COUNTER:
        return '纪念日';
      default:
        return '提醒';
    }
  }

  private openTaskAdjustDialog(item: GoalRescheduleTaskPreviewItem): void {
    if (!item.adjustable || item.oldDate === undefined) {
      return;
    }
    this.adjustTargetType = 'task';
    this.adjustTargetId = item.id;
    this.adjustTargetTitle = item.title;
    this.adjustOriginalDate = item.oldDate;
    this.adjustSuggestedDate = item.systemSuggestedDate || item.newDate || item.oldDate;
    this.adjustSelectedDate = item.newDate || item.oldDate;
    this.adjustManualAdjusted = item.manualAdjusted;
    this.showAdjustDialog = true;
  }

  private openReminderAdjustDialog(item: GoalRescheduleReminderPreviewItem): void {
    if (!item.adjustable || item.oldDate === undefined) {
      return;
    }
    this.adjustTargetType = 'reminder';
    this.adjustTargetId = item.id;
    this.adjustTargetTitle = item.title;
    this.adjustOriginalDate = item.oldDate;
    this.adjustSuggestedDate = item.systemSuggestedDate || item.newDate || item.oldDate;
    this.adjustSelectedDate = item.newDate || item.oldDate;
    this.adjustManualAdjusted = item.manualAdjusted;
    this.showAdjustDialog = true;
  }

  private closeAdjustDialog(): void {
    this.showAdjustDialog = false;
  }

  private applyManualAdjustment(): void {
    if (!this.preview || !this.adjustTargetId) {
      return;
    }
    const updatedPreview = this.adjustTargetType === 'task'
      ? GoalRescheduleService.updateTaskPreviewDate(this.preview, this.adjustTargetId, this.adjustSelectedDate)
      : GoalRescheduleService.updateReminderPreviewDate(this.preview, this.adjustTargetId, this.adjustSelectedDate);
    this.preview = updatedPreview;
    this.previewRevision += 1;
    this.confirmChecked = false;
    this.showAdjustDialog = false;
  }

  private resetManualAdjustment(): void {
    if (!this.preview || !this.adjustTargetId) {
      return;
    }
    const updatedPreview = this.adjustTargetType === 'task'
      ? GoalRescheduleService.resetTaskPreviewDate(this.preview, this.adjustTargetId)
      : GoalRescheduleService.resetReminderPreviewDate(this.preview, this.adjustTargetId);
    this.preview = updatedPreview;
    this.previewRevision += 1;
    this.confirmChecked = false;
    this.showAdjustDialog = false;
  }

  private async applyReschedule(): Promise<void> {
    if (!this.preview) {
      return;
    }
    try {
      this.isApplying = true;
      const result = await GoalRescheduleService.applyPreview(getContext(this), this.preview);
      const reminderSuffix = result.reminderCount > 0 ? `，同步调整了 ${result.reminderCount} 个提醒` : '';
      const cleanupSuffix = result.cleanedAutoGeneratedTaskCount > 0
        ? `，清理了 ${result.cleanedAutoGeneratedTaskCount} 个旧提醒待办`
        : '';
      this.showToast(`已重排 ${result.taskCount} 个任务${reminderSuffix}${cleanupSuffix}`);
      router.back();
    } catch (error) {
      logger.error('applyReschedule failed', error as Object);
      this.showToast('应用目标重排失败，请稍后重试');
    } finally {
      this.isApplying = false;
    }
  }

  @Builder
  private HeroCard() {
    if (this.pageData?.goal) {
    AppCard({ variant: 'accent', spacing: SPACE_SM }) {
      Row() {
        AppStatusBadge({ text: '目标重排', tone: 'primary', iconName: 'goal' })
        AppStatusBadge({ text: '自动选择剩余任务', tone: 'neutral', iconName: 'task' })
      }
      .width('100%')

      Text(this.pageData.goal.title)
        .fontSize(TYPE_HERO_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      Text('保留已完成进度，重新安排这个目标的剩余计划。')
        .fontSize(TYPE_BODY)
        .lineHeight(22)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
    }
  }

  @Builder
  private SummaryCard() {
    if (this.pageData) {
    AppCard({ variant: 'base', spacing: SPACE_SM }) {
      Text('当前状态')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)

      Row() {
        this.MetricBlock('整体完成', this.getCompletionRatioText(), `完成率 ${this.getCompletionPercentText()}`)
        this.MetricBlock('剩余任务', `${this.pageData.remainingTaskCount}`, `可重排 ${this.pageData.schedulableTaskCount}`)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row() {
        this.MetricBlock('最早未完成日期', this.formatDate(this.pageData.earliestPendingDate), '系统会以它为原起点')
        this.MetricBlock('最近完成时间', this.formatDateTime(this.pageData.lastCompletedAt), '用于帮助判断是否已中断')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      if (this.pageData.unscheduledTaskCount > 0 || this.pageData.autoGeneratedTaskCount > 0) {
        Text(
          `${this.pageData.unscheduledTaskCount > 0 ? `${this.pageData.unscheduledTaskCount} 个未排期任务暂不参与本次重排` : ''}${
            this.pageData.unscheduledTaskCount > 0 && this.pageData.autoGeneratedTaskCount > 0 ? '，' : ''
          }${
            this.pageData.autoGeneratedTaskCount > 0 ? `${this.pageData.autoGeneratedTaskCount} 个自动提醒任务会在应用时清理旧待办，避免继续显示逾期` : ''
          }`
        )
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
      }
    }
    }
  }

  @Builder
  private MetricBlock(title: string, value: string, subtitle: string) {
    Column({ space: SPACE_XS }) {
      Text(title)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      Text(value)
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.primary)
        .width('100%')

      Text(subtitle)
        .fontSize(TYPE_CAPTION)
        .fontColor(this.themeColors.textMuted)
        .width('100%')
    }
    .width('48%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(this.themeColors.surfaceLight)
    .borderRadius(16)
  }

  @Builder
  private SetupCard() {
    AppCard({ variant: 'base', spacing: SPACE_SM }) {
      Text('新的开始日期')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)

      Text('选择新的起始日期，系统会自动把该目标下所有剩余任务按原间隔整体平移。')
        .fontSize(TYPE_BODY)
        .lineHeight(22)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      DatePicker({
        start: new Date(Date.now() - 365 * DAY_MS),
        end: new Date(Date.now() + 365 * DAY_MS),
        selected: new Date(this.nextStartDate)
      })
        .onChange((value: DatePickerResult) => {
          const date = new Date(value.year!, value.month!, value.day!);
          this.nextStartDate = date.getTime();
        })
        .width('100%')

      Text(`选定日期：${this.formatDate(this.nextStartDate)}`)
        .fontSize(TYPE_BODY)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
    }
  }

  @Builder
  private PreviewCard() {
    if (this.preview) {
      AppCard({ variant: 'base', spacing: SPACE_SM }) {
        Text('重排预览')
          .fontSize(TYPE_SECTION_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)

        Text(
          this.getShiftSummaryText()
        )
          .fontSize(TYPE_BODY)
          .lineHeight(22)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')

        Text(
          this.preview.syncReminders
            ? `共审阅 ${this.preview.totalReminderCount} 个提醒，其中 ${this.preview.affectedReminderCount} 个会同步调整`
            : '本次不会同步调整关联提醒'
        )
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.primary)
          .width('100%')

        Text(`本次共审阅 ${this.preview.affectedTaskCount} 个剩余任务，其中 ${this.preview.unchangedTaskCount} 个无需调整日期。`)
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')

        if (this.preview.manualAdjustedTaskCount > 0 || this.preview.manualAdjustedReminderCount > 0) {
          Text(`你已手动调整 ${this.preview.manualAdjustedTaskCount} 个任务、${this.preview.manualAdjustedReminderCount} 个提醒。`)
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.primary)
            .width('100%')
        }

        if (this.preview.taskMoves.length > 0) {
          Text(`原起点 ${this.formatDate(this.preview.taskMoves[0].oldDate)} -> 最终最早执行日期 ${this.formatDate(this.preview.newStartDate)}`)
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')
        }

        if (this.preview.cleanedAutoGeneratedTaskCount > 0) {
          Text(`会同步清理 ${this.preview.cleanedAutoGeneratedTaskCount} 个旧的自动提醒待办，避免重排后仍显示逾期。`)
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')
        }

        if (this.preview.unsupportedReminderCount > 0) {
          Text(`另有 ${this.preview.unsupportedReminderCount} 个复杂提醒保持原样。`)
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textMuted)
            .width('100%')
        }
      }

      AppCard({ variant: 'base', spacing: SPACE_SM }) {
        Text('提醒清单（全部）')
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .width('100%')

        if (this.preview.reminderPreviewItems.length === 0) {
          Text('当前目标下没有关联提醒。')
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textMuted)
            .width('100%')
        } else {
          ForEach(this.preview.reminderPreviewItems, (item: GoalRescheduleReminderPreviewItem) => {
            this.PreviewReminderRow(item)
          }, (item: GoalRescheduleReminderPreviewItem) => `${item.id}-${item.newDate || 0}-${item.status}-${item.manualAdjusted ? 'manual' : 'auto'}-${this.previewRevision}`)
        }
      }

      AppCard({ variant: 'base', spacing: SPACE_SM }) {
        Text('任务清单（全部）')
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .width('100%')

        ForEach(this.preview.taskPreviewItems, (item: GoalRescheduleTaskPreviewItem) => {
          this.PreviewTaskRow(item)
        }, (item: GoalRescheduleTaskPreviewItem) => `${item.id}-${item.newDate || 0}-${item.status}-${item.manualAdjusted ? 'manual' : 'auto'}-${this.previewRevision}`)
      }
    }
  }

  @Builder
  private PreviewTaskRow(item: GoalRescheduleTaskPreviewItem) {
    Column({ space: 4 }) {
      Row({ space: SPACE_SM }) {
        Text(item.title)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .layoutWeight(1)

        if (item.adjustable) {
          AppButton({
            text: item.manualAdjusted ? '已调整' : '调整',
            variant: item.manualAdjusted ? 'primary' : 'secondary',
            buttonSize: 'sm',
            tapAction: () => {
              this.openTaskAdjustDialog(item);
            }
          })
        }
      }
      .width('100%')

      if (item.oldDate !== undefined && item.newDate !== undefined && item.status === 'move') {
        Text(`${this.formatDate(item.oldDate)} -> ${this.formatDate(item.newDate)}${item.dueTime ? ` ${item.dueTime}` : ''}`)
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
      } else if (item.oldDate !== undefined) {
        Text(`${this.formatDate(item.oldDate)}${item.dueTime ? ` ${item.dueTime}` : ''}`)
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
      }

      Text(item.note)
        .fontSize(TYPE_CAPTION)
        .fontColor(item.status === 'cleanup' ? this.themeColors.warning : this.themeColors.textSecondary)
        .width('100%')
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({
      width: { bottom: 0.5 },
      color: this.themeColors.borderLight
    })
  }

  @Builder
  private PreviewReminderRow(item: GoalRescheduleReminderPreviewItem) {
    Column({ space: 4 }) {
      Row({ space: SPACE_SM }) {
        Text(item.title)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .layoutWeight(1)

        if (item.adjustable) {
          AppButton({
            text: item.manualAdjusted ? '已调整' : '调整',
            variant: item.manualAdjusted ? 'primary' : 'secondary',
            buttonSize: 'sm',
            tapAction: () => {
              this.openReminderAdjustDialog(item);
            }
          })
        }
      }
      .width('100%')

      Text(this.getReminderTypeLabel(item.type))
        .fontSize(TYPE_CAPTION)
        .fontColor(this.themeColors.primary)
        .width('100%')

      if (item.oldDate !== undefined && item.newDate !== undefined && item.status === 'move') {
        Text(`${this.formatDate(item.oldDate)} -> ${this.formatDate(item.newDate)}`)
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
      } else if (item.oldDate !== undefined) {
        Text(this.formatDate(item.oldDate))
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
      }

      Text(item.note)
        .fontSize(TYPE_CAPTION)
        .fontColor(item.status === 'move' ? this.themeColors.textSecondary : this.themeColors.textMuted)
        .width('100%')
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({
      width: { bottom: 0.5 },
      color: this.themeColors.borderLight
    })
  }

  @Builder
  private ConfirmCard() {
    AppCard({ variant: 'soft', spacing: SPACE_SM }) {
      Text('确认执行')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)

      Text('确认后系统会直接修改这些任务和提醒的日期，操作不可撤销。')
        .fontSize(TYPE_BODY)
        .lineHeight(22)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      if (this.preview && (this.preview.manualAdjustedTaskCount > 0 || this.preview.manualAdjustedReminderCount > 0)) {
        Text(`本次会按你的手动调整结果执行：${this.preview.manualAdjustedTaskCount} 个任务、${this.preview.manualAdjustedReminderCount} 个提醒已覆盖系统建议。`)
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.primary)
          .width('100%')
      }

      Row() {
        Checkbox()
          .select(this.confirmChecked)
          .onChange((value: boolean) => {
            this.confirmChecked = value;
          })
          .margin({ right: 8 })

        Text('我已知晓本次会直接修改原计划，且无法撤销')
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textPrimary)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding(12)
      .backgroundColor(this.themeColors.surfaceBase)
      .borderRadius(16)
    }
  }

  @Builder
  private FooterActions() {
    Column({ space: SPACE_SM }) {
      if (this.step === 'setup') {
        AppButton({
          text: '查看重排预览',
          variant: 'primary',
          buttonSize: 'lg',
          fullWidth: true,
          tapAction: () => {
            void this.generatePreview();
          }
        })
      } else if (this.step === 'preview') {
        AppButton({
          text: '确认并执行重排',
          variant: 'primary',
          buttonSize: 'lg',
          fullWidth: true,
          tapAction: () => {
            this.step = 'confirm';
          }
        })
        AppButton({
          text: '返回修改',
          variant: 'secondary',
          buttonSize: 'lg',
          fullWidth: true,
          tapAction: () => {
            this.step = 'setup';
          }
        })
      } else {
        AppButton({
          text: this.isApplying ? '正在应用...' : '确认执行',
          variant: 'primary',
          buttonSize: 'lg',
          fullWidth: true,
          disabled: !this.confirmChecked || this.isApplying,
          loading: this.isApplying,
          tapAction: () => {
            void this.applyReschedule();
          }
        })
        AppButton({
          text: '返回预览',
          variant: 'secondary',
          buttonSize: 'lg',
          fullWidth: true,
          tapAction: () => {
            this.step = 'preview';
          }
        })
      }
    }
    .width('100%')
  }

  @Builder
  private AdjustDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeColors.surfaceOverlay)
        .onClick(() => {
          this.closeAdjustDialog();
        })

      Column({ space: SPACE_SM }) {
        Text(this.adjustTargetType === 'task' ? '调整任务日期' : '调整提醒日期')
          .fontSize(TYPE_SECTION_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .width('100%')

        Text(this.adjustTargetTitle)
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textPrimary)
          .width('100%')

        Text(`原日期：${this.formatDate(this.adjustOriginalDate)}，系统建议：${this.formatDate(this.adjustSuggestedDate)}`)
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')

        Text('保存后会直接覆盖当前预览中的系统建议。')
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textMuted)
          .width('100%')

        DatePicker({
          start: new Date(Date.now() - 365 * DAY_MS),
          end: new Date(Date.now() + 365 * DAY_MS),
          selected: new Date(this.adjustSelectedDate)
        })
          .onChange((value: DatePickerResult) => {
            const date = new Date(value.year!, value.month!, value.day!);
            this.adjustSelectedDate = date.getTime();
          })
          .width('100%')

        Text(`当前选择：${this.formatDate(this.adjustSelectedDate)}`)
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textPrimary)
          .width('100%')

        if (this.adjustManualAdjusted) {
          AppButton({
            text: '恢复系统建议',
            variant: 'secondary',
            buttonSize: 'sm',
            fullWidth: true,
            tapAction: () => {
              this.resetManualAdjustment();
            }
          })
        }

        AppDialogActions({
          primaryText: '保存调整',
          onSecondary: () => {
            this.closeAdjustDialog();
          },
          onPrimary: () => {
            this.applyManualAdjustment();
          }
        })
      }
      .width('88%')
      .padding(SPACE_MD)
      .backgroundColor(this.themeColors.cardBackground)
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
      AppPageHeader({ title: this.pageData?.goal?.title || '目标重排', showBack: true })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(this.themeColors.primary)
          Text('加载目标数据中...')
            .fontSize(TYPE_BODY)
            .fontColor(this.themeColors.textSecondary)
            .margin({ top: SPACE_MD })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (!this.pageData || !this.pageData.goal) {
        Scroll() {
          Column() {
            AppEmptyState({
              iconName: 'warning',
              iconTone: 'warning',
              title: '无法加载目标信息',
              description: '请确认目标是否存在，或返回重试。'
            })
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING })
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: SECTION_GAP }) {
            this.HeroCard()
            this.SummaryCard()

            if (this.step === 'setup') {
              this.SetupCard()
            } else {
              this.PreviewCard()
              if (this.step === 'confirm') {
                this.ConfirmCard()
              }
            }

            this.FooterActions()
            Blank().height(8)
          }
          .width('100%')
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: SPACE_MD, bottom: SPACE_MD })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeColors.background)

      if (this.showAdjustDialog) {
        this.AdjustDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}
