import { Goal, GoalCategory } from '../models/Goal';
import { Task, TaskStatus } from '../models/Task';
import { db } from '../storage/Database';
import { ThemeMode, ThemeColors, LightTheme } from '../theme/AppTheme';
import { CATEGORY_COLORS } from '../common/Constants';
import { themeService } from '../services/ThemeService';
import { dataSyncService } from '../services/DataSyncService';
import window from '@ohos.window';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppFormCard } from '../ui/base/AppFormCard';
import { AppIcon } from '../ui/base/AppIcon';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppPanelSection } from '../ui/base/AppPanelSection';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { SPACE_LG, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { COMFORTABLE_PAGE_PADDING, COMFORTABLE_SECTION_GAP } from '../foundation/tokens/PageTierTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_META } from '../foundation/tokens/TypographyTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('EditGoalPage');

@Entry
@Component
struct EditGoalPage {
  @State themeMode: ThemeMode = ThemeMode.SYSTEM;
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State goalId: string = '';
  @State category: GoalCategory = GoalCategory.HEALTH;
  @State categoryTitle: string = '';
  @State categoryColor: string = CATEGORY_COLORS[GoalCategory.HEALTH];
  @State goalTitle: string = '';
  @State goalDescription: string = '';
  @State isPriority: boolean = false;
  @State isSaving: boolean = false;
  @State currentGoal: Goal | null = null;
  @State relatedTasks: Task[] = [];

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch (_) {
    }
  }

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as Record<string, string | GoalCategory | boolean>;
    if (params) {
      this.goalId = params['goalId'] as string || '';
      this.category = (params['category'] as GoalCategory) || GoalCategory.HEALTH;
      this.categoryTitle = (params['categoryTitle'] as string) || this.category;
      this.categoryColor = (params['categoryColor'] as string) || CATEGORY_COLORS[GoalCategory.HEALTH];
      this.goalTitle = (params['goalTitle'] as string) || '';
      this.goalDescription = (params['goalDescription'] as string) || '';
      this.isPriority = (params['isPriority'] as boolean) || false;
    }
    this.loadGoalData();

    const context = this.getUIContext().getHostContext() as Context;
    themeService.initialize(context).then(() => {
      this.themeMode = themeService.getThemeMode();
      this.applyWindowTheme();
    });
  }

  onPageShow(): void {
    this.loadGoalData();
    this.themeMode = themeService.getThemeMode();
    this.applyWindowTheme();
  }

  private loadGoalData(): void {
    const goal = db.getGoalById(this.goalId);
    this.currentGoal = goal || null;
    this.relatedTasks = this.goalId ? db.getTasksByGoalId(this.goalId) : [];

    if (goal) {
      this.category = goal.category;
      this.categoryTitle = goal.category;
      this.goalTitle = goal.title;
      this.goalDescription = goal.description || '';
      this.isPriority = goal.isPriority || false;
    }
  }

  private getCompletedTaskCount(): number {
    return this.relatedTasks.filter((task: Task) => task.status === TaskStatus.COMPLETED).length;
  }

  private getCompletedKeyResultCount(): number {
    if (!this.currentGoal) {
      return 0;
    }
    return this.currentGoal.keyResults.filter((kr) => kr.completed || kr.progress >= 100).length;
  }

  private areAllKeyResultsCompleted(): boolean {
    if (!this.currentGoal) {
      return false;
    }
    return this.currentGoal.keyResults.every((kr) => kr.completed || kr.progress >= 100);
  }

  private areAllTasksCompleted(): boolean {
    return this.relatedTasks.every((task: Task) => task.status === TaskStatus.COMPLETED);
  }

  private canArchiveGoal(): boolean {
    if (!this.currentGoal || this.currentGoal.isArchived) {
      return false;
    }
    return this.areAllKeyResultsCompleted() && this.areAllTasksCompleted();
  }

  private showArchiveDialog(): void {
    if (this.currentGoal?.isArchived) {
      return;
    }
    if (!this.canArchiveGoal()) {
      this.showToast('请先完成全部关键结果和关联任务，再归档目标');
      return;
    }

    this.getUIContext().showAlertDialog({
      title: '归档目标',
      message: '归档后目标会从首页和执行列表移除，仅保留在归档列表中查看。',
      buttons: [
        {
          value: '取消',
          action: () => {}
        },
        {
          value: '确认归档',
          action: () => {
            void this.archiveGoal();
          }
        }
      ]
    });
  }

  private async archiveGoal(): Promise<void> {
    const goal = db.getGoalById(this.goalId);
    if (!goal) {
      return;
    }

    goal.isArchived = true;
    goal.archivedAt = Date.now();
    goal.updatedAt = Date.now();

    const currentGoals = dataSyncService.getGoals();
    const updatedGoals = currentGoals.map((item: Goal) => item.id === goal.id ? goal : item);
    dataSyncService.setGoals(updatedGoals);

    await db.updateGoal(goal);
    this.showToast('目标已归档');
    this.getUIContext().getRouter().replaceUrl({ url: 'pages/MainPage' });
  }

  private showDeleteDialog(): void {
    this.getUIContext().showAlertDialog({
      title: '删除目标',
      message: '删除后会一并清理该目标下的关键结果、任务和关联专注记录，且无法恢复。',
      buttons: [
        {
          value: '取消',
          action: () => {}
        },
        {
          value: '确认删除',
          action: () => {
            void this.deleteGoalForever();
          }
        }
      ]
    });
  }

  private async deleteGoalForever(): Promise<void> {
    const updatedGoals = dataSyncService.getGoals().filter((goal: Goal) => goal.id !== this.goalId);
    const updatedTasks = dataSyncService.getTasks().filter((task: Task) => task.goalId !== this.goalId);
    dataSyncService.setGoals(updatedGoals);
    dataSyncService.setTasks(updatedTasks);

    await db.deleteGoal(this.goalId);
    this.showToast('目标已删除');
    this.getUIContext().getRouter().replaceUrl({ url: 'pages/MainPage' });
  }

  private applyWindowTheme(): void {
    try {
      window.getLastWindow(this.getUIContext().getHostContext() as Context).then((windowClass) => {
        try {
          windowClass.setWindowBackgroundColor(this.themeColors.background);
          const sysBarProps: window.SystemBarProperties = {
            statusBarColor: this.themeColors.background,
            navigationBarColor: this.themeColors.background,
            statusBarContentColor: this.themeColors.textPrimary,
            navigationBarContentColor: this.themeColors.textPrimary
          };
          windowClass.setWindowSystemBarProperties(sysBarProps);
        } catch (err) {
        }
      });
    } catch (err) {
    }
  }

  private async saveGoal(): Promise<void> {
    if (!this.goalTitle.trim() || this.currentGoal?.isArchived) {
      return;
    }

    this.isSaving = true;
    try {
      const context = this.getUIContext().getHostContext() as Context;
      await db.initialize(context);

      const existingGoal = await db.getGoalById(this.goalId);
      if (existingGoal) {
        existingGoal.title = this.goalTitle.trim();
        existingGoal.description = this.goalDescription.trim();
        existingGoal.isPriority = this.isPriority;
        existingGoal.updatedAt = Date.now();

        try {
          dataSyncService.updateGoal(existingGoal);
        } catch (error) {
          logger.error('EditGoalPage saveGoal updateGoal failed', error as Object);
        }

        await db.updateGoal(existingGoal);
        this.currentGoal = existingGoal;
      }

      this.getUIContext().getRouter().back();
    } catch (error) {
      logger.error('更新目标失败', error as Object);
      this.getUIContext().getRouter().back();
    } finally {
      this.isSaving = false;
    }
  }

  @Builder
  private ActionRow(title: string, description: string, tone: 'primary' | 'danger', enabled: boolean, onTap: () => void) {
    AppCard({
      variant: tone === 'danger' ? 'danger' : 'soft',
      spacing: SPACE_XS,
      paddingLevel: 'md',
      interactive: true,
      tapAction: () => {
        if (enabled) {
          onTap();
        }
      }
    }) {
      Row({ space: SPACE_SM }) {
        Column({ space: 4 }) {
          Text(title)
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(enabled ? this.themeColors.textPrimary : this.themeColors.textMuted)
            .width('100%')

          Text(description)
            .fontSize(TYPE_META)
            .lineHeight(18)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        AppIcon({
          name: 'chevron-right',
          iconSize: TYPE_BODY,
          framed: false,
          color: tone === 'danger' ? this.themeColors.danger : this.themeColors.primary
        })
      }
      .width('100%')
    }
  }

  @Builder
  private MoreActionSection() {
    AppPanelSection({
      title: '更多操作',
      subtitle: this.currentGoal?.isArchived
        ? '该目标已归档，仍可查看并执行删除操作。'
        : `关键结果完成 ${this.getCompletedKeyResultCount()}/${this.currentGoal?.keyResults.length || 0} · 任务完成 ${this.getCompletedTaskCount()}/${this.relatedTasks.length}`
    }) {
      Column({ space: SPACE_SM }) {
        this.ActionRow(
          '归档目标',
          this.currentGoal?.isArchived ? '当前目标已经归档。' : '仅当全部关键结果和关联任务都完成时可归档。',
          'primary',
          !this.currentGoal?.isArchived,
          () => {
            this.showArchiveDialog();
          }
        )

        this.ActionRow(
          '删除目标',
          '会同时清理该目标下的关键结果、任务和关联专注记录。',
          'danger',
          true,
          () => {
            this.showDeleteDialog();
          }
        )
      }
      .width('100%')
    }
  }

  build() {
    Column({ space: SPACE_MD }) {
      AppPageHeader({
        title: '编辑目标',
        subtitle: '调整标题、说明和优先级，不改变现有功能',
        insetHorizontal: COMFORTABLE_PAGE_PADDING,
        onBack: () => {
          this.getUIContext().getRouter().back();
        }
      })

      Scroll() {
        Column({ space: COMFORTABLE_SECTION_GAP }) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            Text(this.categoryTitle)
              .fontSize(TYPE_CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeColors.textOnPrimary)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(this.categoryColor)
              .borderRadius(999)

            if (this.isPriority) {
              AppStatusBadge({ text: '优先目标', tone: 'warning', iconName: 'warning' })
            }

            if (this.currentGoal?.isArchived) {
              AppStatusBadge({ text: '已归档', tone: 'neutral', iconName: 'archive' })
            }
          }
          .width('100%')

          AppFormCard({ spacing: SPACE_MD, paddingLevel: 'md' }) {
            Column({ space: SPACE_XS }) {
              Text('目标名称')
                .fontSize(TYPE_BODY)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.themeColors.textPrimary)

              TextInput({
                placeholder: '请输入目标名称',
                text: this.goalTitle
              })
                .width('100%')
                .height(44)
                .backgroundColor(this.themeColors.inputBackground)
                .borderRadius(14)
                .padding({ left: 12, right: 12 })
                .fontColor(this.themeColors.textPrimary)
                .placeholderColor(this.themeColors.textMuted)
                .onChange((value: string) => {
                  this.goalTitle = value;
                })
            }
            .width('100%')

            Column({ space: SPACE_XS }) {
              Text('目标说明')
                .fontSize(TYPE_BODY)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.themeColors.textPrimary)

              TextArea({
                placeholder: '补充说明、约束或计划重点',
                text: this.goalDescription
              })
                .width('100%')
                .height(96)
                .backgroundColor(this.themeColors.inputBackground)
                .borderRadius(14)
                .padding(12)
                .fontColor(this.themeColors.textPrimary)
                .placeholderColor(this.themeColors.textMuted)
                .onChange((value: string) => {
                  this.goalDescription = value;
                })
            }
            .width('100%')
          }

          AppCard({ variant: 'soft', spacing: SPACE_MD, paddingLevel: 'md' }) {
            Row({ space: SPACE_SM }) {
              Column({ space: 4 }) {
                Text('设为优先目标')
                  .fontSize(TYPE_BODY)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.themeColors.textPrimary)
                  .width('100%')

                Text('优先目标会在首页、今日计划和任务推荐中更靠前显示。')
                  .fontSize(TYPE_META)
                  .fontColor(this.themeColors.textSecondary)
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Toggle({ type: ToggleType.Switch, isOn: this.isPriority })
                .selectedColor(this.themeColors.primary)
                .onChange((isOn: boolean) => {
                  this.isPriority = isOn;
                })
            }
            .width('100%')

            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              AppStatusBadge({ text: `关键结果 ${this.currentGoal?.keyResults.length || 0}`, tone: 'info', iconName: 'goal' })
              AppStatusBadge({ text: `关联任务 ${this.relatedTasks.length}`, tone: 'primary', iconName: 'task' })
              AppStatusBadge({ text: `已完成 ${this.getCompletedTaskCount()}`, tone: 'success', iconName: 'success' })
            }
            .width('100%')
          }

          AppCard({ variant: 'soft', spacing: SPACE_XS, paddingLevel: 'md' }) {
            Text('提示')
              .fontSize(TYPE_CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeColors.textPrimary)

            Text('目标分类不会在此页修改，如需更换类型或分类，请删除后重新创建。')
              .fontSize(TYPE_META)
              .lineHeight(18)
              .fontColor(this.themeColors.textSecondary)
              .width('100%')
          }

          this.MoreActionSection()
          Blank().height(8)
        }
        .width('100%')
        .padding({ left: COMFORTABLE_PAGE_PADDING, right: COMFORTABLE_PAGE_PADDING, bottom: SPACE_LG })
      }
      .align(Alignment.Top)
      .width('100%')
      .layoutWeight(1)

      Column({ space: SPACE_XS }) {
        AppButton({
          text: this.isSaving ? '保存中...' : '保存修改',
          iconName: 'success',
          loading: this.isSaving,
          disabled: !this.goalTitle.trim() || this.currentGoal?.isArchived === true,
          tapAction: () => {
            void this.saveGoal();
          }
        })
        .width('100%')

        if (this.currentGoal?.isArchived) {
          Text('归档目标不可继续编辑。')
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textMuted)
        }
      }
      .width('100%')
      .padding({ left: COMFORTABLE_PAGE_PADDING, right: COMFORTABLE_PAGE_PADDING, bottom: 24, top: SPACE_XS })
      .backgroundColor(this.themeColors.navBackground)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
