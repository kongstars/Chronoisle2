import { GoalCategory } from '../models/Goal';

export interface CategoryInfo {
  value: GoalCategory;
  label: string;
  color: string;
  icon: string;
}

// 8 大生活维度配置
export const CATEGORIES: CategoryInfo[] = [
  { value: GoalCategory.CAREER, label: '💼 事业', color: '#2196F3', icon: '💼' },
  { value: GoalCategory.HEALTH, label: '💪 健康', color: '#FF5722', icon: '💪' },
  { value: GoalCategory.LEARNING, label: '📚 学习', color: '#4CAF50', icon: '📚' },
  { value: GoalCategory.FINANCE, label: '💰 理财', color: '#FFC107', icon: '💰' },
  { value: GoalCategory.SOCIAL, label: '👥 社交', color: '#9C27B0', icon: '👥' },
  { value: GoalCategory.FAMILY, label: '👨‍👩‍👧 家庭', color: '#FF9800', icon: '👨‍👩‍👧' },
  { value: GoalCategory.GROWTH, label: '🌱 成长', color: '#00BCD4', icon: '🌱' },
  { value: GoalCategory.FUN, label: '🎉 娱乐', color: '#E91E63', icon: '🎉' }
];

// 分类颜色映射
export const CATEGORY_COLORS: Record<GoalCategory, string> = {
  [GoalCategory.CAREER]: '#2196F3',
  [GoalCategory.HEALTH]: '#FF5722',
  [GoalCategory.LEARNING]: '#4CAF50',
  [GoalCategory.FINANCE]: '#FFC107',
  [GoalCategory.SOCIAL]: '#9C27B0',
  [GoalCategory.FAMILY]: '#FF9800',
  [GoalCategory.GROWTH]: '#00BCD4',
  [GoalCategory.FUN]: '#E91E63'
};

// 应用配置
export const APP_NAME: string = '人生目标管理器';
export const VERSION: string = '1.0.0';
