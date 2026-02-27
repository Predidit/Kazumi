/**
 * Bangumi API 请求模块 - 照抄 Kazumi 的 bangumi.dart
 * 集成缓存层优化性能
 */

import { Api, formatUrl } from './config'
import { apiCache, CACHE_TTL } from '@/lib/utils/cache'
import {
  BangumiItem,
  parseBangumiItem,
  EpisodeInfo,
  parseEpisodeInfo,
  CommentResponse,
  parseCommentResponse,
  CharactersResponse,
  parseCharactersResponse,
  StaffResponse,
  parseStaffResponse,
} from '@/types/bangumi'

/**
 * 获取每日放送 - 照抄 BangumiHTTP.getCalendar
 * 缓存 30 分钟
 */
export async function getCalendar(): Promise<BangumiItem[][]> {
  const cacheKey = 'bangumi:calendar'
  const cached = apiCache.get<BangumiItem[][]>(cacheKey)
  if (cached) return cached

  const bangumiCalendar: BangumiItem[][] = []
  try {
    const res = await fetch(Api.bangumiAPINextDomain + Api.bangumiCalendar)
    const jsonData = await res.json()
    
    for (let i = 1; i <= 7; i++) {
      const bangumiList: BangumiItem[] = []
      const jsonList = jsonData[String(i)] || []
      for (const jsonItem of jsonList) {
        try {
          const bangumiItem = parseBangumiItem(jsonItem.subject)
          bangumiList.push(bangumiItem)
        } catch {}
      }
      bangumiCalendar.push(bangumiList)
    }
    
    apiCache.set(cacheKey, bangumiCalendar, CACHE_TTL.LONG)
  } catch (e) {
    console.error('Resolve calendar failed', e)
  }
  return bangumiCalendar
}

/**
 * 通过搜索API获取日历 - 照抄 BangumiHTTP.getCalendarBySearch
 */
export async function getCalendarBySearch(
  dateRange: [string, string],
  limit: number,
  offset: number
): Promise<BangumiItem[][]> {
  const bangumiList: BangumiItem[] = []
  const bangumiCalendar: BangumiItem[][] = []

  const params = {
    keyword: '',
    sort: 'rank',
    filter: {
      type: [2],
      tag: ['日本'],
      air_date: [`>=${dateRange[0]}`, `<${dateRange[1]}`],
      rank: ['>0', '<=99999'],
      nsfw: true,
    },
  }

  try {
    const url = formatUrl(Api.bangumiAPIDomain + Api.bangumiRankSearch, [limit, offset])
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(params),
    })
    const jsonData = await res.json()
    const jsonList = jsonData.data || []
    
    for (const jsonItem of jsonList) {
      if (jsonItem && typeof jsonItem === 'object') {
        bangumiList.push(parseBangumiItem(jsonItem))
      }
    }
  } catch (e) {
    console.error('Resolve bangumi list failed', e)
  }

  try {
    for (let weekday = 1; weekday <= 7; weekday++) {
      const bangumiDayList: BangumiItem[] = []
      for (const bangumiItem of bangumiList) {
        if (bangumiItem.airWeekday === weekday) {
          bangumiDayList.push(bangumiItem)
        }
      }
      bangumiCalendar.push(bangumiDayList)
    }
  } catch (e) {
    console.error('Network: fetch bangumi item to calendar failed', e)
  }

  return bangumiCalendar
}

/**
 * 获取番剧列表 (按标签) - 照抄 BangumiHTTP.getBangumiList
 */
export async function getBangumiList(
  rank: number = 2,
  tag: string = ''
): Promise<BangumiItem[]> {
  const bangumiList: BangumiItem[] = []
  
  let params: any
  if (tag === '') {
    params = {
      keyword: '',
      sort: 'rank',
      filter: {
        type: [2],
        tag: ['日本'],
        rank: [`>${rank}`, '<=1050'],
        nsfw: false,
      },
    }
  } else {
    params = {
      keyword: '',
      sort: 'rank',
      filter: {
        type: [2],
        tag: [tag],
        rank: [`>${rank}`, '<=99999'],
        nsfw: false,
      },
    }
  }

  try {
    const url = formatUrl(Api.bangumiAPIDomain + Api.bangumiRankSearch, [100, 0])
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(params),
    })
    const jsonData = await res.json()
    const jsonList = jsonData.data || []
    
    for (const jsonItem of jsonList) {
      if (jsonItem && typeof jsonItem === 'object') {
        bangumiList.push(parseBangumiItem(jsonItem))
      }
    }
  } catch (e) {
    console.error('Network: resolve bangumi list failed', e)
  }

  return bangumiList
}

/**
 * 获取热门番剧列表 - 照抄 BangumiHTTP.getBangumiTrendsList
 * 缓存 5 分钟
 */
export async function getBangumiTrendsList(
  type: number = 2,
  limit: number = 24,
  offset: number = 0
): Promise<BangumiItem[]> {
  const cacheKey = `bangumi:trends:${type}:${limit}:${offset}`
  const cached = apiCache.get<BangumiItem[]>(cacheKey)
  if (cached) return cached

  const bangumiList: BangumiItem[] = []
  
  const params = new URLSearchParams({
    type: String(type),
    limit: String(limit),
    offset: String(offset),
  })

  try {
    const res = await fetch(
      `${Api.bangumiAPINextDomain}${Api.bangumiTrendsNext}?${params}`
    )
    const jsonData = await res.json()
    const jsonList = jsonData.data || []
    
    for (const jsonItem of jsonList) {
      if (jsonItem && typeof jsonItem === 'object') {
        bangumiList.push(parseBangumiItem(jsonItem.subject))
      }
    }
    
    apiCache.set(cacheKey, bangumiList, CACHE_TTL.MEDIUM)
  } catch (e) {
    console.error('Network: resolve bangumi trends list failed', e)
  }

  return bangumiList
}

/**
 * 搜索番剧 - 照抄 BangumiHTTP.bangumiSearch
 */
export async function bangumiSearch(
  keyword: string,
  options: {
    tags?: string[]
    offset?: number
    sort?: 'heat' | 'rank' | 'match'
  } = {}
): Promise<BangumiItem[]> {
  const { tags = [], offset = 0, sort = 'heat' } = options
  const bangumiList: BangumiItem[] = []

  const params = {
    keyword,
    sort,
    filter: {
      type: [2],
      tag: tags,
      rank: sort === 'rank' ? ['>0', '<=99999'] : ['>=0', '<=99999'],
      nsfw: false,
    },
  }

  try {
    const url = formatUrl(Api.bangumiAPIDomain + Api.bangumiRankSearch, [20, offset])
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(params),
    })
    const jsonData = await res.json()
    const jsonList = jsonData.data || []
    
    for (const jsonItem of jsonList) {
      if (jsonItem && typeof jsonItem === 'object') {
        try {
          const bangumiItem = parseBangumiItem(jsonItem)
          if (bangumiItem.nameCn !== '') {
            bangumiList.push(bangumiItem)
          }
        } catch (e) {
          console.error('Network: resolve search results failed', e)
        }
      }
    }
  } catch (e) {
    console.error('Network: unknown search problem', e)
  }

  return bangumiList
}

/**
 * 通过ID获取番剧信息 - 照抄 BangumiHTTP.getBangumiInfoByID
 * 缓存 1 小时（番剧信息很少变化）
 */
export async function getBangumiInfoByID(id: number): Promise<BangumiItem | null> {
  const cacheKey = `bangumi:info:${id}`
  const cached = apiCache.get<BangumiItem>(cacheKey)
  if (cached) return cached

  try {
    const url = formatUrl(Api.bangumiAPIDomain + Api.bangumiInfoByID, [id])
    const res = await fetch(url)
    const data = await res.json()
    const item = parseBangumiItem(data)
    apiCache.set(cacheKey, item, CACHE_TTL.VERY_LONG)
    return item
  } catch (e) {
    console.error('Network: resolve bangumi item failed', e)
    return null
  }
}

/**
 * 获取番剧剧集信息 - 照抄 BangumiHTTP.getBangumiEpisodeByID
 */
export async function getBangumiEpisodeByID(
  id: number,
  episode: number
): Promise<EpisodeInfo | null> {
  const params = new URLSearchParams({
    subject_id: String(id),
    offset: String(episode - 1),
    limit: '1',
  })

  try {
    const res = await fetch(
      `${Api.bangumiAPIDomain}${Api.bangumiEpisodeByID}?${params}`
    )
    const jsonData = await res.json()
    const episodeData = jsonData.data?.[0]
    if (episodeData) {
      return parseEpisodeInfo(episodeData)
    }
  } catch (e) {
    console.error('Network: resolve bangumi episode failed', e)
  }
  return null
}

/**
 * 获取番剧所有剧集 - 用于剧集列表
 */
export async function getBangumiEpisodes(
  subjectId: number,
  limit: number = 100,
  offset: number = 0
): Promise<{ data: EpisodeInfo[]; total: number }> {
  const params = new URLSearchParams({
    subject_id: String(subjectId),
    limit: String(limit),
    offset: String(offset),
  })

  try {
    const res = await fetch(
      `${Api.bangumiAPIDomain}${Api.bangumiEpisodeByID}?${params}`
    )
    const jsonData = await res.json()
    return {
      data: (jsonData.data || []).map((ep: any) => parseEpisodeInfo(ep)),
      total: jsonData.total || 0,
    }
  } catch (e) {
    console.error('Network: resolve bangumi episodes failed', e)
    return { data: [], total: 0 }
  }
}

/**
 * 获取番剧评论 (吐槽) - 照抄 BangumiHTTP.getBangumiCommentsByID
 */
export async function getBangumiCommentsByID(
  id: number,
  offset: number = 0
): Promise<CommentResponse> {
  try {
    const url = formatUrl(
      Api.bangumiAPINextDomain + Api.bangumiCommentsByIDNext,
      [id, 20, offset]
    )
    const res = await fetch(url)
    const jsonData = await res.json()
    return parseCommentResponse(jsonData)
  } catch (e) {
    console.error('Network: resolve bangumi comments failed', e)
    return { commentList: [], total: 0 }
  }
}

/**
 * 获取番剧角色列表 - 照抄 BangumiHTTP.getCharatersByBangumiID
 * 缓存 1 小时
 */
export async function getCharactersByBangumiID(id: number): Promise<CharactersResponse> {
  const cacheKey = `bangumi:characters:${id}`
  const cached = apiCache.get<CharactersResponse>(cacheKey)
  if (cached) return cached

  try {
    const url = formatUrl(Api.bangumiAPIDomain + Api.bangumiCharacterByID, [id])
    const res = await fetch(url)
    const jsonData = await res.json()
    const result = parseCharactersResponse(jsonData)
    apiCache.set(cacheKey, result, CACHE_TTL.VERY_LONG)
    return result
  } catch (e) {
    console.error('Network: resolve bangumi characters failed', e)
    return { charactersList: [] }
  }
}

/**
 * 获取番剧制作人员 - 照抄 BangumiHTTP.getBangumiStaffByID
 */
export async function getBangumiStaffByID(id: number): Promise<StaffResponse> {
  try {
    const url = formatUrl(
      Api.bangumiAPINextDomain + Api.bangumiStaffByIDNext,
      [id]
    )
    const res = await fetch(url)
    const jsonData = await res.json()
    return parseStaffResponse(jsonData)
  } catch (e) {
    console.error('Network: resolve bangumi staff failed', e)
    return { data: [], total: 0 }
  }
}
