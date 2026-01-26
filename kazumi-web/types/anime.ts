/**
 * Anime-related type definitions
 * Based on Bangumi API response structures
 */

export interface AnimeDetail {
  id: number
  type: number
  name: string
  nameCn: string
  summary: string
  date: string
  platform: string
  eps: number
  totalEpisodes: number
  volumes: number
  series: boolean
  locked: boolean
  nsfw: boolean
  rating: Rating
  images: Images
  collection: Collection
  tags: Tag[]
  infobox: InfoboxItem[]
  metaTags: string[]
}

export interface Rating {
  rank: number
  score: number
  total: number
  count: Record<string, number> // "1" to "10"
}

export interface Images {
  small: string
  grid: string
  large: string
  medium: string
  common: string
}

export interface Collection {
  wish: number
  collect: number
  doing: number
  onHold: number
  dropped: number
}

export interface Tag {
  name: string
  count: number
  totalCont: number
}

export interface InfoboxItem {
  key: string
  value: string | { v: string }[]
}

export interface SearchResponse {
  data: AnimeDetail[]
  total: number
  limit: number
  offset: number
}

export interface CalendarResponse {
  [weekday: string]: CalendarItem[]
}

export interface CalendarItem {
  subject: AnimeDetail
  watchers: number
}

export interface TrendingResponse {
  data: TrendingItem[]
  total: number
}

export interface TrendingItem {
  count: number
  subject: AnimeDetail
}

export interface SearchParams {
  keyword: string
  limit?: number
  offset?: number
  sort?: 'heat' | 'rank' | 'score'
  filter?: {
    type?: number[]
    tag?: string[]
    rank?: string[]
    nsfw?: boolean
  }
}

export interface PaginationParams {
  limit?: number
  offset?: number
}

export interface TrendingParams extends PaginationParams {
  type?: number
}
