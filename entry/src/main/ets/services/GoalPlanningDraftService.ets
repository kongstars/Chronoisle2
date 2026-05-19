import dataPreferences from '@ohos.data.preferences';
import { PlanningSession, touchPlanningSession } from '../models/PlanningSession';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('GoalPlanningDraftService');

const PREF_NAME = 'chronoisle_planning_drafts';
const DRAFT_EXPIRE_MS = 48 * 60 * 60 * 1000;

export class GoalPlanningDraftService {
  private static instance: GoalPlanningDraftService;
  private preferences: dataPreferences.Preferences | null = null;

  private constructor() {}

  public static getInstance(): GoalPlanningDraftService {
    if (!GoalPlanningDraftService.instance) {
      GoalPlanningDraftService.instance = new GoalPlanningDraftService();
    }
    return GoalPlanningDraftService.instance;
  }

  async init(context: Context): Promise<void> {
    try {
      if (this.preferences === null) {
        this.preferences = await dataPreferences.getPreferences(context, PREF_NAME);
      }
    } catch (e) {
      logger.error('GoalPlanningDraftService init error', e as Object);
      throw new Error('GoalPlanningDraftService init failed');
    }
  }

  isInitialized(): boolean {
    return this.preferences !== null;
  }

  private async ensureReady(): Promise<dataPreferences.Preferences> {
    if (!this.preferences) {
      throw new Error('GoalPlanningDraftService has not been initialized');
    }
    return this.preferences;
  }

  async saveDraft(session: PlanningSession): Promise<void> {
    try {
      const prefs = await this.ensureReady();
      await this.cleanupExpiredDrafts();
      touchPlanningSession(session);
      await prefs.put(session.sessionId, JSON.stringify(session));
      await prefs.flush();
    } catch (e) {
      logger.error('GoalPlanningDraftService saveDraft error', e as Object);
      throw new Error('GoalPlanningDraftService saveDraft failed');
    }
  }

  async loadDraft(sessionId: string): Promise<PlanningSession | null> {
    try {
      const prefs = await this.ensureReady();
      const draftStr = await prefs.get(sessionId, '') as string;
      if (!draftStr) return null;
      const draft = JSON.parse(draftStr) as PlanningSession;
      if (Date.now() - draft.updatedAt >= DRAFT_EXPIRE_MS || draft.status !== 'active') {
        await this.deleteDraft(sessionId);
        return null;
      }
      return draft;
    } catch (e) {
      logger.error('GoalPlanningDraftService loadDraft parse error', e as Object);
      return null;
    }
  }
  async listDrafts(): Promise<PlanningSession[]> {
    try {
      const prefs = await this.ensureReady();
      const allKeys = await prefs.getAll() as Record<string, string>;
      const drafts: PlanningSession[] = [];
      const entries = Object.entries(allKeys);
      for (let i = 0; i < entries.length; i++) {
        const entry = entries[i];
        const key = entry[0];
        const value = entry[1];
        try {
          const draft = JSON.parse(value as string) as PlanningSession;
          if (Date.now() - draft.updatedAt < DRAFT_EXPIRE_MS && draft.status === 'active') {
            drafts.push(draft);
          }
        } catch (e) {
          logger.warn('GoalPlanningDraftService listDrafts parse error: ${key}');
        }
      }

      return drafts.sort((a, b) => b.updatedAt - a.updatedAt);
    } catch (e) {
      logger.error('GoalPlanningDraftService listDrafts error', e as Object);
      return [];
    }
  }

  async deleteDraft(sessionId: string): Promise<void> {
    const prefs = await this.ensureReady();
    try {
      await prefs.delete(sessionId);
      await prefs.flush();
    } catch (e) {
      logger.warn('GoalPlanningDraftService deleteDraft failed: ${sessionId}');
    }
  }

  private async cleanupExpiredDrafts(): Promise<void> {
    try {
      const prefs = await this.ensureReady();
      const allKeys = await prefs.getAll() as Record<string, string>;
      let modified = false;
      const entries = Object.entries(allKeys);
      for (let i = 0; i < entries.length; i++) {
        const entry = entries[i];
        const key = entry[0];
        const value = entry[1];
        try {
          const draft = JSON.parse(value as string) as PlanningSession;
          if (Date.now() - draft.updatedAt >= DRAFT_EXPIRE_MS || draft.status !== 'active') {
            await prefs.delete(key);
            modified = true;
          }
        } catch (e) {
          await prefs.delete(key);
          modified = true;
        }
      }

      if (modified) {
        await prefs.flush();
      }
    } catch (e) {
      logger.error('GoalPlanningDraftService cleanupExpiredDrafts error', e as Object);
    }
  }
}

export const draftService = GoalPlanningDraftService.getInstance();
