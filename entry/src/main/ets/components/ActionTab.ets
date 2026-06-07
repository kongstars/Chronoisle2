/**
 * ActionTab — 行动 Tab（融合：任务列表 + 时间日历 + 提醒下钻）
 *
 * 顶部固定 Header（标题 + 提醒中心 + 新建）
 * 中部视图切换（列表 / 时间）
 * 下部内嵌 TaskListTab 或 CalendarTab
 *
 * 提醒管理（暂停/恢复/长期暂停）通过右上角"提醒中心"下钻到 ReminderListPage。
 */

import { TaskListTab } from './TaskListTab';
import { CalendarTab } from './CalendarTab';
import { Goal } from '../models/Goal';
import { Task, TaskStatus } from '../models/Task';
import { DayEvent } from '../models/DayEvent';
import { startOfDay } from '../common/DayEventUtils';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { AppIcon } from '../ui/base/AppIcon';
import { AppSegmentTabs } from '../ui/base/AppSegmentTabs';
import { COMPACT_PAGE_PADDING } from '../foundation/tokens/PageTierTokens';
import { SPACE_2XS, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_CAPTION, TYPE_HERO_TITLE, TYPE_META } from '../foundation/tokens/TypographyTokens';

@Component
struct ActionTabHeaderButton {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop iconName: string = '';
  @Prop badge: string = '';
  @Prop tone: 'primary' | 'neutral' = 'neutral';
  @State isPressed: boolean = false;
  onTap?: () => void;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(40)
        .height(40)
        .backgroundColor(this.tone === 'primary' ? this.themeColors.primarySubtle : this.themeColors.surfaceSoft)
        .borderRadius(20)

      AppIcon({
        name: this.iconName,
        iconSize: 22,
        framed: false,
        color: this.tone === 'primary' ? this.themeColors.primary : this.themeColors.textSecondary
      })

      if (this.badge.length > 0) {
        Row() {
          Text(this.badge)
            .fontSize(TYPE_CAPTION)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textOnPrimary)
        }
        .padding({ left: 4, right: 4 })
        .height(14)
        .constraintSize({ minWidth: 14 })
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.themeColors.danger)
        .borderRadius(7)
        .border({ width: 1, color: this.themeColors.background })
        .position({ x: 26, y: -4 })
      }
    }
    .width(40)
    .height(40)
    .scale({ x: this.isPressed ? 0.96 : 1, y: this.isPressed ? 0.96 : 1 })
    .animation({ duration: 100, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .onClick(() => {
      if (this.onTap) this.onTap();
    })
  }
}

@Component
export struct ActionTab {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop tasks: Task[] = [];
  @Prop goals: Goal[] = [];
  @Prop dayEvents: DayEvent[] = [];

  // 视图切换：0 列表  1 时间
  @State viewIndex: number = 0;

  onCreate?: () => void;
  onOpenReminderCenter?: () => void;
  onOpenSearch?: () => void;

  private getPendingCount(): number {
    return this.tasks.filter((t: Task) => t.status === TaskStatus.PENDING).length;
  }

  private getOverdueCount(): number {
    const now = Date.now();
    return this.tasks.filter((t: Task) => t.status === TaskStatus.PENDING && t.dueDate !== undefined && t.dueDate < now).length;
  }

  private getActiveReminderCount(): number {
    return this.dayEvents.filter((e: DayEvent) => e.isEnabled).length;
  }

  private getSubtitle(): string {
    const overdue = this.getOverdueCount();
    const today = this.getTodayActionableCount();
    if (overdue > 0) {
      return `今天 ${today} 件 · 需关注 ${overdue} 件`;
    }
    if (today > 0) {
      return `今天还有 ${today} 件待办`;
    }
    return '安排井然，按计划推进';
  }

  private getTodayActionableCount(): number {
    const start = startOfDay(Date.now());
    const end = start + 86400000;
    return this.tasks.filter((t: Task) => {
      if (t.status !== TaskStatus.PENDING) {
        return false;
      }
      if (t.dueDate === undefined) {
        return false;
      }
      return t.dueDate < end;
    }).length;
  }

  private getReminderBadge(): string {
    const count = this.getActiveReminderCount();
    if (count <= 0) {
      return '';
    }
    return count > 99 ? '99+' : `${count}`;
  }

  @Builder
  private Header() {
    Row({ space: SPACE_SM }) {
      Column({ space: 2 }) {
        Text('行动')
          .fontSize(TYPE_HERO_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
        Text(this.getSubtitle())
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 搜索（跳全局 SearchPage）
      ActionTabHeaderButton({
        iconName: 'search',
        badge: '',
        tone: 'neutral',
        onTap: () => {
          if (this.onOpenSearch) {
            this.onOpenSearch();
          }
        }
      })

      // 提醒中心
      ActionTabHeaderButton({
        iconName: 'reminder',
        badge: this.getReminderBadge(),
        tone: 'neutral',
        onTap: () => {
          if (this.onOpenReminderCenter) {
            this.onOpenReminderCenter();
          }
        }
      })

      // 新建
      ActionTabHeaderButton({
        iconName: 'plus',
        badge: '',
        tone: 'primary',
        onTap: () => {
          if (this.onCreate) {
            this.onCreate();
          }
        }
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: COMPACT_PAGE_PADDING, right: COMPACT_PAGE_PADDING, top: 8, bottom: 4 })
  }

  @Builder
  private ViewSwitcher() {
    Row() {
      AppSegmentTabs({
        tabs: ['列表', '时间'],
        selectedIndex: this.viewIndex,
        onSelect: (index: number) => {
          this.viewIndex = index;
        }
      })
    }
    .width('100%')
    .padding({ left: COMPACT_PAGE_PADDING, right: COMPACT_PAGE_PADDING, top: SPACE_2XS, bottom: SPACE_SM })
  }

  build() {
    Column() {
      this.Header()
      this.ViewSwitcher()

      Column() {
        if (this.viewIndex === 0) {
          TaskListTab({
            tasks: this.tasks,
            goals: this.goals,
            embedded: true
          })
        } else {
          CalendarTab({
            dayEvents: this.dayEvents,
            tasks: this.tasks,
            embedded: true,
            onOpenReminderCenter: () => {
              if (this.onOpenReminderCenter) {
                this.onOpenReminderCenter();
              }
            }
          })
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
