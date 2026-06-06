import dataPreferences from '@ohos.data.preferences';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { Task, TaskStatus } from '../models/Task';
import { Goal } from '../models/Goal';
import type { SavedPlanTaskItem, SavedTodayPlan } from '../models/TodayPlan';
import { buildTodayPlanStorageDate, buildTodayPlanStorageKey } from '../models/TodayPlan';
import { db } from '../storage/Database';
import { dataSyncService } from '../services/DataSyncService';
import { TodayPlanService } from '../services/TodayPlanService';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SECTION_GAP, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('TaskSelectPage');

@Entry
@Component
struct TaskSelectPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State tasks: Task[] = [];
  @State goals: Goal[] = [];
  @State selectedIds: string[] = [];
  @State existingPlan: SavedTodayPlan | null = null;
  @State saving: boolean = false;

  aboutToAppear(): void {
    void this.loadData();
    void this.loadExistingPlan();
  }

  private async loadData(): Promise<void> {
    const context = this.getUIContext().getHostContext() as Context;
    if (!db.isInitialized()) {
      await db.initialize(context);
    }
    const syncTasks = dataSyncService.getTasks();
    const syncGoals = dataSyncService.getGoals();
    this.tasks = (syncTasks.length > 0 ? syncTasks : db.getAllTasks())
      .filter((task: Task) => task.status === TaskStatus.PENDING)
      .sort((first: Task, second: Task) => {
        if (first.isPinned !== second.isPinned) {
          return first.isPinned ? -1 : 1;
        }
        if (first.isOverdue !== second.isOverdue) {
          return first.isOverdue ? -1 : 1;
        }
        return (first.dueDate || Number.MAX_SAFE_INTEGER) - (second.dueDate || Number.MAX_SAFE_INTEGER);
      });
    this.goals = syncGoals.length > 0 ? syncGoals : db.getAllGoals();
  }

  private async loadExistingPlan(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as Context;
      const prefs = await dataPreferences.getPreferences(context, 'chronoisle_settings');
      const today = buildTodayPlanStorageDate();
      const raw = await prefs.get(buildTodayPlanStorageKey(today), '') as string;
      if (!raw) {
        this.existingPlan = null;
        this.selectedIds = [];
        return;
      }
      this.existingPlan = JSON.parse(raw) as SavedTodayPlan;
      this.selectedIds = this.existingPlan.focusTasks.map((item: SavedPlanTaskItem) => item.id);
    } catch (error) {
      logger.error('TaskSelectPage loadExistingPlan error', error as Object);
      this.existingPlan = null;
      this.selectedIds = [];
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch (_) {
    }
  }

  private isSelected(taskId: string): boolean {
    return this.selectedIds.includes(taskId);
  }

  private toggleTask(taskId: string): void {
    if (this.isSelected(taskId)) {
      this.selectedIds = this.selectedIds.filter((id: string) => id !== taskId);
    } else {
      this.selectedIds = [...this.selectedIds, taskId];
    }
  }

  private getGoalName(task: Task): string {
    if (task.goalTitle) {
      return task.goalTitle;
    }
    const goal = this.goals.find((item: Goal) => item.id === task.goalId);
    return goal ? goal.title : '未关联目标';
  }

  private getSelectedCount(): number {
    return this.selectedIds.length;
  }

  private isInExistingPlan(taskId: string): boolean {
    if (!this.existingPlan) {
      return false;
    }
    return this.existingPlan.focusTasks.some((item: SavedPlanTaskItem) => item.id === taskId);
  }

  private formatHours(hours: number): string {
    if (!isFinite(hours) || hours <= 0) {
      return '0.0 小时';
    }
    return `${hours.toFixed(1)} 小时`;
  }

  private getSelectedHours(): number {
    return this.selectedIds.reduce((sum: number, id: string) => {
      const task = this.tasks.find((item: Task) => item.id === id);
      return sum + (task?.estimatedHours || 0);
    }, 0);
  }

  private getHeroTitle(): string {
    if (this.existingPlan && this.existingPlan.focusTasks.length > 0) {
      return '手动补齐今天的重点任务';
    }
    return '先挑出今天最该推进的任务';
  }

  private getHeroDescription(): string {
    if (this.existingPlan && this.existingPlan.focusTasks.length > 0) {
      return '这里是在编辑你当前的今日计划。取消选中会移出今日重点，新增选中会补充进去，但不会删除原始任务。';
    }
    return '如果今天还没有现成计划，可以先手动挑几项任务开始，后面仍然可以回到 AI 今日计划页继续调整。';
  }

  private getSelectionSummary(): string {
    return `${this.getSelectedCount()} 个重点 · 预计 ${this.formatHours(this.getSelectedHours())} · 可选 ${this.tasks.length} 项`;
  }

  private getTaskMeta(task: Task): string {
    const parts: string[] = [];
    if (task.isOverdue) {
      parts.push('已逾期');
    } else if (task.deadline) {
      parts.push(task.deadline);
    } else {
      parts.push('未设置截止时间');
    }

    if (task.estimatedHours && task.estimatedHours > 0) {
      parts.push(`预计 ${this.formatHours(task.estimatedHours)}`);
    }
    return parts.join(' · ');
  }

  private buildFocusTaskItem(task: Task, existingMap: Record<string, SavedPlanTaskItem>): SavedPlanTaskItem {
    const existing = existingMap[task.id];
    const item: SavedPlanTaskItem = {
      id: task.id,
      title: task.title,
      reason: existing?.reason || (task.isOverdue
        ? '今天需要先处理逾期任务'
        : (task.deadline ? '今天适合优先推进' : '手动加入今日重点'))
    };
    if (existing && existing.completed !== undefined) {
      item.completed = existing.completed;
    }
    if (task.estimatedHours && task.estimatedHours > 0) {
      item.estimatedMinutes = Math.round(task.estimatedHours * 60);
    } else if (existing && existing.estimatedMinutes !== undefined) {
      item.estimatedMinutes = existing.estimatedMinutes;
    }
    return item;
  }

  private buildPlanSummary(taskCount: number, totalHours: number): string {
    if (taskCount <= 0) {
      return '今天还没有手动选中的重点任务。';
    }
    if (this.existingPlan && this.existingPlan.focusTasks.length > 0) {
      return `已按你的最新选择更新今日计划，共 ${taskCount} 项重点任务，预计投入 ${this.formatHours(totalHours)}。`;
    }
    return `这是你手动确认的今日计划，共 ${taskCount} 项重点任务，预计投入 ${this.formatHours(totalHours)}。`;
  }

  private async persistPlan(): Promise<void> {
    if (this.saving) {
      return;
    }
    if (this.selectedIds.length === 0) {
      this.showToast('请至少选择一个任务');
      return;
    }

    this.saving = true;
    try {
      const context = this.getUIContext().getHostContext() as Context;
      const prefs = await dataPreferences.getPreferences(context, 'chronoisle_settings');
      const today = buildTodayPlanStorageDate();

      const currentPlan: SavedTodayPlan = this.existingPlan ? this.existingPlan : {
        focusTasks: [],
        deferTasks: [],
        summary: '',
        totalEstimatedHours: 0,
        adoptedAt: Date.now(),
        sourceDate: today,
        planSource: 'local'
      };

      const existingMap: Record<string, SavedPlanTaskItem> = {};
      currentPlan.focusTasks.forEach((item: SavedPlanTaskItem) => {
        existingMap[item.id] = item;
      });

      const selectedTasks: Task[] = [];
      this.selectedIds.forEach((id: string) => {
        const task = this.tasks.find((item: Task) => item.id === id);
        if (task) {
          selectedTasks.push(task);
        }
      });

      const previousIds = currentPlan.focusTasks.map((item: SavedPlanTaskItem) => item.id);
      const removedIds = previousIds.filter((id: string) => !this.selectedIds.includes(id));

      for (const task of this.tasks) {
        const shouldHighlight = this.selectedIds.includes(task.id);
        if (task.isImportant !== shouldHighlight) {
          task.isImportant = shouldHighlight;
          task.updatedAt = Date.now();
          await db.updateTask(task);
          dataSyncService.updateTask(task);
        }
      }

      currentPlan.focusTasks = selectedTasks.map((task: Task) => this.buildFocusTaskItem(task, existingMap));
      currentPlan.deferTasks = currentPlan.deferTasks.filter((item: SavedPlanTaskItem) => !this.selectedIds.includes(item.id));
      currentPlan.totalEstimatedHours = selectedTasks.reduce((sum: number, task: Task) => sum + (task.estimatedHours || 0), 0);
      currentPlan.adoptedAt = Date.now();
      currentPlan.planSource = currentPlan.planSource || 'local';
      currentPlan.summary = this.buildPlanSummary(currentPlan.focusTasks.length, currentPlan.totalEstimatedHours || 0);

      await prefs.put(buildTodayPlanStorageKey(today), JSON.stringify(currentPlan));
      await prefs.flush();
      void TodayPlanService.trySyncPlanToCloud(currentPlan);

      this.showToast(removedIds.length > 0 || this.existingPlan ? '已更新今日计划' : '已加入今日计划');
      this.getUIContext().getRouter().back();
    } catch (error) {
      this.showToast('保存失败，请重试');
      logger.error('TaskSelectPage persistPlan error', error as Object);
    } finally {
      this.saving = false;
    }
  }

  private getTaskCardVariant(task: Task): 'accent' | 'danger' | 'base' {
    if (this.isSelected(task.id)) {
      return 'accent';
    }
    if (task.isOverdue) {
      return 'danger';
    }
    return 'base';
  }

  @Builder
  private HeroCard() {
    AppCard({ variant: 'accent', spacing: SPACE_SM }) {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        AppStatusBadge({ text: '手动调整', tone: 'info', iconName: 'note' })
        AppStatusBadge({
          text: this.existingPlan ? '正在编辑当前计划' : '补齐今日重点',
          tone: 'primary',
          iconName: this.existingPlan ? 'plan' : 'today'
        })
      }
      .width('100%')

      Text(this.getHeroTitle())
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      Text(this.getHeroDescription())
        .fontSize(TYPE_BODY)
        .lineHeight(18)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      Text(this.getSelectionSummary())
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textMuted)
        .width('100%')
    }
  }

  @Builder
  private SelectionSummaryCard() {
    AppCard({ variant: 'soft', spacing: SPACE_XS }) {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        AppStatusBadge({ text: `已选 ${this.getSelectedCount()}`, tone: 'primary', iconName: 'task' })
        AppStatusBadge({ text: `预计 ${this.formatHours(this.getSelectedHours())}`, tone: 'success', iconName: 'focus' })
      }
      .width('100%')

      if (this.existingPlan) {
        Text('取消选中会同步移出今日重点，新增选中会补进当前计划。')
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
      }
    }
  }

  @Builder
  private TaskCard(task: Task) {
    AppCard({
      variant: this.getTaskCardVariant(task),
      spacing: SPACE_XS,
      interactive: true,
      tapAction: () => {
        this.toggleTask(task.id);
      }
    }) {
      Row({ space: 10 }) {
        Text(task.title)
          .layoutWeight(1)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.isInExistingPlan(task.id)) {
          AppStatusBadge({ text: '已在计划', tone: 'info', iconName: 'plan' })
        }
        if (task.isOverdue) {
          AppStatusBadge({ text: '逾期', tone: 'danger', iconName: 'warning' })
        }
      }
      .width('100%')

      Text(this.getGoalName(task))
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      Text(this.getTaskMeta(task))
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textMuted)
        .width('100%')

      Row() {
        Blank()
        AppStatusBadge({
          text: this.isSelected(task.id) ? '已选中' : '选择',
          tone: this.isSelected(task.id) ? 'primary' : 'neutral',
          iconName: this.isSelected(task.id) ? 'success' : 'task'
        })
      }
      .width('100%')
    }
  }

  build() {
    Column() {
      AppPageHeader({
        title: '手动挑选任务',
        subtitle: `已选择 ${this.getSelectedCount()} 项`,
        onBack: () => {
          this.getUIContext().getRouter().back();
        }
      })

      Scroll() {
        Column({ space: SECTION_GAP }) {
          this.HeroCard()
          this.SelectionSummaryCard()

          Text('把今天最想推进的任务加入“今日计划”。已经在计划里的任务会保持选中。')
            .fontSize(TYPE_BODY)
            .lineHeight(18)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')

          if (this.tasks.length === 0) {
            AppEmptyState({
              iconName: 'task',
              iconTone: 'primary',
              title: '当前没有可选的待办任务',
              description: '先创建任务，或者回到 AI 今日计划页查看是否有可直接采纳的预览结果。'
            })
          } else {
            ForEach(this.tasks, (task: Task) => {
              this.TaskCard(task)
            }, (task: Task) => task.id)
          }

          Row()
            .width('100%')
            .height(64)
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: 0 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)

      Column({ space: 10 }) {
        Row() {
          AppButton({
            text: this.saving ? '保存中...' : (this.existingPlan ? '更新今日计划' : '加入今日计划'),
            variant: 'primary',
            buttonSize: 'lg',
            loading: this.saving,
            tapAction: () => {
              void this.persistPlan();
            }
          })
            .width('100%')
        }
        .width('100%')

        if (this.existingPlan) {
          Row() {
            AppButton({
              text: '返回计划页',
              variant: 'secondary',
              buttonSize: 'sm',
              iconName: 'plan',
              tapAction: () => {
                this.getUIContext().getRouter().back();
              }
            })
          }
        }
      }
      .width('100%')
      .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 8, bottom: 16 })
      .backgroundColor(this.themeColors.background)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
