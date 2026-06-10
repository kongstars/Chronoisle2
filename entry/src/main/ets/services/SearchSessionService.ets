import { Task, TaskData } from '../models/Task';

class SearchSessionService {
  private taskResultsByQuery: Map<string, Task[]> = new Map();
  private taskResultsBySearchId: Map<string, Task[]> = new Map();

  private cloneTask(task: Task): Task {
    return Task.fromJSON(JSON.parse(JSON.stringify(task)) as TaskData);
  }

  private cloneTasks(tasks: Task[]): Task[] {
    return tasks.map((task: Task) => this.cloneTask(task));
  }

  setTaskResults(query: string, tasks: Task[]): void {
    this.taskResultsByQuery.set(query.trim().toLowerCase(), this.cloneTasks(tasks));
  }

  createTaskSearchSession(tasks: Task[]): string {
    const searchId = `search_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    this.taskResultsBySearchId.set(searchId, this.cloneTasks(tasks));
    return searchId;
  }

  getTaskResults(query: string): Task[] | undefined {
    const normalizedQuery = query.trim().toLowerCase();
    const tasks = this.taskResultsByQuery.get(normalizedQuery);
    if (!tasks) {
      return undefined;
    }
    return this.cloneTasks(tasks);
  }

  getTaskResultsBySearchId(searchId: string): Task[] | undefined {
    const tasks = this.taskResultsBySearchId.get(searchId);
    if (!tasks) {
      return undefined;
    }
    return this.cloneTasks(tasks);
  }

  clearTaskResults(query?: string): void {
    if (query === undefined) {
      this.taskResultsByQuery.clear();
      return;
    }
    this.taskResultsByQuery.delete(query.trim().toLowerCase());
  }

  clearTaskSearchSession(searchId: string): void {
    this.taskResultsBySearchId.delete(searchId);
  }
}

export const searchSessionService = new SearchSessionService();
