import { GoalCategory } from '../models/Goal';
import Resource from '@ohos.app.ability.common';

export interface CategoryInfo {
  value: GoalCategory;
  label: string;
  color: string;
  icon: string;
}

export const CATEGORY_HEALTH_COLOR: string = '#59B294';
export const CATEGORY_LEARNING_COLOR: string = '#F1A765';
export const CATEGORY_FINANCE_COLOR: string = '#9A96FF';
export const CATEGORY_FUN_COLOR: string = '#D978A6';

// 4 大生活维度配置
export const CATEGORIES: CategoryInfo[] = [
  { value: GoalCategory.HEALTH, label: '健康', color: CATEGORY_HEALTH_COLOR, icon: 'health' },
  { value: GoalCategory.LEARNING, label: '成长', color: CATEGORY_LEARNING_COLOR, icon: 'growth' },
  { value: GoalCategory.FINANCE, label: '理财', color: CATEGORY_FINANCE_COLOR, icon: 'finance' },
  { value: GoalCategory.FUN, label: '快乐', color: CATEGORY_FUN_COLOR, icon: 'joy' }
];
// 分类颜色映射
export const CATEGORY_COLORS: Record<GoalCategory, string> = {
  [GoalCategory.HEALTH]: CATEGORY_HEALTH_COLOR,
  [GoalCategory.LEARNING]: CATEGORY_LEARNING_COLOR,
  [GoalCategory.FINANCE]: CATEGORY_FINANCE_COLOR,
  [GoalCategory.FUN]: CATEGORY_FUN_COLOR
};

// 分类背景图片映射
export const CATEGORY_IMAGES: Record<GoalCategory, Resource> = {
  [GoalCategory.HEALTH]: $r('app.media.goal_health'),
  [GoalCategory.LEARNING]: $r('app.media.learning'),
  [GoalCategory.FINANCE]: $r('app.media.finance'),
  [GoalCategory.FUN]: $r('app.media.entertainment')
};

export type GoalCategoryIconVariant = 'selected' | 'muted';

export function getGoalCategoryIconResource(
  category: GoalCategory,
  variant: GoalCategoryIconVariant = 'selected'
): Resource {
  switch (category) {
    case GoalCategory.HEALTH:
      return variant === 'selected'
        ? $r('app.media.app_icon_health_selected')
        : $r('app.media.app_icon_health_muted');
    case GoalCategory.LEARNING:
      return variant === 'selected'
        ? $r('app.media.app_icon_growth_selected')
        : $r('app.media.app_icon_growth_muted');
    case GoalCategory.FINANCE:
      return variant === 'selected'
        ? $r('app.media.app_icon_finance_selected')
        : $r('app.media.app_icon_finance_muted');
    case GoalCategory.FUN:
      return variant === 'selected'
        ? $r('app.media.app_icon_joy_selected')
        : $r('app.media.app_icon_joy_muted');
    default:
      return variant === 'selected'
        ? $r('app.media.app_icon_goal_selected')
        : $r('app.media.app_icon_goal');
  }
}

// 应用配置
export const APP_NAME: string = '四时清单';
export const VERSION: string = '1.0.0';
