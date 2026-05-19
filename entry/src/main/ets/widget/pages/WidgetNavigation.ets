export class WidgetRouteParams {
  taskId?: string = undefined;
  eventId?: string = undefined;
  showVoiceCreate?: boolean = undefined;
  target?: string = undefined;
}

export class WidgetRouterInfo {
  abilityName: string = 'EntryAbility';
  url: string = '';
  params?: WidgetRouteParams = undefined;
}

export class WidgetRouterAction {
  action: string = 'router';
  abilityName: string = 'EntryAbility';
  router: WidgetRouterInfo = new WidgetRouterInfo();
}

export function buildWidgetRouteAction(url: string, params?: WidgetRouteParams): WidgetRouterAction {
  const routerInfo: WidgetRouterInfo = new WidgetRouterInfo();
  routerInfo.url = url;
  routerInfo.params = params;

  const action: WidgetRouterAction = new WidgetRouterAction();
  action.router = routerInfo;
  return action;
}

export function buildTaskRouteParams(taskId: string): WidgetRouteParams {
  const params: WidgetRouteParams = new WidgetRouteParams();
  params.taskId = taskId;
  return params;
}

export function buildEventRouteParams(eventId: string): WidgetRouteParams {
  const params: WidgetRouteParams = new WidgetRouteParams();
  params.eventId = eventId;
  return params;
}

export function buildVoiceRouteParams(): WidgetRouteParams {
  const params: WidgetRouteParams = new WidgetRouteParams();
  params.showVoiceCreate = true;
  params.target = 'voiceCreate';
  return params;
}
