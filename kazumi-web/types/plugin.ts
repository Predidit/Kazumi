/**
 * Plugin 数据类型 - 照抄 Kazumi 的 plugins.dart
 */

export interface Plugin {
  api: string
  type: string
  name: string
  version: string
  muliSources: boolean
  useWebview: boolean
  useNativePlayer: boolean
  usePost: boolean
  useLegacyParser: boolean
  adBlocker: boolean
  userAgent: string
  baseURL: string  // 注意: 原项目用 baseURL (大写URL)
  searchURL: string
  searchList: string
  searchName: string
  searchResult: string
  chapterRoads: string
  chapterResult: string
  referer: string
}

/**
 * 从JSON解析Plugin - 照抄 Plugin.fromJson
 */
export function parsePlugin(json: any): Plugin {
  return {
    api: json.api || '',
    type: json.type || 'anime',
    name: json.name || '',
    version: json.version || '',
    muliSources: json.muliSources ?? true,
    useWebview: json.useWebview ?? true,
    useNativePlayer: json.useNativePlayer ?? true,
    usePost: json.usePost ?? false,
    useLegacyParser: json.useLegacyParser ?? false,
    adBlocker: json.adBlocker ?? false,
    userAgent: json.userAgent || '',
    baseURL: json.baseURL || '',
    searchURL: json.searchURL || '',
    searchList: json.searchList || '',
    searchName: json.searchName || '',
    searchResult: json.searchResult || '',
    chapterRoads: json.chapterRoads || '',
    chapterResult: json.chapterResult || '',
    referer: json.referer || '',
  }
}

/**
 * 创建空Plugin模板 - 照抄 Plugin.fromTemplate
 */
export function createPluginTemplate(): Plugin {
  return {
    api: '5',
    type: 'anime',
    name: '',
    version: '',
    muliSources: true,
    useWebview: true,
    useNativePlayer: true,
    usePost: false,
    useLegacyParser: false,
    adBlocker: false,
    userAgent: '',
    baseURL: '',
    searchURL: '',
    searchList: '',
    searchName: '',
    searchResult: '',
    chapterRoads: '',
    chapterResult: '',
    referer: '',
  }
}

/**
 * 插件HTTP列表项 - 照抄 plugin_http_module.dart
 */
export interface PluginHTTPItem {
  name: string
  version: string
  useNativePlayer: boolean
  author: string
  lastUpdate: number
}

export function parsePluginHTTPItem(json: any): PluginHTTPItem {
  return {
    name: json.name || '',
    version: json.version || '',
    useNativePlayer: json.useNativePlayer ?? true,
    author: json.author || '',
    lastUpdate: json.lastUpdate ?? 0,
  }
}

/**
 * 搜索结果项 - 照抄 plugin_search_module.dart
 */
export interface SearchItem {
  name: string
  src: string
}

// 兼容旧代码的别名
export type SearchResult = SearchItem & { pluginName: string }

export interface PluginSearchResponse {
  pluginName: string
  data: SearchItem[]
}

/**
 * 播放列表 (线路) - 照抄 road_module.dart
 */
export interface Road {
  name: string
  data: string[]       // 章节URL列表
  identifier: string[] // 章节名称列表
}

/**
 * 视频源 - 用于显示多个播放源
 */
export interface VideoSource {
  plugin: string
  url: string
  quality?: string
}
