import { GoalCategory } from '../models/Goal';
import Resource from '@ohos.app.ability.common';

export interface CategoryInfo {
  value: GoalCategory;
  label: string;
  color: string;
  icon: string;
}
// 4 大生活维度配置
export const CATEGORIES: CategoryInfo[] = [
  { value: GoalCategory.HEALTH, label: '健康', color: '#52C41A', icon: 'health' },
  { value: GoalCategory.LEARNING, label: '成长', color: '#FA8C16', icon: 'growth' },
  { value: GoalCategory.FINANCE, label: '理财', color: '#722ED1', icon: 'finance' },
  { value: GoalCategory.FUN, label: '快乐', color: '#F5222D', icon: 'joy' }
];
// 分类颜色映射
export const CATEGORY_COLORS: Record<GoalCategory, string> = {
  [GoalCategory.HEALTH]: '#52C41A',
  [GoalCategory.LEARNING]: '#FA8C16',
  [GoalCategory.FINANCE]: '#722ED1',
  [GoalCategory.FUN]: '#F5222D'
};

// 分类背景图片映射
export const CATEGORY_IMAGES: Record<GoalCategory, Resource> = {
  [GoalCategory.HEALTH]: $r('app.media.goal_health'),
  [GoalCategory.LEARNING]: $r('app.media.learning'),
  [GoalCategory.FINANCE]: $r('app.media.finance'),
  [GoalCategory.FUN]: $r('app.media.entertainment')
};

// 应用配置
export const APP_NAME: string = '四时清单';
export const VERSION: string = '1.0.0';
