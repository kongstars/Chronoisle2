export type HarmonySymbolAdoptionStatus = 'ready' | 'candidate' | 'deferred';
export type HarmonySymbolFallback = 'app-vector' | 'media-resource' | 'text-mark';

export interface HarmonySymbolMapping {
  name: string;
  semantic: string;
  symbol: string;
  status: HarmonySymbolAdoptionStatus;
  fallback: HarmonySymbolFallback;
  note: string;
}

export const HARMONY_SYMBOL_MIN_API: number = 11;
export const HARMONY_SYMBOL_FORM_MIN_API: number = 12;
export const HARMONY_SYMBOL_DEFAULT_WEIGHT: number = 500;
export const HARMONY_SYMBOL_RENDER_SINGLE: number = 0;
export const HARMONY_SYMBOL_RENDER_MULTIPLE_COLOR: number = 1;
export const HARMONY_SYMBOL_RENDER_MULTIPLE_OPACITY: number = 2;

export const HARMONY_SYMBOL_MAPPINGS: HarmonySymbolMapping[] = [
  {
    name: 'today',
    semantic: 'today/calendar/day',
    symbol: 'sys.symbol.calendar',
    status: 'ready',
    fallback: 'app-vector',
    note: 'runtime now prefers AppIcon custom calendar mark for bottom navigation and large brand usage'
  },
  {
    name: 'task',
    semantic: 'checklist/check',
    symbol: 'sys.symbol.list_checkmask',
    status: 'ready',
    fallback: 'app-vector',
    note: 'verified from HarmonyOS Symbol runtime resources; AppIcon keeps vector fallback through useSystemSymbol'
  },
  {
    name: 'calendar',
    semantic: 'calendar/date',
    symbol: 'sys.symbol.calendar',
    status: 'ready',
    fallback: 'media-resource',
    note: 'verified from HarmonyOS Symbol runtime resources; shared by calendar tab and reminder cards'
  },
  {
    name: 'goal',
    semantic: 'target/goal/focus',
    symbol: 'sys.symbol.flag_fill',
    status: 'ready',
    fallback: 'app-vector',
    note: 'runtime now prefers AppIcon custom target mark; filled flag remains only as system fallback reference'
  },
  {
    name: 'reminder',
    semantic: 'bell/clock',
    symbol: 'sys.symbol.bell_fill',
    status: 'ready',
    fallback: 'app-vector',
    note: 'verified from HarmonyOS Symbol runtime resources; preserves urgency through AppIcon tone color'
  },
  {
    name: 'focus',
    semantic: 'timer/focus',
    symbol: 'sys.symbol.timer',
    status: 'ready',
    fallback: 'app-vector',
    note: 'verified from HarmonyOS Symbol runtime resources; also feeds the future Live View icon set'
  },
  {
    name: 'ai',
    semantic: 'spark/intelligence',
    symbol: 'sys.symbol.wand_and_stars',
    status: 'candidate',
    fallback: 'app-vector',
    note: 'aligned with AppIcon runtime; AI mark stays restrained and is not treated as a marketing badge'
  },
  {
    name: 'profile',
    semantic: 'person/account',
    symbol: 'sys.symbol.person_fill',
    status: 'ready',
    fallback: 'app-vector',
    note: 'runtime now prefers AppIcon custom profile mark for bottom navigation and avatar placeholders'
  },
  {
    name: 'search',
    semantic: 'search/query',
    symbol: 'sys.symbol.magnifyingglass',
    status: 'ready',
    fallback: 'app-vector',
    note: 'verified from HarmonyOS Symbol runtime resources; used by search and empty states'
  },
  {
    name: 'success',
    semantic: 'check/done',
    symbol: 'sys.symbol.checkmark',
    status: 'ready',
    fallback: 'app-vector',
    note: 'first AppIcon SymbolGlyph trial'
  },
  {
    name: 'warning',
    semantic: 'warning/alert',
    symbol: 'sys.symbol.exclamationmark_triangle_fill',
    status: 'ready',
    fallback: 'text-mark',
    note: 'first AppIcon SymbolGlyph trial; shape ensures warning is not color-only'
  },
  {
    name: 'info',
    semantic: 'info/help',
    symbol: 'sys.symbol.info_circle',
    status: 'ready',
    fallback: 'text-mark',
    note: 'first AppIcon SymbolGlyph trial'
  },
  {
    name: 'chevron-left',
    semantic: 'back/chevron-left',
    symbol: 'sys.symbol.chevron_left',
    status: 'ready',
    fallback: 'app-vector',
    note: 'first AppIcon SymbolGlyph trial'
  },
  {
    name: 'chevron-right',
    semantic: 'forward/chevron-right',
    symbol: 'sys.symbol.chevron_right',
    status: 'ready',
    fallback: 'app-vector',
    note: 'first AppIcon SymbolGlyph trial'
  },
  {
    name: 'chevron-up',
    semantic: 'collapse/chevron-up',
    symbol: 'sys.symbol.chevron_up',
    status: 'ready',
    fallback: 'app-vector',
    note: 'verified from HarmonyOS Symbol runtime resources; used by expandable filters'
  },
  {
    name: 'chevron-down',
    semantic: 'expand/chevron-down',
    symbol: 'sys.symbol.chevron_down',
    status: 'ready',
    fallback: 'app-vector',
    note: 'verified from HarmonyOS Symbol runtime resources; used by expandable filters'
  },
  {
    name: 'progress',
    semantic: 'progress/ring/trend',
    symbol: 'sys.symbol.chart_bar',
    status: 'deferred',
    fallback: 'app-vector',
    note: 'runtime currently uses AppIcon custom progress mark; chart bar remains a future system-symbol candidate'
  },
  {
    name: 'stats',
    semantic: 'stats/analytics/bar',
    symbol: 'sys.symbol.chart_pie',
    status: 'deferred',
    fallback: 'app-vector',
    note: 'runtime currently uses AppIcon custom bar mark for clearer small-size analytics readability'
  },
  {
    name: 'wallet',
    semantic: 'creditcard/payment',
    symbol: 'sys.symbol.creditcard',
    status: 'candidate',
    fallback: 'app-vector',
    note: 'candidate; verify on device; used in membership/credit pages'
  },
  {
    name: 'archive',
    semantic: 'archive/box',
    symbol: 'sys.symbol.archivebox',
    status: 'candidate',
    fallback: 'app-vector',
    note: 'candidate; verify on device; used in archived goals page'
  },
  {
    name: 'plan',
    semantic: 'clipboard/list/plan',
    symbol: 'sys.symbol.doc_text',
    status: 'candidate',
    fallback: 'app-vector',
    note: 'aligned with AppIcon runtime; document glyph currently reads more clearly than clipboard at small sizes'
  },
  {
    name: 'note',
    semantic: 'document/text/note',
    symbol: 'sys.symbol.doc_text',
    status: 'candidate',
    fallback: 'app-vector',
    note: 'candidate; verify on device; fallback is geometric TargetMark variant'
  },
  {
    name: 'gear',
    semantic: 'settings/gear',
    symbol: 'sys.symbol.gearshape',
    status: 'candidate',
    fallback: 'app-vector',
    note: 'candidate; verify on device; used in settings and configuration'
  },
  {
    name: 'sync',
    semantic: 'sync/refresh/cloud',
    symbol: 'sys.symbol.arrow_clockwise',
    status: 'candidate',
    fallback: 'app-vector',
    note: 'aligned with AppIcon runtime; clockwise refresh mark is the active system fallback'
  },
  {
    name: 'plus',
    semantic: 'plus/add/create',
    symbol: 'sys.symbol.plus',
    status: 'candidate',
    fallback: 'app-vector',
    note: 'candidate; verify on device; used in create/add actions'
  },
  {
    name: 'close',
    semantic: 'close/x/delete',
    symbol: 'sys.symbol.xmark',
    status: 'candidate',
    fallback: 'app-vector',
    note: 'candidate; verify on device; used in clear and dismiss actions'
  }
];
