/**
 * API client interface definitions
 * For Bangumi API, DanDanPlay API, and Plugin Manager
 */

import {
  AnimeDetail,
  SearchParams,
  SearchResponse,
  CalendarResponse,
  TrendingParams,
  TrendingResponse,
  PaginationParams,
} from './anime'
import { EpisodeResponse } from './episode'
import { Character, StaffResponse } from './character'
import {
  DanmakuSearchResponse,
  DanmakuBangumiResponse,
  DanmakuResponse,
} from './danmaku'
import { Plugin, SearchResult } from './plugin'

/**
 * Bangumi API Client Interface
 */
export interface BangumiClient {
  // Get anime details by ID
  getSubject(id: number): Promise<AnimeDetail>

  // Search anime by keyword
  searchSubjects(params: SearchParams): Promise<SearchResponse>

  // Get daily schedule
  getCalendar(): Promise<CalendarResponse>

  // Get trending anime
  getTrending(params: TrendingParams): Promise<TrendingResponse>

  // Get episodes for anime
  getEpisodes(
    subjectId: number,
    params: PaginationParams
  ): Promise<EpisodeResponse>

  // Get characters for anime
  getCharacters(subjectId: number): Promise<Character[]>

  // Get staff for anime
  getStaff(subjectId: number): Promise<StaffResponse>
}

/**
 * DanDanPlay API Client Interface
 */
export interface DanDanPlayClient {
  // Search anime by keyword
  searchAnime(keyword: string): Promise<DanmakuSearchResponse>

  // Get anime info by ID
  getBangumi(animeId: number): Promise<DanmakuBangumiResponse>

  // Get anime info by Bangumi ID
  getBangumiByBgmId(bgmId: number): Promise<DanmakuBangumiResponse>

  // Get danmaku comments for episode
  getComments(episodeId: number, withRelated?: boolean): Promise<DanmakuResponse>

  // Generate authentication signature
  generateSignature(timestamp: string, path: string): string
}

/**
 * Plugin Manager Interface
 */
export interface PluginManager {
  // Load all available plugins
  loadPlugins(): Promise<Plugin[]>

  // Get plugin by name
  getPlugin(name: string): Plugin | undefined

  // Search for video sources using plugin
  searchWithPlugin(plugin: Plugin, keyword: string): Promise<SearchResult[]>

  // Resolve video URL from source
  resolveVideoUrl(plugin: Plugin, sourceUrl: string): Promise<string>
}
