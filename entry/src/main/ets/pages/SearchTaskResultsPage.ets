import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { db } from '../storage/Database';
import { Task } from '../models/Task';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppLoadingState } from '../ui/base/AppLoadingState';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { TaskListTab } from '../components/TaskListTab';
import { PAGE_PADDING } from '../foundation/tokens/SpacingTokens';
import { Logger } from '../Utils/Logger';
import AppConfig from '../Utils/AppConfig';
import { searchSessionService } from '../services/SearchSessionService';

const logger = Logger.create('SearchTaskResultsPage');

interface SearchTaskResultsPageParams {
  keyword?: string;
  searchId?: string;
}

@Entry
@Component
struct SearchTaskResultsPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State keyword: string = '';
  @State tasks: Task[] = [];
  @State isLoading: boolean = true;
  private hasLoadedParams: boolean = false;
  private searchId: string = '';

  aboutToAppear(): void {
    this.applyEntryParams();
    void this.loadTasks();
  }

  private applyEntryParams(): void {
    if (this.hasLoadedParams) {
      return;
    }
    this.hasLoadedParams = true;
    const params = this.getUIContext().getRouter().getParams() as SearchTaskResultsPageParams;
    if (params && params.keyword) {
      this.keyword = params.keyword;
    }
    if (params && params.searchId) {
      this.searchId = params.searchId;
    }
  }

  private async loadTasks(): Promise<void> {
    this.isLoading = true;
    try {
      if (this.searchId.length > 0) {
        const sessionTasks = searchSessionService.getTaskResultsBySearchId(this.searchId);
        if (sessionTasks) {
          this.tasks = sessionTasks.sort((first: Task, second: Task) => (second.updatedAt || second.createdAt) - (first.updatedAt || first.createdAt));
          return;
        }
      }

      const query = this.normalize(this.keyword);
      const cachedTasks = searchSessionService.getTaskResults(query);
      if (cachedTasks) {
        this.tasks = cachedTasks.sort((first: Task, second: Task) => (second.updatedAt || second.createdAt) - (first.updatedAt || first.createdAt));
        return;
      }

      const context = this.getUIContext().getHostContext() as Context;
      await db.initialize(context);
      const allTasks = db.getAllTasks()
        .sort((first: Task, second: Task) => (second.updatedAt || second.createdAt) - (first.updatedAt || first.createdAt));

      this.tasks = query.length === 0 ? [] : allTasks.filter((task: Task) => {
        return this.containsQuery(task.title, query) ||
          this.containsQuery(task.description, query) ||
          this.containsQuery(task.goalTitle, query);
      });
    } catch (error) {
      logger.error('SearchTaskResultsPage loadTasks error', error as Object);
      this.tasks = [];
    } finally {
      this.isLoading = false;
    }
  }

  private normalize(value: string | undefined): string {
    return (value || '').trim().toLowerCase();
  }

  private containsQuery(value: string | undefined, query: string): boolean {
    return this.normalize(value).includes(query);
  }

  private getDebugTitle(task: Task): string {
    const title = (task.title || '').trim();
    return title.length > 0 ? title : '未命名任务';
  }

  private getTaskDebugLines(): string[] {
    return this.tasks.map((task: Task, index: number) => {
      return `#${index + 1} | ${task.id} | ${this.getDebugTitle(task)}`;
    });
  }

  build() {
    Column({ space: 0 }) {
      AppPageHeader({
        title: '任务搜索结果',
        subtitle: this.keyword.length > 0 ? `"${this.keyword}" · ${this.tasks.length} 条` : `${this.tasks.length} 条`,
        onBack: () => {
          this.getUIContext().getRouter().back();
        }
      })

      if (this.isLoading) {
        Column() {
          AppLoadingState({ label: '正在整理任务结果' })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding(PAGE_PADDING)
      } else if (this.tasks.length === 0) {
        Column() {
          AppEmptyState({
            iconName: 'task',
            iconTone: 'info',
            title: '没有找到匹配任务',
            description: '换一个关键词试试，或者返回搜索页查看目标和提醒结果。'
          })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding(PAGE_PADDING)
      } else {
        if (AppConfig.isTestEnvironment()) {
          Scroll() {
            Column({ space: 8 }) {
              Text(`纯文本诊断：${this.tasks.length} 条`)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.themeColors.textPrimary)
                .width('100%')

              ForEach(this.getTaskDebugLines(), (line: string) => {
                Text(line)
                  .fontSize(13)
                  .lineHeight(20)
                  .fontColor(this.themeColors.textSecondary)
                  .width('100%')
                  .textAlign(TextAlign.Start)
              }, (line: string) => line)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(PAGE_PADDING)
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Auto)
        } else {
          TaskListTab({
            tasks: this.tasks,
            goals: [],
            embedded: true
          })
          .layoutWeight(1)
          .width('100%')
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
