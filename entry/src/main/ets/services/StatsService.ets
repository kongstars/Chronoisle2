// 统计服务 - 提供数据统计功能
import { Goal, GoalCategory } from '../models/Goal';
import { Task, TaskStatus } from '../models/Task';

// 时间范围选项
export enum TimeRange {
  LAST_7_DAYS = 7,
  LAST_30_DAYS = 30,
  LAST_90_DAYS = 90,
  ALL_TIME = 0
}

// 统计数据接口
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
  
  // 计算统计数据
  calculateStats(goals: Goal[], tasks: Task[], timeRange: TimeRange = TimeRange.LAST_7_DAYS): StatsData {
    // 计算时间范围
    const now = Date.now();
    const dayMs = 24 * 60 * 60 * 1000;
    const startTime = timeRange === TimeRange.ALL_TIME ? 0 : now - (timeRange * dayMs);
    
    // 过滤时间范围内的数据
    const filteredGoals = goals.filter(g => g.createdAt >= startTime);
    const filteredTasks = tasks.filter(t => t.createdAt >= startTime);
    
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
    const daysToShow = timeRange === TimeRange.ALL_TIME ? 90 : timeRange;
    const dailyStats = this.calculateDailyStats(goals, tasks, Math.min(daysToShow, 30)); // 最多显示 30 天
    
    // 周报统计
    const weeklyStats = this.calculateWeeklyStats(goals, tasks, timeRange);
    
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
      weeklyStats
    };
  }
  
  // 分类统计
  private calculateCategoryStats(goals: Goal[], tasks: Task[]): CategoryStat[] {
    const categories = Object.values(GoalCategory);
    const categoryNames = {
      [GoalCategory.CAREER]: '事业',
      [GoalCategory.HEALTH]: '健康',
      [GoalCategory.LEARNING]: '学习',
      [GoalCategory.FINANCE]: '理财',
      [GoalCategory.SOCIAL]: '社交',
      [GoalCategory.FAMILY]: '家庭',
      [GoalCategory.GROWTH]: '成长',
      [GoalCategory.FUN]: '娱乐'
    };
    
    const categoryIcons = {
      [GoalCategory.CAREER]: '💼',
      [GoalCategory.HEALTH]: '💪',
      [GoalCategory.LEARNING]: '📚',
      [GoalCategory.FINANCE]: '💰',
      [GoalCategory.SOCIAL]: '🤝',
      [GoalCategory.FAMILY]: '👨‍👩‍👧',
      [GoalCategory.GROWTH]: '🌱',
      [GoalCategory.FUN]: '🎮'
    };
    
    const categoryColors = {
      [GoalCategory.CAREER]: '#FF6B6B',
      [GoalCategory.HEALTH]: '#4ECDC4',
      [GoalCategory.LEARNING]: '#45B7D1',
      [GoalCategory.FINANCE]: '#FFA502',
      [GoalCategory.SOCIAL]: '#A55EEA',
      [GoalCategory.FAMILY]: '#FF85A2',
      [GoalCategory.GROWTH]: '#26DE81',
      [GoalCategory.FUN]: '#FD9644'
    };
    
    return categories.map(category => {
      const categoryGoals = goals.filter(g => g.category === category);
      const categoryCompletedGoals = categoryGoals.filter(g => g.progress === 100).length;
      const categoryGoalIds = categoryGoals.map(g => g.id);
      const categoryTasks = tasks.filter(t => categoryGoalIds.includes(t.goalId));
      const categoryCompletedTasks = categoryTasks.filter(t => t.status === TaskStatus.COMPLETED).length;
      
      return {
        category,
        categoryName: categoryNames[category],
        icon: categoryIcons[category],
        color: categoryColors[category],
        totalGoals: categoryGoals.length,
        completedGoals: categoryCompletedGoals,
        completionRate: categoryGoals.length > 0 ? Math.round((categoryCompletedGoals / categoryGoals.length) * 100) : 0,
        totalTasks: categoryTasks.length,
        completedTasks: categoryCompletedTasks
      };
    });
  }
  
  // 每日趋势统计
  private calculateDailyStats(goals: Goal[], tasks: Task[], days: number = 7): DailyStat[] {
    const dailyStats: DailyStat[] = [];
    const now = Date.now();
    const dayMs = 24 * 60 * 60 * 1000;
    
    for (let i = days - 1; i >= 0; i--) {
      const dayStart = now - (i * dayMs);
      const dayEnd = dayStart + dayMs;
      const date = new Date(dayStart);
      const dateStr = `${date.getMonth() + 1}/${date.getDate()}`;
      
      // 统计当天完成的目标
      const completedGoals = goals.filter(g => {
        if (g.progress !== 100) return false;
        const updatedAt = g.updatedAt || g.createdAt;
        return updatedAt >= dayStart && updatedAt < dayEnd;
      }).length;
      
      // 统计当天完成的任务
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
  private calculateWeeklyStats(goals: Goal[], tasks: Task[], timeRange: TimeRange): WeeklyStat[] {
    const weeklyStats: WeeklyStat[] = [];
    const now = Date.now();
    const dayMs = 24 * 60 * 60 * 1000;
    const weekMs = 7 * dayMs;
    
    const weeksCount = timeRange === TimeRange.ALL_TIME ? 12 : Math.ceil(timeRange / 7);
    
    for (let i = weeksCount - 1; i >= 0; i--) {
      const weekStart = now - (i * weekMs);
      const weekEnd = weekStart + weekMs;
      const startDate = new Date(weekStart);
      const endDate = new Date(weekEnd);
      const weekLabel = `${startDate.getMonth() + 1}/${startDate.getDate()}`;
      
      // 统计该周完成的目标
      const completedGoals = goals.filter(g => {
        if (g.progress !== 100) return false;
        const updatedAt = g.updatedAt || g.createdAt;
        return updatedAt >= weekStart && updatedAt < weekEnd;
      }).length;
      
      // 统计该周完成的任务
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
  
  // 生成统计报告（用于导出）
  generateReport(goals: Goal[], tasks: Task[], timeRange: TimeRange = TimeRange.LAST_7_DAYS): string {
    const stats = this.calculateStats(goals, tasks, timeRange);
    const now = new Date();
    const dateStr = `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`;
    
    let report = `📊 人生目标管理器 - 统计报告\n`;
    report += `生成时间：${dateStr}\n`;
    report += `统计范围：${this.getTimeRangeLabel(timeRange)}\n\n`;
    
    report += `═══ 核心指标 ═══\n`;
    report += `🎯 目标：${stats.completedGoals}/${stats.totalGoals} (${stats.goalCompletionRate}% 完成)\n`;
    report += `✅ 任务：${stats.completedTasks}/${stats.totalTasks} (${stats.taskCompletionRate}% 完成)\n\n`;
    
    report += `═══ 分类统计 ═══\n`;
    stats.categoryStats.forEach(cat => {
      if (cat.totalGoals > 0) {
        report += `${cat.icon} ${cat.categoryName}: ${cat.completedGoals}/${cat.totalGoals} 目标，${cat.completedTasks}/${cat.totalTasks} 任务\n`;
      }
    });
    
    report += `\n═══ 最近趋势 ═══\n`;
    stats.dailyStats.slice(-7).forEach(day => {
      if (day.completedGoals > 0 || day.completedTasks > 0) {
        report += `${day.date}: ${day.completedGoals} 目标，${day.completedTasks} 任务\n`;
      }
    });
    
    return report;
  }
  
  private getTimeRangeLabel(timeRange: TimeRange): string {
    switch (timeRange) {
      case TimeRange.LAST_7_DAYS: return '最近 7 天';
      case TimeRange.LAST_30_DAYS: return '最近 30 天';
      case TimeRange.LAST_90_DAYS: return '最近 90 天';
      case TimeRange.ALL_TIME: return '全部时间';
      default: return '自定义';
    }
  }
}

export const statsService = StatsService.getInstance();
