// 统计服务 - 提供数据统计功能
import { Goal, GoalCategory } from '../models/Goal';
import { Task, TaskStatus } from '../models/Task';

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
  
  // 趋势统计（最近 7 天）
  dailyStats: DailyStat[];
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
  calculateStats(goals: Goal[], tasks: Task[]): StatsData {
    // 目标统计
    const totalGoals = goals.length;
    const completedGoals = goals.filter(g => g.progress === 100).length;
    const inProgressGoals = totalGoals - completedGoals;
    const goalCompletionRate = totalGoals > 0 ? Math.round((completedGoals / totalGoals) * 100) : 0;
    
    // 任务统计
    const totalTasks = tasks.length;
    const completedTasks = tasks.filter(t => t.status === TaskStatus.COMPLETED).length;
    const pendingTasks = totalTasks - completedTasks;
    const taskCompletionRate = totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0;
    
    // 分类统计
    const categoryStats = this.calculateCategoryStats(goals, tasks);
    
    // 趋势统计
    const dailyStats = this.calculateDailyStats(goals, tasks);
    
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
      dailyStats
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
  
  // 每日趋势统计（最近 7 天）
  private calculateDailyStats(goals: Goal[], tasks: Task[]): DailyStat[] {
    const dailyStats: DailyStat[] = [];
    const now = Date.now();
    const dayMs = 24 * 60 * 60 * 1000;
    
    for (let i = 6; i >= 0; i--) {
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
}

export const statsService = StatsService.getInstance();
