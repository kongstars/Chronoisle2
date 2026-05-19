import { GoalCategory } from '../models/Goal';

export interface GoalTypeInfo {
  category: GoalCategory;
  title: string;
  subtitle: string;
  description: string;
  color: string;
  icon: string;
  image: ResourceStr;
}

export const GOAL_TYPES: GoalTypeInfo[] = [
  { category: GoalCategory.HEALTH, title: '健康', subtitle: '运动、作息、饮食', description: '建立更稳定的身心状态', color: '#34C759', icon: 'health', image: $r('app.media.goal_health') },
  { category: GoalCategory.LEARNING, title: '成长', subtitle: '学习、技能、阅读', description: '持续积累长期复利能力', color: '#007AFF', icon: 'growth', image: $r('app.media.learning') },
  { category: GoalCategory.FINANCE, title: '理财', subtitle: '收入、储蓄、预算', description: '让资金安排更清晰可控', color: '#FF9500', icon: 'finance', image: $r('app.media.finance') },
  { category: GoalCategory.FUN, title: '快乐', subtitle: '兴趣、旅行、社交', description: '为生活加入期待和能量', color: '#AF52DE', icon: 'joy', image: $r('app.media.entertainment') }
];
