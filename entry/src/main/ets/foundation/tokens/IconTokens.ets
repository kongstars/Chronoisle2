import {
  HARMONY_SYMBOL_DEFAULT_WEIGHT,
  HARMONY_SYMBOL_FORM_MIN_API,
  HARMONY_SYMBOL_MIN_API
} from './SymbolTokens';

export const ICON_SIZE_XS: number = 16;
export const ICON_SIZE_SM: number = 22;
export const ICON_SIZE_MD: number = 26;
export const ICON_SIZE_LG: number = 30;
export const ICON_SIZE_XL: number = 36;

export const ICON_STROKE_SM: number = 1;
export const ICON_STROKE_MD: number = 1.25;
export const ICON_STROKE_LG: number = 1.5;

export type IconRenderSource = 'system-symbol' | 'app-vector' | 'media-resource';

export const ICON_RENDER_SOURCE_SYSTEM_SYMBOL: IconRenderSource = 'system-symbol';
export const ICON_RENDER_SOURCE_APP_VECTOR: IconRenderSource = 'app-vector';
export const ICON_RENDER_SOURCE_MEDIA_RESOURCE: IconRenderSource = 'media-resource';

export const ICON_SYMBOL_MIN_API: number = HARMONY_SYMBOL_MIN_API;
export const ICON_SYMBOL_FORM_MIN_API: number = HARMONY_SYMBOL_FORM_MIN_API;
export const ICON_SYMBOL_DEFAULT_WEIGHT: number = HARMONY_SYMBOL_DEFAULT_WEIGHT;
