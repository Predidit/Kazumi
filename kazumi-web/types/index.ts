/**
 * 类型导出 - 照抄 Kazumi 的数据模型结构
 */

// Bangumi 相关类型 (主要类型)
export * from './bangumi'

// Plugin 相关类型
export * from './plugin'

// 弹幕相关类型
export * from './danmaku'

// 存储相关类型
export * from './storage'

// API 相关类型
export * from './api'

// 角色相关类型 (兼容旧代码，排除与bangumi冲突的类型)
export type { Character, Actor } from './character'

// 剧集相关类型 (兼容旧代码)
export * from './episode'

// 动画相关类型 (兼容旧代码)
export type { 
  AnimeDetail, 
  Rating, 
  Images, 
  Collection, 
  Tag, 
  InfoboxItem,
  SearchResponse,
  CalendarResponse,
  CalendarItem,
  TrendingResponse,
  TrendingItem,
  SearchParams,
  PaginationParams,
  TrendingParams
} from './anime'
