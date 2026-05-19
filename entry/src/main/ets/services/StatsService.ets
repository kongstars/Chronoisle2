// 统计服务 - 提供数据统计功能
import { Goal, GoalCategory } from '../models/Goal';
import { Task, TaskStatus } from '../models/Task';
import { Pomodoro } from '../models/Pomodoro';
import { authService } from './AuthService';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('StatsService');

// 时间范围选项
export enum TimeRange {
  DAY = 1,
  WEEK = 7,
  MONTH = 30,
  YEAR = 365,
  CUSTOM = -1
}

// 统计数据接口
export interface GoalFocusItem {
  goalId: string;
  goalTitle: string;
  minutes: number;
  count: number;
  color: string;
}

export interface HourDistItem {
  hour: number;
  count: number;
}

export interface DayBarItem {
  label: string;
  minutes: number;
  date: number;
}

export interface HeatmapCell {
  date: number;
  label: string;
  minutes: number;
  level: number;
}

export interface FocusStat {
  totalCount: number;
  totalMinutes: number;
  heatmapData: HeatmapCell[];
  trendData: DayBarItem[];
  hourDistribution: HourDistItem[];
  goalDistribution: GoalFocusItem[];
}

export interface StatsData {
  // 目标统计
  totalGoals: number;
  completedGoals: number;
  inProgressGoals: number;
  goalCompletionRate: number;
  
  // 任务统计
  totalTasks: number;
  completedTasks: number;
  pendingTasks: number;
  taskCompletionRate: number;
  
  // 分类统计
  categoryStats: CategoryStat[];
  
  // 趋势统计（按天）
  dailyStats: DailyStat[];
  
  // 周报统计
  weeklyStats: WeeklyStat[];
  
  // 专注统计
  focusStats: FocusStat;
  
  // 是否因为非会员被降级限制查询
  isFallbackFromPremium: boolean;
}

export interface CategoryStat {
  category: GoalCategory;
  categoryName: string;
  icon: string;
  color: string;
  totalGoals: number;
  completedGoals: number;
  completionRate: number;
  totalTasks: number;
  completedTasks: number;
}

export interface DailyStat {
  date: string;
  timestamp: number;
  completedGoals: number;
  completedTasks: number;
}

export interface WeeklyStat {
  weekLabel: string;
  startDate: number;
  endDate: number;
  completedGoals: number;
  completedTasks: number;
}

export class StatsService {
  private static instance: StatsService;
  
  private constructor() {}
  
  static getInstance(): StatsService {
    if (!StatsService.instance) {
      StatsService.instance = new StatsService();
    }
    return StatsService.instance;
  }
  
  private startOfDay(ts: number): number {
    const d = new Date(ts);
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }

  // 计算统计数据
  async calculateStats(goals: Goal[], tasks: Task[], pomodoros: Pomodoro[], timeRange: TimeRange = TimeRange.WEEK, customStart?: number, customEnd?: number): Promise<StatsData> {
    const user = await authService.getCurrentUser();
    const isPremium = authService.isPremiumUser(user);

    let startTime = 0;
    let endTime = Date.now();
    let isFallback = false;

    if (timeRange === TimeRange.CUSTOM && customStart !== undefined && customEnd !== undefined) {
      startTime = this.startOfDay(customStart);
      endTime = this.startOfDay(customEnd) + 86400000; // custom end is inclusive day
    } else {
      const dayMs = 24 * 60 * 60 * 1000;
      startTime = endTime - (timeRange * dayMs);
      startTime = this.startOfDay(startTime);
    }

    // 会员权限校验：查询跨度超过 31 天需要 Premium
    const spanDays = (endTime - startTime) / (24 * 60 * 60 * 1000);
    if (!isPremium && spanDays > 31) {
      isFallback = true;
      const dayMs = 24 * 60 * 60 * 1000;
      endTime = Date.now();
      startTime = endTime - (30 * dayMs);
      startTime = this.startOfDay(startTime);
      timeRange = TimeRange.MONTH;
    }

    // 过滤时间范围内的数据
    // 注意目标需要在这个范围内创建，或者在范围内活动（进展）
    const filteredGoals = goals.filter(g => g.createdAt >= startTime && g.createdAt <= endTime);
    const filteredTasks = tasks.filter(t => t.createdAt >= startTime && t.createdAt <= endTime);
    const filteredPomodoros = pomodoros.filter(p => p.completed && p.startTime >= startTime && p.startTime <= endTime);
    
    // 目标统计
    const totalGoals = filteredGoals.length;
    const completedGoals = filteredGoals.filter(g => g.progress === 100).length;
    const inProgressGoals = totalGoals - completedGoals;
    const goalCompletionRate = totalGoals > 0 ? Math.round((completedGoals / totalGoals) * 100) : 0;
    
    // 任务统计
    const totalTasks = filteredTasks.length;
    const completedTasks = filteredTasks.filter(t => t.status === TaskStatus.COMPLETED).length;
    const pendingTasks = totalTasks - completedTasks;
    const taskCompletionRate = totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0;
    
    // 分类统计
    const categoryStats = this.calculateCategoryStats(filteredGoals, filteredTasks);
    
    // 趋势统计
    const querySpanDays = (endTime - startTime) / 86400000;
    const maxDaily = Math.max(7, Math.min(30, Math.ceil(querySpanDays)));
    const dailyStats = this.calculateDailyStats(goals, tasks, maxDaily, endTime); 
    
    // 周报统计
    const weeklyStats = this.calculateWeeklyStats(goals, tasks, querySpanDays, endTime);
    
    // 专注统计
    const focusStats = this.calculateFocusStats(filteredPomodoros, tasks, startTime, endTime, querySpanDays);
    return {
      totalGoals,
      completedGoals,
      inProgressGoals,
      goalCompletionRate,
      totalTasks,
      completedTasks,
      pendingTasks,
      taskCompletionRate,
      categoryStats,
      dailyStats,
      weeklyStats,
      focusStats,
      isFallbackFromPremium: isFallback
    } as StatsData;
  }
  
  // 分类统计
  private calculateCategoryStats(goals: Goal[], tasks: Task[]): CategoryStat[] {
    const categories: GoalCategory[] = [
      GoalCategory.HEALTH, GoalCategory.LEARNING, GoalCategory.FINANCE, GoalCategory.FUN
    ];
    const categoryNames: Record<string, string> = { '健康': '健康', '成长': '成长', '理财': '理财', '快乐': '快乐' };
      const categoryIcons: Record<string, string> = { '健康': 'health', '成长': 'growth', '理财': 'finance', '快乐': 'joy' };
    const categoryColors: Record<string, string> = { '健康': '#52C41A', '成长': '#FA8C16', '理财': '#722ED1', '快乐': '#F5222D' };
    
    const allCategoryStats = categories.map((category: GoalCategory): CategoryStat => {
      const categoryGoals = goals.filter((g: Goal) => g.category === category);
      const categoryCompletedGoals = categoryGoals.filter((g: Goal) => g.progress === 100).length;
      const categoryGoalIds = categoryGoals.map((g: Goal) => g.id);
      const categoryTasks = tasks.filter((t: Task) => categoryGoalIds.includes(t.goalId));
      const categoryCompletedTasks = categoryTasks.filter((t: Task) => t.status === TaskStatus.COMPLETED).length;
      const catStr: string = category as string;
      
      return {
        category: category,
        categoryName: categoryNames[catStr],
        icon: categoryIcons[catStr],
        color: categoryColors[catStr],
        totalGoals: categoryGoals.length,
        completedGoals: categoryCompletedGoals,
        completionRate: categoryGoals.length > 0 ? Math.round((categoryCompletedGoals / categoryGoals.length) * 100) : 0,
        totalTasks: categoryTasks.length,
        completedTasks: categoryCompletedTasks
      };
    });
    
    return allCategoryStats.filter((stat: CategoryStat) => stat.totalGoals > 0 || stat.totalTasks > 0);
  }
  
  // 每日趋势统计
  private calculateDailyStats(goals: Goal[], tasks: Task[], days: number, endTime: number): DailyStat[] {
    const dailyStats: DailyStat[] = [];
    const endMidnight = this.startOfDay(endTime);
    const dayMs = 24 * 60 * 60 * 1000;
    
    for (let i = days - 1; i >= 0; i--) {
      const dayStart = endMidnight - (i * dayMs);
      const dayEnd = dayStart + dayMs;
      const date = new Date(dayStart);
      const dateStr = `${date.getMonth() + 1}/${date.getDate()}`;
      
      const completedGoals = goals.filter(g => {
        if (g.progress !== 100) return false;
        const targetTime = g.updatedAt || g.createdAt;
        return targetTime >= dayStart && targetTime < dayEnd;
      }).length;
      
      const completedTasks = tasks.filter(t => {
        if (t.status !== TaskStatus.COMPLETED || !t.completedAt) return false;
        return t.completedAt >= dayStart && t.completedAt < dayEnd;
      }).length;
      
      dailyStats.push({
        date: dateStr,
        timestamp: dayStart,
        completedGoals,
        completedTasks
      });
    }
    
    return dailyStats;
  }
  
  // 每周统计
  private calculateWeeklyStats(goals: Goal[], tasks: Task[], spanDays: number, endTime: number): WeeklyStat[] {
    const weeklyStats: WeeklyStat[] = [];
    const dayMs = 24 * 60 * 60 * 1000;
    const weekMs = 7 * dayMs;
    
    const weeksCount = Math.max(1, Math.ceil(spanDays / 7));
    const endMidnight = this.startOfDay(endTime);
    
    for (let i = weeksCount - 1; i >= 0; i--) {
      const weekStart = endMidnight - (i * weekMs);
      const weekEnd = weekStart + weekMs;
      const startDate = new Date(weekStart);
      const weekLabel = `${startDate.getMonth() + 1}/${startDate.getDate()}`;
      
      const completedGoals = goals.filter(g => {
        if (g.progress !== 100) return false;
        const targetTime = g.updatedAt || g.createdAt;
        return targetTime >= weekStart && targetTime < weekEnd;
      }).length;
      
      const completedTasks = tasks.filter(t => {
        if (t.status !== TaskStatus.COMPLETED || !t.completedAt) return false;
        return t.completedAt >= weekStart && t.completedAt < weekEnd;
      }).length;
      
      weeklyStats.push({
        weekLabel,
        startDate: weekStart,
        endDate: weekEnd,
        completedGoals,
        completedTasks
      });
    }
    
    return weeklyStats;
  }

  // 专注相关算法
  private getPomodoroDuration(p: Pomodoro): number {
    if (p.endTime) {
      return Math.round((p.endTime - p.startTime) / 60000);
    }
    return p.duration;
  }

  private calculateFocusStats(pomodoros: Pomodoro[], tasks: Task[], startTime: number, endTime: number, spanDays: number): FocusStat {
    const totalMinutes = pomodoros.reduce((sum, p) => sum + this.getPomodoroDuration(p), 0);
    const dayMs = 24 * 60 * 60 * 1000;
    const endMidnight = this.startOfDay(endTime);

    // Heatmap (最多取近期28天内)
    const heatmapDays = Math.min(28, spanDays);
    const heatmapData: HeatmapCell[] = [];
    for (let i = heatmapDays - 1; i >= 0; i--) {
      const dayStart = endMidnight - (i * dayMs);
      const d = new Date(dayStart);
      const label = `${d.getMonth() + 1}/${d.getDate()}`;

      const minutes = pomodoros
        .filter(p => p.startTime >= dayStart && p.startTime < dayStart + dayMs)
        .reduce((sum, p) => sum + this.getPomodoroDuration(p), 0);

      let level = 0;
      if (minutes > 120) level = 4;
      else if (minutes > 60) level = 3;
      else if (minutes > 25) level = 2;
      else if (minutes > 0) level = 1;

      heatmapData.push({ date: dayStart, label, minutes, level });
    }

    // 趋势柱状图 (最多取近期30天)
    const trendDays = Math.min(30, spanDays);
    const trendData: DayBarItem[] = [];
    for (let i = trendDays - 1; i >= 0; i--) {
      const dayStart = endMidnight - (i * dayMs);
      const d = new Date(dayStart);
      const label = `${d.getMonth() + 1}/${d.getDate()}`;

      const minutes = pomodoros
        .filter(p => p.startTime >= dayStart && p.startTime < dayStart + dayMs)
        .reduce((sum, p) => sum + this.getPomodoroDuration(p), 0);

      trendData.push({ label, minutes, date: dayStart });
    }

    // 目标分布
    const goalColors = [
      '#5B8FF9', '#5AD8A6', '#F6BD16', '#E86452', '#6DC8EC',
      '#945FB9', '#FF9845', '#1E9493', '#FF99C3', '#269A99'
    ];
    const goalMap: Record<string, GoalFocusItem> = {};

    pomodoros.forEach(p => {
      const task = tasks.find(t => t.id === p.taskId);
      const goalId = task?.goalId || 'unknown';
      const goalTitle = task?.goalTitle || '未关联目标';

      if (!goalMap[goalId]) {
        const idx = Object.keys(goalMap).length % goalColors.length;
        goalMap[goalId] = {
          goalId,
          goalTitle,
          minutes: 0,
          count: 0,
          color: goalColors[idx]
        };
      }
      goalMap[goalId].minutes += this.getPomodoroDuration(p);
      goalMap[goalId].count += 1;
    });

    const goalDistribution = Object.keys(goalMap)
      .map(key => goalMap[key])
      .sort((a, b) => b.minutes - a.minutes);

    // 时段分布
    const hourCounts: number[] = new Array(24).fill(0);
    pomodoros.forEach((p: Pomodoro) => {
      const h = new Date(p.startTime).getHours();
      hourCounts[h] += 1;
    });
    const hourDistribution = hourCounts.map((count, hour) => ({ hour, count } as HourDistItem));

    return {
      totalCount: pomodoros.length,
      totalMinutes,
      heatmapData,
      trendData,
      hourDistribution,
      goalDistribution
    };
  }
  
  // 生成并导出统计报表
  async exportStatsFile(_context: object, goals: Goal[], tasks: Task[], pomodoros: Pomodoro[], timeRange: TimeRange, customStart?: number, customEnd?: number): Promise<boolean> {
    const user = await authService.getCurrentUser();
    // 强制高级会员判断
    if (!user || user.membershipType !== 'premium' || (user.membershipExpireAt && user.membershipExpireAt <= Date.now())) {
      throw new Error('REQUIRE_PREMIUM');
    }
    
    // 根据区间计算数据
    const stats = await this.calculateStats(goals, tasks, pomodoros, timeRange, customStart, customEnd);
    const dateStr = new Date().toISOString().split('T')[0];
    
    let csv = '\ufeff数据类别,指标,数值\n'; // 加入 BOM 以适配 Excel
    csv += `总览,目标完成数,${stats.completedGoals}/${stats.totalGoals}\n`;
    csv += `总览,任务完成数,${stats.completedTasks}/${stats.totalTasks}\n`;
    csv += `专注,总次数,${stats.focusStats.totalCount}\n`;
    csv += `专注,总时长(分钟),${stats.focusStats.totalMinutes}\n\n`;
    
    csv += `目标分布详情,目标名称,投入时间(分钟),专注次数\n`;
    stats.focusStats.goalDistribution.forEach(g => {
      // 防止包含逗号干扰 CSV
      const safeTitle = g.goalTitle.replace(/,/g, ' ');
      csv += `,${safeTitle},${g.minutes},${g.count}\n`;
    });
    
    try {
      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [`Chronoisle_Stats_${dateStr}.csv`];
      
      const documentViewPicker = new picker.DocumentViewPicker();
      const documentSaveResult = await documentViewPicker.save(documentSaveOptions);
      
      if (documentSaveResult && documentSaveResult.length > 0) {
        const uri = documentSaveResult[0];
        const file = await fs.open(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        await fs.write(file.fd, csv);
        await fs.close(file);
        return true;
      }
      return false; // 取消保存
    } catch (e) {
      logger.error('Export failed', e as Object);
      return false;
    }
  }
}

export const statsService = StatsService.getInstance();
