/**
 * Danmaku (bullet comment) type definitions
 * Based on DanDanPlay API structures
 */

export interface Danmaku {
  message: string
  time: number
  type: number // 1=scroll, 4=bottom, 5=top
  color: string
  source: string
}

export interface DanmakuComment {
  p: string // Format: "time,type,color,source,pool,userId,mode"
  m: string // Message content
}

export interface DanmakuResponse {
  count: number
  comments: DanmakuComment[]
}

export interface DanmakuAnime {
  animeId: number
  animeTitle: string
  type: string
  typeDescription: string
  episodeCount: number
  imageUrl: string
  startDate: string
  rating: number
  isFavorited: boolean
  bangumiId: string
}

export interface DanmakuBangumi {
  animeId: number
  animeTitle: string
  bangumiId: string
  type: string
  typeDescription: string
  imageUrl: string
  searchKeyword: string
  isOnAir: boolean
  airDay: number
  isFavorited: boolean
  isRestricted: boolean
  rating: number
  bangumiUrl: string
  userRating: number
  favoriteStatus: string
  comment: string
  intro: string
  summary: string
  metadata: any[]
  titles: Title[]
  seasons: any[]
  relateds: RelatedAnime[]
  similars: RelatedAnime[]
  tags: DanmakuTag[]
  onlineDatabases: OnlineDatabase[]
  trailers: Trailer[]
  ratingDetails: Record<string, number>
  episodes: DanmakuEpisode[]
}

export interface DanmakuEpisode {
  episodeId: number
  episodeNumber: number
  episodeTitle: string
  seasonId: number
  airDate: string
  lastWatched: string
}

export interface Title {
  language: string
  title: string
}

export interface RelatedAnime {
  animeId: number
  animeTitle: string
  bangumiId: string
  imageUrl: string
  searchKeyword: string
  isOnAir: boolean
  airDay: number
  isFavorited: boolean
  isRestricted: boolean
  rating: number
}

export interface DanmakuTag {
  id: number
  name: string
  count: number
}

export interface OnlineDatabase {
  name: string
  url: string
}

export interface Trailer {
  id: string
  title: string
  url: string
  imageUrl: string
  date: string
}

export interface DanmakuSearchResponse {
  success: boolean
  errorCode: number
  errorMessage: string
  animes: DanmakuAnime[]
}

export interface DanmakuBangumiResponse {
  success: boolean
  errorCode: number
  errorMessage: string
  bangumi: {
    animeId: number
    animeTitle: string
    type?: string
    typeDescription?: string
  } | null
  episodes?: DanmakuEpisode[]
  searchResults?: DanmakuAnime[]
}
