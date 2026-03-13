/**
 * DanDanPlay API 请求模块 - 照抄 Kazumi 的 damaku.dart
 */

import { Api, formatUrl } from './config'

// ============ 数据类型 - 照抄 danmaku_module.dart ============

export interface Danmaku {
  time: number      // 弹幕出现时间 (秒)
  mode: number      // 弹幕模式: 1=滚动, 4=底部, 5=顶部
  color: number     // 弹幕颜色 (十进制)
  message: string   // 弹幕内容
}

/**
 * 解析弹幕 - 照抄 Danmaku.fromJson
 * 弹幕格式: "time,mode,color,uid,message"
 */
export function parseDanmaku(json: any): Danmaku {
  const p = (json.p || '').split(',')
  return {
    time: parseFloat(p[0]) || 0,
    mode: parseInt(p[1]) || 1,
    color: parseInt(p[2]) || 16777215,
    message: json.m || '',
  }
}

// ============ 弹幕搜索响应 - 照抄 danmaku_search_response.dart ============

export interface DanmakuAnime {
  animeId: number
  animeTitle: string
  type: string
  typeDescription: string
  episodes: DanmakuEpisode[]
}

export interface DanmakuEpisode {
  episodeId: number
  episodeTitle: string
}

export interface DanmakuSearchResponse {
  hasMore: boolean
  animes: DanmakuAnime[]
  errorCode: number
  success: boolean
  errorMessage: string
}

export function parseDanmakuSearchResponse(json: any): DanmakuSearchResponse {
  return {
    hasMore: json.hasMore ?? false,
    animes: (json.animes || []).map((anime: any) => ({
      animeId: anime.animeId ?? 0,
      animeTitle: anime.animeTitle ?? '',
      type: anime.type ?? '',
      typeDescription: anime.typeDescription ?? '',
      episodes: (anime.episodes || []).map((ep: any) => ({
        episodeId: ep.episodeId ?? 0,
        episodeTitle: ep.episodeTitle ?? '',
      })),
    })),
    errorCode: json.errorCode ?? 0,
    success: json.success ?? false,
    errorMessage: json.errorMessage ?? '',
  }
}

// ============ 弹幕剧集响应 - 照抄 danmaku_episode_response.dart ============

export interface DanmakuEpisodeResponse {
  bangumiId: number
  bangumiTitle: string
  type: string
  typeDescription: string
  episodes: DanmakuEpisode[]
  errorCode: number
  success: boolean
  errorMessage: string
}

export function parseDanmakuEpisodeResponse(json: any): DanmakuEpisodeResponse {
  return {
    bangumiId: json.bangumi?.animeId ?? 0,
    bangumiTitle: json.bangumi?.animeTitle ?? '',
    type: json.bangumi?.type ?? '',
    typeDescription: json.bangumi?.typeDescription ?? '',
    episodes: (json.bangumi?.episodes || []).map((ep: any) => ({
      episodeId: ep.episodeId ?? 0,
      episodeTitle: ep.episodeTitle ?? '',
    })),
    errorCode: json.errorCode ?? 0,
    success: json.success ?? false,
    errorMessage: json.errorMessage ?? '',
  }
}

// ============ API 请求函数 - 照抄 DanmakuRequest ============

/**
 * 计算字符串相似度 - 照抄 string_match.dart 的 calculateSimilarity
 */
function calculateSimilarity(str1: string, str2: string): number {
  const s1 = str1.toLowerCase()
  const s2 = str2.toLowerCase()
  
  if (s1 === s2) return 1
  
  const len1 = s1.length
  const len2 = s2.length
  
  if (len1 === 0 || len2 === 0) return 0
  
  // 使用 Levenshtein 距离计算相似度
  const matrix: number[][] = []
  
  for (let i = 0; i <= len1; i++) {
    matrix[i] = [i]
  }
  for (let j = 0; j <= len2; j++) {
    matrix[0][j] = j
  }
  
  for (let i = 1; i <= len1; i++) {
    for (let j = 1; j <= len2; j++) {
      const cost = s1[i - 1] === s2[j - 1] ? 0 : 1
      matrix[i][j] = Math.min(
        matrix[i - 1][j] + 1,
        matrix[i][j - 1] + 1,
        matrix[i - 1][j - 1] + cost
      )
    }
  }
  
  const maxLen = Math.max(len1, len2)
  return 1 - matrix[len1][len2] / maxLen
}

/**
 * 从BgmBangumiID获取DanDanBangumiID - 照抄 DanmakuRequest.getDanDanBangumiIDByBgmBangumiID
 */
export async function getDanDanBangumiIDByBgmBangumiID(bgmBangumiID: number): Promise<number> {
  const path = formatUrl(Api.dandanAPIInfoByBgmBangumiId, [bgmBangumiID])
  const endPoint = Api.dandanAPIDomain + path
  
  const res = await fetch(endPoint)
  const jsonData = await res.json()
  const response = parseDanmakuEpisodeResponse(jsonData)
  return response.bangumiId
}

/**
 * 从标题获取DanDanBangumiID - 照抄 DanmakuRequest.getBangumiIDByTitle
 */
export async function getBangumiIDByTitle(title: string): Promise<number> {
  const response = await getDanmakuSearchResponse(title)
  
  let bestAnimeId = 0
  let maxSimilarity = 0
  
  for (const anime of response.animes) {
    const animeId = anime.animeId
    if (animeId >= 100000 || animeId < 2) {
      continue
    }
    
    const animeTitle = anime.animeTitle
    const similarity = calculateSimilarity(animeTitle, title)
    
    if (similarity === 1) {
      console.log(`Danmaku: total match ${title}`)
      return animeId
    }
    
    if (similarity > maxSimilarity) {
      maxSimilarity = similarity
      bestAnimeId = animeId
      console.log(`Danmaku: match anime danmaku ${title} --- ${animeTitle} similarity: ${similarity}`)
    }
  }
  
  return bestAnimeId
}

/**
 * 从BangumiID获取分集ID - 照抄 DanmakuRequest.getDanmakuEpisodesByBangumiID
 */
export async function getDanmakuEpisodesByBangumiID(bangumiID: number): Promise<DanmakuEpisodeResponse> {
  const path = formatUrl(Api.dandanAPIInfoByBgmBangumiId, [bangumiID])
  const endPoint = Api.dandanAPIDomain + path
  
  const res = await fetch(endPoint)
  const jsonData = await res.json()
  return parseDanmakuEpisodeResponse(jsonData)
}

/**
 * 从DanDanBangumiID获取分集ID - 照抄 DanmakuRequest.getDanDanEpisodesByDanDanBangumiID
 */
export async function getDanDanEpisodesByDanDanBangumiID(bangumiID: number): Promise<DanmakuEpisodeResponse> {
  const path = Api.dandanAPIInfo + bangumiID.toString()
  const endPoint = Api.dandanAPIDomain + path
  
  const res = await fetch(endPoint)
  const jsonData = await res.json()
  return parseDanmakuEpisodeResponse(jsonData)
}

/**
 * 从标题检索DanDan番剧数据库 - 照抄 DanmakuRequest.getDanmakuSearchResponse
 */
export async function getDanmakuSearchResponse(title: string): Promise<DanmakuSearchResponse> {
  const path = Api.dandanAPISearch
  const endPoint = Api.dandanAPIDomain + path
  
  const params = new URLSearchParams({ keyword: title })
  const res = await fetch(`${endPoint}?${params}`)
  const jsonData = await res.json()
  return parseDanmakuSearchResponse(jsonData)
}

/**
 * 获取弹幕 - 照抄 DanmakuRequest.getDanDanmaku
 * 这里猜测了弹弹Play的分集命名规则，例如番剧ID为1758，第一集弹幕库ID大概率为17580001
 */
export async function getDanDanmaku(bangumiID: number, episode: number): Promise<Danmaku[]> {
  const danmakus: Danmaku[] = []
  
  if (bangumiID === 0) {
    return danmakus
  }
  
  const episodeStr = episode.toString().padStart(4, '0')
  const path = Api.dandanAPIComment + bangumiID.toString() + episodeStr
  const endPoint = Api.dandanAPIDomain + path
  
  const params = new URLSearchParams({ withRelated: 'true' })
  console.log(`Danmaku: final request URL ${endPoint}?${params}`)
  
  const res = await fetch(`${endPoint}?${params}`)
  const jsonData = await res.json()
  const comments = jsonData.comments || []
  
  for (const comment of comments) {
    danmakus.push(parseDanmaku(comment))
  }
  
  return danmakus
}

/**
 * 通过EpisodeID获取弹幕 - 照抄 DanmakuRequest.getDanDanmakuByEpisodeID
 */
export async function getDanDanmakuByEpisodeID(episodeID: number): Promise<Danmaku[]> {
  const path = Api.dandanAPIComment + episodeID.toString()
  const endPoint = Api.dandanAPIDomain + path
  const danmakus: Danmaku[] = []
  
  const params = new URLSearchParams({ withRelated: 'true' })
  const res = await fetch(`${endPoint}?${params}`)
  const jsonData = await res.json()
  const comments = jsonData.comments || []
  
  for (const comment of comments) {
    danmakus.push(parseDanmaku(comment))
  }
  
  return danmakus
}
