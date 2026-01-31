/**
 * Local storage type definitions
 * For watch history and favorites persistence
 */

export interface WatchHistoryItem {
  animeId: number
  episodeNumber: number
  time: number
  timestamp: number
  animeTitle: string
  animeCover: string
  /** 来源插件名称 */
  adapterName?: string
}

export interface FavoritesData {
  animeIds: number[]
}

/**
 * 收藏类型 - 照抄原项目的 collect_type.dart
 * 0 - 未收藏
 * 1 - 在看
 * 2 - 想看
 * 3 - 搁置
 * 4 - 看过
 * 5 - 抛弃
 */
export type CollectType = 0 | 1 | 2 | 3 | 4 | 5

/**
 * 收藏的动画 - 照抄原项目的 collect_module.dart
 */
export interface CollectedAnime {
  animeId: number
  type: CollectType
  time: number
  name: string
  nameCn: string
  cover: string
}
