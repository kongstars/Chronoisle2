import { GoalCategory as AppGoalCategory } from './Goal';

export type GoalCategory = AppGoalCategory;

export interface PlanningApiResponse<T> {
  success: boolean;
  data?: T;
  message?: string;
}

export interface GoalDraft {
  title: string;
  description: string;
  category: string;
  motivation?: string;
  periodDays: number;
  goalKind?: string;
  confidence?: number;
  missingFields?: string[];
}

// ===== 澄清阶段 =====
// 与后端 normalizeQuestion 输出严格对齐
export interface ClarificationQuestion {
  id: string;
  text: string;
  type: 'single_choice' | 'multi_choice' | 'short_text' | 'number' | 'date';
  options?: string[];
  placeholder?: string;
  required?: boolean;
}

export interface Clarification {
  questions: ClarificationQuestion[];
  answers: Record<string, string>;
  completenessScore: number;
}

// ===== 难度评估 =====
export interface GoalAssessment {
  level: 'easy' | 'moderate' | 'hard' | 'very_hard';
  summary: string;
  recommendedTrackCount: number;
  shouldReviseGoal?: boolean;
  blockingWarning?: string;
}

// ===== 进度追踪 =====
export interface ProgressTrack {
  id: string;
  title: string;
  type: string;
  unit: string;
  targetValue: number;
  currentValue?: number;
  baselineValue?: number;
  dueDate?: number;
  completionCriteria: string;
  checkpointText?: string;
  reason?: string;
}

export interface UserFacingIssue {
  id: string;
  kind: string;
  severity: 'low' | 'medium' | 'high';
  title: string;
  reason: string;
  suggestion: string;
  targetTrackId?: string;
  inputMode: 'number' | 'short_text';
  inputLabel: string;
  inputPlaceholder: string;
  impactScope: string;
  aiHint: string;
}

export interface CriticIssue {
  severity: 'low' | 'medium' | 'high';
  description: string;
  suggestion?: string;
  module?: string;
  trackId?: string;
}

export interface ProgressPlan {
  tracks: ProgressTrack[];
  criticPassed?: boolean;
  criticIssues?: CriticIssue[];
  userFacingIssues?: UserFacingIssue[];
  userInterventionUsed?: boolean;
  assessment?: GoalAssessment;
  fallbackUsed?: boolean;
}

// ===== 行动方案 =====
export interface OneOffTask {
  title: string;
  description?: string;
  priority?: 'low' | 'medium' | 'high';
  estimatedHours?: number;
  suggestedDueDate?: number;
}

export interface RecurringAction {
  title: string;
  description?: string;
  cadence?: string;
  reminderTime?: string;
  rule?: 'daily' | 'weekly' | 'monthly';
  weekdays?: number[];
  timeParams?: Array<string | number>;
  endDate?: string;
}

export interface CountdownItem {
  title: string;
  targetDate: string;
  description?: string;
}

export interface ActionPlan {
  oneOffTasks: OneOffTask[];
  recurringActions: RecurringAction[];
  countdowns: CountdownItem[];
  focusSuggestions?: string[];
}

export interface AutomationPlan {
  reminders: RecurringAction[];
  countdowns: CountdownItem[];
  conflicts?: AutomationConflict[];
}

export interface AutomationConflict {
  type: string;
  message: string;
  level: string;
}

// ===== 质量报告 =====
export interface QualityReport {
  passed?: boolean;
  overallScore: number;
  summary: string;
  suggestions?: string[];
  issues: CriticIssue[];
  needsUserAttention?: string[];
}

// ===== 运行时状态 =====
export interface RuntimeStatus {
  phase: string;
  stepKey: string;
  currentStep: number;
  totalSteps: number;
  title: string;
  description: string;
  estimatedMs: number;
  startedAt: number;
  active?: boolean;
  stage?: string;
  subStepKey?: string;
  subStepIndex?: number;
  subStepTotal?: number;
  estimatedRemainingMs?: number;
  updatedAt?: number;
  isSlow?: boolean;
}

// ===== 完整规划会话（与后端 MongoDB Schema 严格对齐）=====
export interface PlanningSession {
  sessionId: string;
  userId?: string;
  source: 'create_goal' | 'enhance_goal';
  targetGoalId?: string;
  rawIntent?: string;
  stage?: 'understanding' | 'clarifying' | 'progress' | 'actions' | 'review' | 'saving' | 'completed' | 'error';
  status?: 'active' | 'paused' | 'completed' | 'abandoned';
  goalDraft?: GoalDraft;
  clarification?: Clarification;
  goalAssessment?: GoalAssessment;
  progressPlan?: ProgressPlan;
  actionPlan?: ActionPlan;
  automationPlan?: AutomationPlan;
  qualityReport?: QualityReport;
  runtimeStatus?: RuntimeStatus;
  createdAt: number;
  updatedAt: number;
}

export interface ApplyResult {
  success: boolean;
  message?: string;
  goalId?: string;
  createdTrackTitles?: string[];
  createdTaskIds?: string[];
  createdReminderIds?: string[];
  failedParts?: Array<'goal' | 'progress' | 'tasks' | 'reminders' | 'countdowns'>;
}

export function touchPlanningSession(session: PlanningSession): PlanningSession {
  session.updatedAt = Date.now();
  return session;
}

export function getTrackTypeLabel(type: string): string {
  return type;
}

export function getTrackTypeIcon(_type: string): string {
  return 'progress';
}
