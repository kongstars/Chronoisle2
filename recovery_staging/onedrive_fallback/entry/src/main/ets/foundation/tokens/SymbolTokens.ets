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
    semantic: 'home/today/calendar',
    symbol: 'sys.symbol.house',
    status: 'ready',
    fallback: 'media-resource',
    note: 'verified from HarmonyOS Symbol runtime resources; bottom navigation uses AppIcon system symbol'
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
    semantic: 'target/flag/progress',
    symbol: 'sys.symbol.flag',
    status: 'ready',
    fallback: 'app-vector',
    note: 'verified from HarmonyOS Symbol runtime resources; uses flag to avoid overly decorative target marks'
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
    symbol: 'sys.symbol.sparkles',
    status: 'candidate',
    fallback: 'text-mark',
    note: 'AI mark should stay restrained and not become a marketing badge'
  },
  {
    name: 'profile',
    semantic: 'person/account',
    symbol: 'sys.symbol.person',
    status: 'ready',
    fallback: 'text-mark',
    note: 'verified from HarmonyOS Symbol runtime resources; used by bottom navigation'
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
  }
];
