import http from '@ohos.net.http';
import AppConfig from '../Utils/AppConfig';
import { db } from '../storage/Database';
import { SimilarityUtils } from '../Utils/SimilarityUtils';
import { TokenService } from './TokenService';
import { authService } from './AuthService';
import { Task } from '../models/Task';
import { Goal, KeyResult } from '../models/Goal';
import { TelemetryProperties } from '../services/TelemetryService';
import { TelemetryService } from './TelemetryService';
import { TelemetryErrorCode } from '../models/TelemetryErrorCode';
import { AppErrorService } from './AppErrorService';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('AgentService');

export interface MatchedKrItem {
  krId: string;
  krTitle: string;
}
export interface AgentIntent {
  intent: 'todo' | 'focus' | 'clarify' | 'ignore';
  confidence: number;
  title_candidate?: string;
  description?: string;
  focus_subject?: string;
  duration_minutes?: number;
  clarification_question?: string;
  priority?: 'high' | 'normal' | 'low';
  suggested_goal_id?: string;
  suggested_kr_id?: string;
  due_date?: string;
}
interface RequestInput {
  prompt: string;
}

interface RequestParameters {
  result_format: string;
}

interface RequestBody {
  input: RequestInput;
  parameters: RequestParameters;
  app_id?: string;
}
export interface SimilarTaskItem {
  task: Task;
  score: number;
}

export interface MatchedGoalItem {
  goal: Goal;
  score: number;
}
export interface MatchedTaskForFocusItem {
  task: Task;
  score: number;
}
interface ApiResponseOutput {
  text?: string;
  choices?: ApiResponseChoice[];
}
interface ApiResponseMessage {
  content: string;
}

interface ApiResponseChoice {
  message?: ApiResponseMessage;
}

interface ApiResponse {
  output?: ApiResponseOutput;
}

interface ApiEnvelope<T> {
  success?: boolean;
  data?: T;
  message?: string;
}

export interface MatchResult {
  hasSimilar: boolean;
  similarTasks: SimilarTaskItem[];
  matchedGoal?: MatchedGoalItem;
  matchedKr?: MatchedKrItem;
  matchedTaskForFocus?: MatchedTaskForFocusItem;
}

export interface AgentProcessResult {
  parsed: AgentIntent;
  match?: MatchResult;
}

export interface TaskAutoFillIntent {
  normalized_title?: string;
  description: string;
  priority: string;
  suggested_goal_id?: string;
  suggested_kr_id?: string;
  due_date?: string;
}

export interface TaskAutoFillResult {
  filled: TaskAutoFillIntent;
  similarTasks: SimilarTaskItem[];
  matchedGoal?: MatchedGoalItem;
  matchedKr?: MatchedKrItem;
}

export class AgentService {
  private static readonly MATCH_THRESHOLD_HIGH = 0.85;
  private static readonly MATCH_THRESHOLD_LOW = 0.5;

  private static async buildHttpErrorMessage(responseCode: number, responseBody: string, path: string): Promise<string> {
    const message = AppErrorService.fromResponse(responseCode, responseBody);
    if (responseCode === 401) {
      await authService.handleUnauthorizedState(message, path);
    }
    return message;
  }

  private static buildActiveGoalsPrompt(): string {
    const activeGoals = db.getActiveGoals();
    if (activeGoals.length === 0) {
      return '当前系统无任何已配置的目标或关键结果。';
    }
    let listStr = '以下是当前用户的活跃目标及关键结果列表（请精准提取ID，若无关请留空）：\n';
    activeGoals.forEach(goal => {
      listStr += `- [目标 ID: ${goal.id}] 名称: ${goal.title}\n`;
      if (goal.keyResults && goal.keyResults.length > 0) {
        goal.keyResults.forEach((kr: KeyResult) => {
          listStr += `    - [KR ID: ${kr.id}] KR标题: ${kr.title}\n`;
        });
      }
    });
    return listStr;
  }

  /**
   * 将用户输入发送至百炼大模型进行意图理解与结构化提取
   */
  public static async analyzeInput(userInput: string): Promise<AgentIntent> {
    const currentTime = new Date().toLocaleString();
    const goalsListDesc = AgentService.buildActiveGoalsPrompt();
    const promptParams = `
你是一个任务解析助手。请根据用户输入，判断其意图是创建“代办任务 (todo)”、创建“专注/番茄 (focus)”、需要澄清 (clarify)，或忽略 (ignore)。

当前系统时间：${currentTime}
${goalsListDesc}

请严格直接输出 JSON，不要输出任何额外解释语。

规则：
1. 若用户表达未来要完成的事项，输出 intent="todo"。若包含时间，请结合当前时间计算为标准日期时间(如 YYYY-MM-DD 或 YYYY-MM-DD HH:mm:ss)。
2. 结合给出的目标列表，选出最符合上下文的目标ID和KR ID。不可凭空捏造ID。若皆不符合，必须留空。

输出字段格式：
{
  "intent": "todo | focus | clarify | ignore",
  "confidence": 0.95,
  "title_candidate": "代办短标题(8-20字)，如为todo",
  "description": "任务的补充描述或原始输入，如为todo",
  "priority": "high | normal | low",
  "due_date": "如为todo，预测的计划完成时间字符串，若未提及留空字符串",
  "suggested_goal_id": "相关联的目标ID，否则留空",
  "suggested_kr_id": "相关联的KR ID，否则留空",
  "focus_subject": "如果是专注，提炼要专注的核心事项",
  "duration_minutes": 25,
  "clarification_question": "如果是clarify，你要反问用户的问题"
}

用户输入：${userInput}
`;

    // 从 Server 处获取 token，并加上鉴权头
    const httpRequest = http.createHttp();
    const token = await authService.getToken();
    const requestBody: RequestBody = {
      input: {
        prompt: promptParams
      } as RequestInput,
      parameters: {
        result_format: "message" // Bailian SDK format
      } as RequestParameters
    };
    const headerObj: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    if (token) {
      headerObj['Authorization'] = `Bearer ${token}`;
    }
    try {
      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/api/agent/completion`,
        {
          method: http.RequestMethod.POST,
          header: headerObj,
          extraData: JSON.stringify(requestBody),
          connectTimeout: 15000,
          readTimeout: 60000
        }
      );
      if (response.responseCode === 200) {
        const result: ApiResponse = JSON.parse(response.result as string);
        let contentStr = '';
        if (result && result.output) {
          if (result.output.text) {
            contentStr = result.output.text;
          } else if (result.output.choices && result.output.choices[0] && result.output.choices[0].message) {
            contentStr = result.output.choices[0].message.content;
          }
        }

        if (contentStr) {
          // 移除所有 markdown 标记并尝试提取 JSON
          contentStr = contentStr.replace(/```json/g, '').replace(/```/g, '').trim();
          const startIdx = contentStr.indexOf('{');
          const endIdx = contentStr.lastIndexOf('}');
          if (startIdx >= 0 && endIdx >= startIdx) {
            contentStr = contentStr.substring(startIdx, endIdx + 1);
          }
          
          try {
            const parsedIntent: AgentIntent = JSON.parse(contentStr);
            return parsedIntent;
          } catch (jsonErr) {
            logger.error('JSON Parse Error for Agent Response:', contentStr as Object);
            (() => { let _p: TelemetryProperties = { 
              "code": TelemetryErrorCode.ERR_AI_JSON_PARSE_FAIL, 
              "msg": String(jsonErr).substring(0, 50),
              "path": 'analyzeInput'
            }; TelemetryService.track('api_error', _p, 'ai'); })();
            return {
              intent: 'ignore',
              confidence: 1.0,
              clarification_question: '大模型返回结果内容异常，无法解析，请精简或修改内容后重试。'
            };
          }
        } else {
            logger.error('Agent API returned unexpected structure', result as Object);
            (() => { let _p: TelemetryProperties = { 'code': TelemetryErrorCode.ERR_AI_INVALID_STRUCTURE, 'msg': 'No content in output', 'path': 'analyzeInput'
             }; TelemetryService.track('api_error', _p, 'ai'); })();
            return {
              intent: 'ignore',
              confidence: 1.0,
              clarification_question: '接口返回结构异常，未获取到有效回答，请稍后重试。'
            };
        }
      } else {
        let errMsg = await AgentService.buildHttpErrorMessage(
          response.responseCode,
          String(response.result),
          'agent/completion:analyze-input'
        );
        logger.error('Agent API Error:', errMsg as Object);
        (() => { let _p: TelemetryProperties = { 
          "code": TelemetryErrorCode.ERR_HTTP_EXCEPTION, 
          "msg": errMsg.substring(0, 50),
          "path": 'analyzeInput'
        }; TelemetryService.track('api_error', _p, 'ai'); })();
        return {
           intent: 'ignore',
           confidence: 1.0,
           clarification_question: `通信异常，请检查网络或避免输入敏感/无效内容。（${errMsg}）`
        };
      }
    } catch (error) {
      logger.error('analyzeInput err', error as Object);
      const errMsg = AppErrorService.fromUnknown(error, 'AI 请求失败，请稍后重试');
      (() => { let _p: TelemetryProperties = { 
        "code": TelemetryErrorCode.ERR_NET_TIMEOUT, 
        "msg": errMsg.substring(0, 50),
        "path": 'analyzeInput'
      }; TelemetryService.track('api_error', _p, 'ai'); })();
       return {
         intent: 'ignore',
         confidence: 1.0,
         clarification_question: `网络异常或请求超时，请稍后重试。（${errMsg}）`
      };
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * 处理用户输入，包括大模型意图提取和本地业务匹配
   */
  public static async processUserInput(userInput: string): Promise<AgentProcessResult> {
    // 1. 调用大模型解析意图
    const parsedIntent = await AgentService.analyzeInput(userInput);
    // 2. 如果置信度低或需要澄清，直接返回，不走本地匹配
    if (parsedIntent.intent === 'clarify' || parsedIntent.intent === 'ignore' || parsedIntent.confidence < 0.70) {
      const result: AgentProcessResult = { parsed: parsedIntent };
      return result;
    }

    const matchResult: MatchResult = {
      hasSimilar: false,
      similarTasks: [],
    };
    // 3. 针对不同意图，执行本地相似度算法匹配
    const pendingTasks = db.getPendingTasks();
    const activeGoals = db.getActiveGoals();

    // 提前声明变量以避免控制流分析问题
    let matchedGoal: Goal | undefined = undefined;
    let bestGoalScore = 0;

    if (parsedIntent.intent === 'todo') {
      const searchTarget = parsedIntent.title_candidate || userInput;
      // a. 寻找相似代办
      const taskScores = pendingTasks.map(task => {
        const score = SimilarityUtils.calculateSimilarity(searchTarget, task.title);
        const similarTask: SimilarTaskItem = { task, score };
        return similarTask;
      }).filter(item => item.score > AgentService.MATCH_THRESHOLD_LOW)
        .sort((a, b) => b.score - a.score);

      matchResult.similarTasks = taskScores.slice(0, 3); // 最多保留前3个
      matchResult.hasSimilar = matchResult.similarTasks.length > 0;

      // b. 寻找最合适的目标 (Goal)
      if (parsedIntent.suggested_goal_id) {
        matchedGoal = activeGoals.find(g => g.id === parsedIntent.suggested_goal_id);
        if (matchedGoal) {
          const matchedGoalItem: MatchedGoalItem = { goal: matchedGoal, score: 1.0 };
          matchResult.matchedGoal = matchedGoalItem;

          // c. 匹配 KR
          if (parsedIntent.suggested_kr_id) {
            const matchedKr = matchedGoal.keyResults.find((kr: KeyResult) => kr.id === parsedIntent.suggested_kr_id);
            if (matchedKr) {
              matchResult.matchedKr = { krId: matchedKr.id, krTitle: matchedKr.title };
            }
          }
        }
      }

    } else if (parsedIntent.intent === 'focus') {
      // 寻找关联专注主题的任务
      const searchTarget = parsedIntent.focus_subject || userInput;
      
      let bestTaskScore = 0;
      let matchedTask: Task | undefined = undefined;

      pendingTasks.forEach(task => {
        const score = SimilarityUtils.calculateSimilarity(searchTarget, task.title);
        if (score > bestTaskScore && score > AgentService.MATCH_THRESHOLD_LOW) {
           bestTaskScore = score;
           matchedTask = task;
        }
      });
      if (matchedTask) {
        const matchedTaskItem: MatchedTaskForFocusItem = { task: matchedTask, score: bestTaskScore };
        matchResult.matchedTaskForFocus = matchedTaskItem;
      }
    }

    return {
      parsed: parsedIntent,
      match: matchResult
    };
  }

  /**
   * 创建任务时的 AI 辅助补全：根据标题自动生成描述、优先级建议，并匹配相似任务和目标
   */
  public static async autoFillTask(titleInput: string): Promise<TaskAutoFillResult> {
    const currentTime = new Date().toLocaleString();
    const goalsListDesc = AgentService.buildActiveGoalsPrompt();
    const promptParams = `
你是一个任务管理助手。用户正在创建一个代办任务，已输入了代办标题。
请根据标题，帮助用户补全任务信息。

当前系统时间：${currentTime}
${goalsListDesc}

请严格输出 JSON，不要输出任何额外解释。

规则：
- normalized_title 必须书面化、可执行，不要保留“今天/明天/后天/下周三/本周五”等相对时间字样。
- 如果用户原话里包含时间信息，应优先写入 due_date，而不是留在标题里。
- due_date 必须严格基于当前系统时间换算成准确日期；例如当前是 2026-06-08（周一）时，“下周三”应换算为 2026-06-17，而不是本周三。
- 如果只提到了日期未提具体时刻，due_date 只返回 YYYY-MM-DD；只有用户明确说了几点几分，才返回带时间的格式。

输出字段格式：
{
  "normalized_title": "将口语化标题规整成书面化、可执行的任务标题（8-24字，不要加句号）",
  "description": "根据标题生成一段简洁实用的任务描述（30-80字），帮助用户后续执行",
  "priority": "high | normal | low",
  "suggested_goal_id": "相关联的目标ID，否则留空",
  "suggested_kr_id": "相关联的KR ID，否则留空",
  "due_date": "预测的计划完成时间字符串(YYYY-MM-DD 或 YYYY-MM-DD HH:mm:ss)，若未提及留空字符串"
}

代办标题：${titleInput}
`;

    const httpRequest = http.createHttp();
    const token = await authService.getToken();
    const requestBody: RequestBody = {
      input: {
        prompt: promptParams
      } as RequestInput,
      parameters: {
        result_format: "message"
      } as RequestParameters
    };
    const headerObj: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    if (token) {
      headerObj['Authorization'] = `Bearer ${token}`;
    }

    let filled: TaskAutoFillIntent = {
      normalized_title: '',
      description: '',
      priority: 'normal',
      suggested_goal_id: '',
      suggested_kr_id: '',
      due_date: ''
    };
    try {
      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/api/agent/completion`,
        {
          method: http.RequestMethod.POST,
          header: headerObj,
          extraData: JSON.stringify(requestBody),
          connectTimeout: 15000,
          readTimeout: 60000
        }
      );
      if (response.responseCode === 200) {
        const result: ApiResponse = JSON.parse(response.result as string);
        let contentStr = '';
        if (result && result.output) {
          if (result.output.text) {
            contentStr = result.output.text;
          } else if (result.output.choices && result.output.choices[0] && result.output.choices[0].message) {
            contentStr = result.output.choices[0].message.content;
          }
        }
        if (contentStr) {
          contentStr = contentStr.replace(/```json/g, '').replace(/```/g, '').trim();
          const startIdx = contentStr.indexOf('{');
          const endIdx = contentStr.lastIndexOf('}');
          if (startIdx >= 0 && endIdx >= startIdx) {
            contentStr = contentStr.substring(startIdx, endIdx + 1);
          }
          try {
            filled = JSON.parse(contentStr) as TaskAutoFillIntent;
          } catch (e) {
            logger.error('JSON Parse Error for autoFillTask:', contentStr as Object);
            (() => { let _p: TelemetryProperties = { 
              "code": TelemetryErrorCode.ERR_AI_JSON_PARSE_FAIL, 
              "msg": String(e).substring(0, 50),
              "path": 'autoFillTask'
            }; TelemetryService.track('api_error', _p, 'ai'); })();
          }
        }
      } else {
        const errMsg = await AgentService.buildHttpErrorMessage(
          response.responseCode,
          String(response.result),
          'agent/completion:auto-fill-task'
        );
        logger.error('autoFillTask HTTP Error:', errMsg as Object);
      }
    } catch (error) {
      logger.error('autoFillTask LLM err:', error as Object);
      (() => { let _p: TelemetryProperties = { 
        "code": TelemetryErrorCode.ERR_NET_TIMEOUT, 
        "msg": JSON.stringify(error).substring(0, 50),
        "path": 'autoFillTask'
      }; TelemetryService.track('api_error', _p, 'ai'); })();
      // LLM 失败不阻断流程，继续走本地匹配
    } finally {
      httpRequest.destroy();
    }

    // 本地相似任务匹配
    const pendingTasks = db.getPendingTasks();
    const taskScores = pendingTasks.map((task: Task) => {
      const score = SimilarityUtils.calculateSimilarity(titleInput, task.title);
      const similarTask: SimilarTaskItem = { task, score };
      return similarTask;
    }).filter((item: SimilarTaskItem) => item.score > AgentService.MATCH_THRESHOLD_LOW)
      .sort((a: SimilarTaskItem, b: SimilarTaskItem) => b.score - a.score)
      .slice(0, 5);

    // 本地目标匹配
    const activeGoals = db.getActiveGoals();
    let matchedGoal: Goal | undefined = undefined;

    const autoFillResult: TaskAutoFillResult = {
      filled: filled,
      similarTasks: taskScores
    };
    if (filled.suggested_goal_id) {
      matchedGoal = activeGoals.find((g: Goal) => g.id === filled.suggested_goal_id);
      if (matchedGoal) {
        const matchedGoalItem: MatchedGoalItem = { goal: matchedGoal, score: 1.0 };
        autoFillResult.matchedGoal = matchedGoalItem;

        // 如果匹配到目标，尝试匹配该目标下的 KR
        if (filled.suggested_kr_id) {
          const matchedKr = matchedGoal.keyResults.find((kr: KeyResult) => kr.id === filled.suggested_kr_id);
          if (matchedKr) {
            autoFillResult.matchedKr = { krId: matchedKr.id, krTitle: matchedKr.title };
          }
        }
      }
    }

    return autoFillResult;
  }

  private static async callAgentAPI<T>(prompt: string, defaultVal: T, appId?: string): Promise<T> {
    const httpRequest = http.createHttp();
    const token = await authService.getToken();
    const requestBody: RequestBody = {
      input: { prompt } as RequestInput,
      parameters: { result_format: "message" } as RequestParameters
    };
    if (appId) {
      requestBody.app_id = appId;
    }
    const headerObj: Record<string, string> = { 'Content-Type': 'application/json' };
    if (token) {
      headerObj['Authorization'] = `Bearer ${token}`;
    }

    try {
      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/api/agent/completion`,
        {
          method: http.RequestMethod.POST,
          header: headerObj,
          extraData: JSON.stringify(requestBody),
          connectTimeout: 15000,
          readTimeout: 120000
        }
      );
      if (response.responseCode === 200) {
        const result: ApiResponse = JSON.parse(response.result as string);
        let contentStr = '';
        if (result?.output?.text) {
          contentStr = result.output.text;
        } else if (result?.output?.choices?.[0]?.message?.content) {
          contentStr = result.output.choices[0].message.content;
        }
        if (contentStr) {
          contentStr = contentStr.replace(/```json/gi, '').replace(/```/g, '').trim();
          const startIdx = contentStr.indexOf('{');
          const endIdx = contentStr.lastIndexOf('}');
          if (startIdx >= 0 && endIdx >= startIdx) {
            contentStr = contentStr.substring(startIdx, endIdx + 1);
          }
          try {
            return JSON.parse(contentStr) as T;
          } catch (e) {
            logger.error('callAgentAPI JSON Parse Error:', contentStr as Object);
            (() => { let _p: TelemetryProperties = { 
              "code": TelemetryErrorCode.ERR_AI_JSON_PARSE_FAIL, 
              "msg": String(e).substring(0, 50),
              "path": 'callAgentAPI'
            }; TelemetryService.track('api_error', _p, 'ai'); })();
            if (typeof defaultVal === 'object' && defaultVal !== null) {
              const obj = defaultVal as ErrorMsgContainer;
              if (obj.errorMsg !== undefined) {
              obj.errorMsg = AppErrorService.fromUnknown(e as Error, 'AI 返回内容解析失败');
              }
            }
          }
        } else {
          logger.error('callAgentAPI No Content in Response', result as Object);
          (() => { let _p: TelemetryProperties = { 'code': TelemetryErrorCode.ERR_AI_INVALID_STRUCTURE, 'msg': 'No content in response', 'path': 'callAgentAPI'
           }; TelemetryService.track('api_error', _p, 'ai'); })();
          if (typeof defaultVal === 'object' && defaultVal !== null) {
            const obj = defaultVal as ErrorMsgContainer;
            if (obj.errorMsg !== undefined) {
              obj.errorMsg = '902: AI 返回内容为空';
            }
          }
        }
      } else {
        logger.error('callAgentAPI HTTP Error:', response.responseCode, response.result as Object);
        (() => { let _p: TelemetryProperties = { 'code': TelemetryErrorCode.ERR_HTTP_EXCEPTION, 'msg': `HTTP ${response.responseCode}`, 'path': 'callAgentAPI'
         }; TelemetryService.track('api_error', _p, 'ai'); })();
        if (typeof defaultVal === 'object' && defaultVal !== null) {
          const obj = defaultVal as ErrorMsgContainer;
          if (obj.errorMsg !== undefined) {
            obj.errorMsg = await AgentService.buildHttpErrorMessage(
              response.responseCode,
              String(response.result),
              'agent/completion:call-agent-api'
            );
          }
        }
      }
    } catch (err) {
      logger.error('callAgentAPI fetch error', err as Object);
      (() => { let _p: TelemetryProperties = { 
        "code": TelemetryErrorCode.ERR_NET_TIMEOUT, 
        "msg": JSON.stringify(err).substring(0, 50),
        "path": 'callAgentAPI'
      }; TelemetryService.track('api_error', _p, 'ai'); })();
      if (typeof defaultVal === 'object' && defaultVal !== null) {
        const obj = defaultVal as ErrorMsgContainer;
        if (obj.errorMsg !== undefined) {
          obj.errorMsg = AppErrorService.fromUnknown(err as Error, 'AI 请求失败，请稍后重试');
        }
      }
    } finally {
      httpRequest.destroy();
    }
    return defaultVal;
  }

  /**
   * AI目标拆解：将用户输入的模糊目标拆解为 O-KR-Tasks
   * 无论信息是否充分，AI 都必须先基于常识给出一版保底草案，同时可选地提出追问
   */
  /**
   * AI目标澄清（第一阶段）：专门用于分析用户输入，并针对性提问
   */
  public static async clarifyGoal(intent: string, userInfo: string = ''): Promise<GoalClarifyResult> {
    const prompt = `
你是一个专业的 OKR 与目标管理教练。用户希望建立一个新目标：【${intent}】。
由于制定一份高质量的 OKR 需要清晰的背景信息（如当前状态、可用资源、时间周期或具体期望等），请你结合用户的意图分析，**提出1到2个最关键的核心问题**。

【重要防呆机制】
如果用户的意图仅仅是一件非常简单立刻能做完的具体事项（例如："买牛奶"、"定电影票"、"回复邮件"等），请不要过度拆解，直接返回 {"status": "simple_task"} 即可。

要求：
1. 语言要亲切、专业。
2. 问题本身要具有启发性，能帮助用户更清晰地定义目标。
3. **强制要求**：绝对不要输出任何额外的思考过程或解释文本！绝对不要使用 markdown 代码块（如 \`\`\`json）包裹！只允许输出大括号 {} 包裹的干净 JSON 字符串。
4. userInfo 是关于用户的额外补充信息（如有），供您参考：${userInfo}

输出 JSON 格式模板（请严格遵守并直接输出）：
{
2. **问题本身要具有启发性并且针对用户的具体目标，帮助用户更清晰地定义该目标的独有难点或期望**。
3. **强制要求**：绝对不要输出任何额外的思考过程或解释文本！绝对不要使用 markdown 代码块（如 \`\`\`json）包裹！只允许输出大括号 {} 包裹的干净 JSON 字符串。
4. userInfo 是关于用户的额外补充信息（如有），供您参考：${userInfo}

输出 JSON 格式模板（请严格遵守并直接输出）：
{
  "status": "success",
  "question": "<必须由你根据当前实际目标思考出的针对性追问内容，而不是固定例子。例如：当前您已经具备了相关的基础吗？期望用多久达成？...>"
}
`;
    // 若解析出错，按 error 返回
    const defaultRes: GoalClarifyResult = {
      status: 'error',
      errorMsg: '网络连接超时或回答异常，请重试'
    };
    // 目标拆解相关请求走专属更精准模型
    const APP_ID = '1e8563e9be1046fa9561b9ca550c7f3c';
    return await AgentService.callAgentAPI<GoalClarifyResult>(prompt, defaultRes, APP_ID);
  }

  /**
   * AI目标生成（第二阶段）：接收完整信息（包含补充回答），直接生成 OKR 草案
   */
  public static async breakdownGoal(intent: string, userInfo: string = ''): Promise<GoalBreakdownResult> {
    const prompt = `
你是一个专业的 OKR 与目标管理教练。用户希望建立一个新目标。
这是经过澄清后的用户意图与全部补充背景信息：【${intent}】。

请你制定：
1. 【1个 Objective】 (O)
2. 【2-4个 Key Results】 (KR)，并在每个 KR 下提供具体的待办任务 (tasks)
3. 【关联长期提醒】 (Reminders)，如果这个目标适合设置长期打卡或倒计时（例如：每天学英语、每周锻炼、考研倒计时等），请为它最多安排 1-2 条核心提醒。如果不需要则返回空数组 []。

要求：
1. **强制要求**：绝对不要输出任何额外的思考过程或解释文本！绝对不要使用 markdown 代码块！只允许输出大括号 {} 包裹的纯净 JSON 字符串。
2. 目标 O 应该简洁有力，富有启发性。
3. KR 必须可衡量，必须设定一个数字形式的 targetValue。
4. 任务 tasks 具体可执行，禁“泛化表达”，每个 KR 下 4-8 个 tasks。
5. 参考此玩家画像及水平设定难度：${userInfo}

输出 JSON 格式（直接输出，绝不要包含上下文废话）：
{
  "status": "success",
  "objective": "示例：3个月减重10斤",
  "keyResults": [
    {
      "title": "连续运动30天",
      "targetValue": 30,
      "tasks": ["挑选并购买适合慢跑的运动鞋", "制定并打印第一周的初阶跑课表", "完成第一次户外15分钟慢跑"]
    }
  ],
  "reminders": [
    {
      "title": "每周跑3次步",
      "category": "habit",
      "rule": "weekly",
      "timeParams": [1, 3, 5]
    },
    {
      "title": "距离期末考试",
      "category": "countdown",
      "rule": "target_date",
      "timeParams": ["2026-06-30"]
    }
  ]
}

关于 reminders 的属性说明:
- category: "habit" (习惯养成), "periodic" (常规周期提醒), "countdown" (重要倒计时/倒数日)。
- rule: 
  - 习惯/周期类："daily" (此时 timeParams 为 []), "weekly" (此时 timeParams 为数字数组 [1,2,3] 代表周几), "monthly" (此时 timeParams 为 [1] 代表某号);
  - 倒计时类："target_date" (此时 timeParams 为 ["YYYY-MM-DD"]).
`;
    const defaultRes: GoalBreakdownResult = {
      status: 'error',
      objective: '',
      keyResults: [],
      reminders: [],
      errorMsg: '网络连接超时或回答异常，请重试'
    };
    return await AgentService.callAgentAPI<GoalBreakdownResult>(prompt, defaultRes);
  }

  /**
   * AI今日计划：根据代办任务列表，为其挑选焦点任务、建议延期和总结。
   */
  public static async generateTodayPlan(pendingTasksSummary: string, intensity: 'light' | 'normal' | 'heavy' = 'normal'): Promise<TodayPlanResult> {
    // 简易解析计算待办数量，由于 pendingTasksSummary 是 JSON string
    let pendingCount = 5;
    try {
      const parsed = JSON.parse(pendingTasksSummary) as Object[];
      if (Array.isArray(parsed)) pendingCount = parsed.length;
    } catch(e) {}

    let intensityGuide = '';
    if (intensity === 'light') {
      intensityGuide = '用户当前希望【更轻松一点】。请尽量只提取 1~2 项最重要的核心任务放入 focusTasks，把其余绝大多数任务放入 deferTasks 建议推迟。';
    } else if (intensity === 'heavy') {
      const maxCount = Math.min(pendingCount, 7);
      const minCount = Math.min(pendingCount, 4);
      intensityGuide = `用户当前希望【更满排一点】。请在合理范围内最大化拉满今日负载，可以挑选 ${minCount}~${maxCount} 项任务进入 focusTasks，尽量少推迟任务。`;
    } else {
      let taskCountGuide = '请挑选出今天最重要、最需要先完成的 3 件左右焦点任务进入 focusTasks。';
      if (pendingCount <= 5) {
        taskCountGuide = '请挑选出最优先的 2~3 项核心焦点任务进入 focusTasks。';
      } else if (pendingCount > 10) {
        taskCountGuide = '由于待办数量较多，请根据实际情况动态安排 4~6 项高优焦点任务进入 focusTasks，以释放用户的生产力。';
      }
      intensityGuide = taskCountGuide;
    }

    const currentHour = new Date().getHours();
    const remainingHours = Math.max(24 - currentHour, 1);

    const prompt = `
你是一个精益时间管理专家。请根据用户的今日待办（包含 dueDate、isOverdue 和预估耗时 estimatedHours 等维度信息）的 JSON 汇总，为他制定一份【今日行动计划】。

要求：
1. ${intensityGuide}
2. \`focusTasks\` 必须补充 \`reason\`（简短一句话说明为什么优先，例如“因为今天到期”或“高优且已逾期”）。
3. \`groupedTasks\` 必须将所有的 \`focusTasks\` 中的任务 ID 进行科学的人性化分组归类（例如："深度工作"、"碎片处理"、"沟通协作"、"出门顺手做"等）。
4. 对于剩余的不重要或精力不足可以推迟的任务，提炼其 taskId 放入 \`deferTasks\`，建议推迟释放今日带宽。
5. \`summary\` 给出今天的简练总结（包含今天的建议基准和负荷评估）。禁止发散不定期的废话。
6. 标注了 "isRecurring": true 的任务来自周期性重复提醒（如每日习惯打卡），同一类重复任务每天最多安排一次，绝不可将多个标题相似的重复任务同时放入 focusTasks。如果存在多个标题高度相似的任务（如"背单词"与"背单词"），只保留一个在 focusTasks，其余放入 deferTasks。
7. 【非常重要】当前时间是 ${currentHour} 点，今天仅剩余 ${remainingHours} 小时可用。制定计划时，\`focusTasks\` 的任务总预估耗时 (totalEstimatedHours) 必须 **严格小于等于** 剩余可用时间（${remainingHours}小时）。如果是晚间安排，严禁排满不可执行的长任务。

严格输出纯 JSON 格式：
{
  "focusTasks": [
    { "id": "taskId_1", "reason": "高优项且今日必须交付" },
    { "id": "taskId_2", "reason": "已逾期需尽快收尾" }
  ],
  "groupedTasks": {
    "深度工作": ["taskId_1"],
    "碎片处理": ["taskId_2"]
  },
  "deferTasks": ["taskId_3", "taskId_4"],
  "summary": "今天主要收尾两个项目文档，约需2.5小时可以搞定。杂项已推迟。",
  "totalEstimatedHours": 2.5
}

今日待办池信息：
${pendingTasksSummary}
`;
    const defaultRes: TodayPlanResult = { focusTasks: [], deferTasks: [], summary: '暂无建议', errorMsg: '' };
    return await AgentService.callAgentAPI<TodayPlanResult>(prompt, defaultRes);
  }

  /**
   * AI自动重排：根据逾期/积压任务提供分组处理建议
   * 输出5个分组：明天继续做 / 本周稍后 / 降低优先级 / 建议拆分 / 暂缓归档
   */
  private static normalizeRescheduleJobStatus(data: RescheduleJobStatus): RescheduleJobStatus {
    return {
      jobId: data.jobId || '',
      status: data.status || 'failed',
      phase: data.phase || '',
      message: data.message || '',
      current: data.current || 0,
      total: data.total || 1,
      percent: data.percent || 0,
      result: data.result,
      error: data.error || ''
    };
  }

  public static async startRescheduleJob(
    overdueTasksSummary: string,
    futureTasksSummary: string,
    totalTasks: number
  ): Promise<RescheduleJobStatus> {
    const httpRequest = http.createHttp();
    const token = await authService.getToken();
    const headerObj: Record<string, string> = { 'Content-Type': 'application/json' };
    if (token) {
      headerObj['Authorization'] = `Bearer ${token}`;
    }

    try {
      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/api/agent/reschedule/start`,
        {
          method: http.RequestMethod.POST,
          header: headerObj,
          extraData: JSON.stringify({
            overdueTasksSummary,
            futureTasksSummary,
            totalTasks
          }),
          connectTimeout: 15000,
          readTimeout: 30000
        }
      );
      if (response.responseCode !== 200) {
        throw new Error(await AgentService.buildHttpErrorMessage(
          response.responseCode,
          String(response.result),
          'agent/reschedule/start'
        ));
      }
      const envelope = JSON.parse(response.result as string) as ApiEnvelope<RescheduleJobStatus>;
      if (!envelope.success || !envelope.data) {
        throw new Error(envelope.message || '重排任务创建失败');
      }
      return AgentService.normalizeRescheduleJobStatus(envelope.data);
    } finally {
      httpRequest.destroy();
    }
  }

  public static async getRescheduleJobStatus(jobId: string): Promise<RescheduleJobStatus> {
    const httpRequest = http.createHttp();
    const token = await authService.getToken();
    const headerObj: Record<string, string> = { 'Content-Type': 'application/json' };
    if (token) {
      headerObj['Authorization'] = `Bearer ${token}`;
    }

    try {
      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/api/agent/reschedule/status/${jobId}`,
        {
          method: http.RequestMethod.GET,
          header: headerObj,
          connectTimeout: 15000,
          readTimeout: 30000
        }
      );
      if (response.responseCode !== 200) {
        throw new Error(await AgentService.buildHttpErrorMessage(
          response.responseCode,
          String(response.result),
          'agent/reschedule/status'
        ));
      }
      const envelope = JSON.parse(response.result as string) as ApiEnvelope<RescheduleJobStatus>;
      if (!envelope.success || !envelope.data) {
        throw new Error(envelope.message || '重排任务状态获取失败');
      }
      return AgentService.normalizeRescheduleJobStatus(envelope.data);
    } finally {
      httpRequest.destroy();
    }
  }

  public static async suggestReschedule(overdueTasksSummary: string, futureTasksSummary: string = ''): Promise<RescheduleResult> {
    const currentDate = new Date().toISOString().split('T')[0];
    const prompt = `
你是一名专业的时间管理与拖延症恢复教练。用户积压了若干未完成任务，请根据每个任务的优先级、预估耗时、历史延期次数和逾期状态，帮用户分组整理，制定一份克制、温和的恢复计划。

当前日期：${currentDate}

【核心原则】
- 偏克制，默认采取暂缓或顺延
- 【全量覆盖】积压任务清单中每一个 isOverdue=true 的任务 id 都必须且只能出现在 6 个输出分组中的一个，不能只处理部分任务，也不能遗漏任务。
- 【明天容量限制】tomorrowTasks 最多 6 项，且总预估耗时不应超过 2 小时。不要把大量积压任务推给明天，否则会造成二次逾期。
- 【重要】必须参考“未来几天已有任务”和每个任务的 similarTaskKey / sameTypeFutureDates，避免将同类或相似任务（如运动、阅读、饮食记录、体重记录等习惯）重排到已经安排了相似任务的日期。如果目标日期已有类似任务，请安排到其他日期，或建议暂缓。
- 【任务来源规则】必须区分任务来源。若 sourceType="auto_periodic_reminder"，或 isReminderAutoGenerated=true 且 reminderEventType="periodic"，默认放入 deleteTasks，理由说明“周期提醒生成的过期任务通常无需补做，删除不会影响后续提醒”。不要把这类任务安排到明天或本周稍后，除非任务标题明确表示必须补做。
- 【周期任务规则】特别是 reminderRuleTypes 包含 periodic_daily / habit_daily 的逾期任务，错过后通常无法补做，应放入 deleteTasks。
- 【同源周期错峰】如果多条积压任务来自同一个周期任务来源（同一个 reminderId / similarTaskKey），即使决定保留，也必须分散到不同日期，绝不能排到同一天；同一来源最多只允许 1 条进入 tomorrowTasks，其余必须继续顺延、暂缓或删除。
- 【习惯任务规则】如果 reminderEventType="habit"，或标题明显是习惯养成/每日记录/打卡类任务，逾期未做一般不补做；如确实需要保留，必须安排到 sameTypeFutureDates 中最后一个同类日期之后，且同一天只能有一个同类任务。
- 【依赖顺序规则】必须识别任务标题、description、goalTitle、krTitle、subtaskTitles 和 possiblePrerequisites 中的前后依赖。如果 B 需要 A 完成后才能开始，必须把 A 排在 B 前面；A 可进入 tomorrowTasks 或更早的 thisWeekTasks，B 必须延期到 A 之后，或暂缓。典型例子：“记录今日体脂率”依赖“购买体脂秤”，必须先安排购买体脂秤，再安排记录体脂率，不能反过来。
- 【去重规则】同一个 similarTaskKey 在同一天最多只能安排一次。重复的同类任务应错峰、暂缓或删除，绝不能全部放入 tomorrowTasks。
- 【删除规则】如果某项任务在未来完全没有合适的插入时间，或是错过即失效的日常循环任务，建议直接删除（放入 deleteTasks 中），我们将询问用户是否确认删除。

请将任务分为以下6个分组，严格输出纯 JSON：

1. \`tomorrowTasks\`: 建议保留到明天的任务（最多 6 项；高优、短耗时、必须接住，且明天没有相似冲突任务）
2. \`thisWeekTasks\`: 建议安排到本周稍后的任务（重要但不紧迫），建议日期 newDate（必须避开已有相似任务的日期，同类任务必须错峰）
3. \`downgradeTasks\`: 建议降低优先级的任务（长期积压、多次延期但非核心）
4. \`splitTasks\`: 建议拆分的大颗粒度任务（预估耗时长 ≥2h），提供拆分后的子任务标题
5. \`shelveTasks\`: 建议暂缓/搁置的任务（多次延期且低优，或近期每天都有类似任务排不开），注意不是删除，语意为"暂时搁置"
6. \`deleteTasks\`: 建议直接删除/放弃的任务（未来无合适插入时间、已失去时效性，或每日/周期类过期任务无法补做）

输出格式：
{
  "tomorrowTasks": [{ "id": "taskId", "reason": "已逾期且仅需10分钟" }],
  "thisWeekTasks": [{ "id": "taskId", "newDate": "${currentDate}", "reason": "重要但今天精力不足" }],
  "downgradeTasks": [{ "id": "taskId", "reason": "已延期3次，非核心事项" }],
  "splitTasks": [{ "id": "taskId", "subTasks": ["子任务1", "子任务2"], "reason": "耗时太长建议拆细" }],
  "shelveTasks": [{ "id": "taskId", "reason": "低优且多次延期，建议暂时搁置" }],
  "deleteTasks": [{ "id": "taskId", "reason": "近期排不开且已无时效性，建议删除" }],
  "summary": "简洁一句话总结本次重排方案"
}

积压任务清单：
${overdueTasksSummary}

未来几天已有任务（重排请尽力避开高度相似冲突的任务时间）：
${futureTasksSummary ? futureTasksSummary : '无'}
`;
    const defaultRes: RescheduleResult = {
      tomorrowTasks: [],
      thisWeekTasks: [],
      downgradeTasks: [],
      splitTasks: [],
      shelveTasks: [],
      deleteTasks: []
    };
    return await AgentService.callAgentAPI<RescheduleResult>(prompt, defaultRes);
  }

  /**
   * AI单条KR重生：根据上下文和用户的特定不满，单点重写某个 KeyResult
   */
  public static async regenerateKR(objective: string, allKRs: KeyResultItem[], targetIndex: number, extraPrompt: string = ''): Promise<KeyResultItem | null> {
    const oldKR = allKRs[targetIndex];
    if (!oldKR) return null;
    const prompt = `
你是一个专业的 OKR 与目标管理教练。用户正在规划目标：【${objective}】。
当前整体的 KR 列表包括：
${JSON.stringify(allKRs.map(k=>k.title))}

用户对其中第 ${targetIndex + 1} 个 KR 不满意，想要重新拆解这一个节点。
旧的不可用的 KR 数据为：${JSON.stringify(oldKR)}

${extraPrompt ? '用户的修改需求是：' + extraPrompt : '请为他换一个衡量角度更新颖、更合理的 KR 替代方案，并给出配套的 tasks。'}

要求：
1. 请返回必须可衡量、并搭配 4~8 个具体可执行动作（不要泛化）的最新 KR 方案。
2. 只返回这一个 JSON 对象，不要包括外部的 objective。格式如下：

{
  "title": "连续运动",
  "targetValue": 30,
  "tasks": ["挑选运动鞋", "制定跑课表", "完成感官初跑"]
}
`;
    const defaultRes: KeyResultItem = { title: "未知重构", targetValue: 1, tasks: [] };
    const res = await AgentService.callAgentAPI<KeyResultItem>(prompt, defaultRes);
    return res;
  }
}
export interface KeyResultItem {
  title: string;
  targetValue: number;
  tasks: string[];
}

export interface ReminderItem {
  id?: string;
  title: string;
  category: 'habit' | 'periodic' | 'countdown';
  rule: 'daily' | 'weekly' | 'monthly' | 'target_date';
  timeParams?: Array<string | number>;
  reminderTime?: string;
  suggestedTime?: string;
  endDate?: string;
}

export interface GoalClarifyResult {
  status: 'success' | 'simple_task' | 'error';
  question?: string;
  errorMsg?: string;
}
export interface GoalBreakdownResult {
  status: 'success' | 'error';
  objective: string;
  keyResults: KeyResultItem[];
  reminders?: ReminderItem[];
  errorMsg?: string;
}

export interface ErrorMsgContainer {
  errorMsg?: string;
}

export interface PlanTaskItem {
  id: string;
  reason: string;
}
export interface TodayPlanResult {
  focusTasks: PlanTaskItem[];
  deferTasks: string[];
  summary: string;
  totalEstimatedHours?: number;
  groupedTasks?: Record<string, string[]>;
  errorMsg?: string;
}

export interface RescheduleItemWithReason {
  id: string;
  reason: string;
}

export interface RescheduleWeekItem {
  id: string;
  newDate: string;
  reason: string;
}

export interface RescheduleSplitItem {
  id: string;
  subTasks: string[];
  reason: string;
}

export interface RescheduleResult {
  tomorrowTasks?: RescheduleItemWithReason[];
  thisWeekTasks?: RescheduleWeekItem[];
  downgradeTasks?: RescheduleItemWithReason[];
  splitTasks?: RescheduleSplitItem[];
  shelveTasks?: RescheduleItemWithReason[];
  deleteTasks?: RescheduleItemWithReason[];
  summary?: string;
  errorMsg?: string;
}

export type RescheduleJobStatusValue = 'queued' | 'running' | 'completed' | 'failed';

export interface RescheduleJobStatus {
  jobId: string;
  status: RescheduleJobStatusValue;
  phase: string;
  message: string;
  current: number;
  total: number;
  percent: number;
  result?: RescheduleResult;
  error?: string;
}
