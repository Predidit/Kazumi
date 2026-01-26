/**
 * Custom React hook for danmaku (bullet comments) management
 * 照抄 Kazumi 的 player_controller.dart 中的弹幕获取逻辑
 * 
 * 原项目流程:
 * 1. getDanDanBangumiIDByBgmBangumiID(bgmBangumiID) - 从 BGM ID 获取 DanDan 的 bangumiId
 * 2. getDanDanmaku(bangumiID, episode) - 使用 bangumiID + episode.padLeft(4, '0') 构造 episodeId
 * 
 * 备用方案 (照抄原项目的 showDanmakuSwitch):
 * - 如果 BGM ID 查询失败，使用番剧标题搜索
 */

import { useState, useCallback, useEffect, useRef } from 'react'
import { useAppStore } from '@/lib/store'
import { parseDanmakuComment } from '@/lib/utils/danmaku'
import type { Danmaku, DanmakuResponse, DanmakuBangumiResponse } from '@/types/danmaku'

interface UseDanmakuOptions {
  animeId?: number  // Bangumi subject ID (BGM ID)
  episodeNumber?: number
  animeTitle?: string  // 番剧标题 (用于备用搜索)
  autoFetch?: boolean
}

interface UseDanmakuResult {
  enabled: boolean
  opacity: number
  speed: number
  fontSize: number
  list: Danmaku[]
  loading: boolean
  error: Error | null
  // 额外设置
  area: number
  hideTop: boolean
  hideBottom: boolean
  hideScroll: boolean
  duration: number
  lineHeight: number
  followSpeed: boolean
  massive: boolean
  border: boolean
  showColor: boolean
  fontWeight: number
  // Setters
  setEnabled: (enabled: boolean) => void
  setOpacity: (opacity: number) => void
  setSpeed: (speed: number) => void
  setFontSize: (size: number) => void
  fetchDanmaku: (bangumiId: number, episodeNumber: number, title?: string) => Promise<void>
  clearDanmaku: () => void
  getVisibleDanmaku: (currentTime: number, windowSize?: number) => Danmaku[]
}

/**
 * Hook for managing danmaku state and fetching
 * 照抄原项目的 getDanDanmakuByBgmBangumiID 方法
 */
export function useDanmaku(options: UseDanmakuOptions = {}): UseDanmakuResult {
  const { animeId: bgmBangumiId, episodeNumber, animeTitle, autoFetch = true } = options
  
  // Get individual state values from store
  const enabled = useAppStore((state) => state.enabled)
  const opacity = useAppStore((state) => state.opacity)
  const speed = useAppStore((state) => state.speed)
  const fontSize = useAppStore((state) => state.fontSize)
  const list = useAppStore((state) => state.list)
  
  // 额外设置
  const area = useAppStore((state) => state.area)
  const hideTop = useAppStore((state) => state.hideTop)
  const hideBottom = useAppStore((state) => state.hideBottom)
  const hideScroll = useAppStore((state) => state.hideScroll)
  const duration = useAppStore((state) => state.danmakuDuration)
  const lineHeight = useAppStore((state) => state.lineHeight)
  const followSpeed = useAppStore((state) => state.followSpeed)
  const massive = useAppStore((state) => state.massive)
  const border = useAppStore((state) => state.border)
  const showColor = useAppStore((state) => state.showColor)
  const fontWeight = useAppStore((state) => state.fontWeight)
  
  // 弹幕来源设置 - 在 getDanmaku 中通过 useAppStore.getState() 获取最新值
  // 这里不需要订阅这些状态，因为过滤是在获取弹幕时进行的
  
  // Get actions (these are stable references)
  const setEnabled = useAppStore((state) => state.setEnabled)
  const setOpacity = useAppStore((state) => state.setOpacity)
  const setSpeed = useAppStore((state) => state.setSpeed)
  const setFontSize = useAppStore((state) => state.setFontSize)
  const setList = useAppStore((state) => state.setList)

  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)
  const hasFetchedRef = useRef(false)

  /**
   * 从 BGM ID 获取 DanDan 的 bangumiId
   * 照抄原项目的 getDanDanBangumiIDByBgmBangumiID
   * 支持备用标题搜索 - 照抄原项目的 showDanmakuSwitch
   */
  const getDanDanBangumiId = useCallback(async (bgmBangumiId: number, title?: string): Promise<number> => {
    // 构建 URL，如果有标题则添加作为备用搜索参数
    const url = new URL(`/api/dandanplay/bangumi/bgm/${bgmBangumiId}`, window.location.origin)
    if (title) {
      url.searchParams.set('title', title)
    }
    
    const response = await fetch(url.toString())
    if (!response.ok) {
      throw new Error('获取弹幕番剧ID失败')
    }
    const data: DanmakuBangumiResponse = await response.json()
    
    if (!data.bangumi || !data.bangumi.animeId) {
      throw new Error('未找到对应的弹幕库')
    }
    
    // 返回 DanDan 的 animeId (bangumiId)
    return data.bangumi.animeId
  }, [])

  /**
   * 获取弹幕
   * 照抄原项目的 getDanDanmaku 方法
   * episodeId = bangumiID.toString() + episode.toString().padLeft(4, '0')
   */
  const getDanmaku = useCallback(async (danDanBangumiId: number, episode: number): Promise<Danmaku[]> => {
    if (danDanBangumiId === 0) {
      return []
    }
    
    // 照抄原项目: bangumiID.toString() + episode.toString().padLeft(4, '0')
    // 例如: bangumiID=1758, episode=1 -> episodeId=17580001
    const episodeIdStr = danDanBangumiId.toString() + episode.toString().padStart(4, '0')
    const episodeId = parseInt(episodeIdStr, 10)
    
    console.log(`Danmaku: final request episodeId ${episodeId}`)
    
    const response = await fetch(`/api/dandanplay/comment/${episodeId}?withRelated=true`)
    if (!response.ok) {
      throw new Error('获取弹幕失败')
    }
    
    const data: DanmakuResponse = await response.json()
    
    if (!data.comments || data.comments.length === 0) {
      return []
    }
    
    // 解析弹幕
    const allDanmaku = data.comments.map(parseDanmakuComment)
    
    // 根据弹幕来源设置过滤 - 照抄原项目
    // 获取最新的来源设置
    const state = useAppStore.getState()
    let filteredDanmaku = allDanmaku.filter(d => {
      const source = d.source.toLowerCase()
      // BiliBili 来源
      if (source.includes('bilibili') || source.includes('bili')) {
        return state.sourceBiliBili
      }
      // Gamer 来源 (巴哈姆特)
      if (source.includes('gamer') || source.includes('bahamut')) {
        return state.sourceGamer
      }
      // DanDan 来源 (弹弹play自有弹幕)
      if (source.includes('dandan') || source === '') {
        return state.sourceDanDan
      }
      // 其他来源默认显示
      return true
    })
    
    // 关键词屏蔽过滤 - 照抄原项目
    // 以"/"开头和结尾将视作正则表达式, 如"/\d+/"表示屏蔽所有数字
    if (state.shieldList && state.shieldList.length > 0) {
      const beforeCount = filteredDanmaku.length
      filteredDanmaku = filteredDanmaku.filter(d => {
        const text = d.message
        for (const keyword of state.shieldList) {
          // 检查是否是正则表达式 (以/开头和结尾)
          if (keyword.startsWith('/') && keyword.endsWith('/') && keyword.length > 2) {
            try {
              const regexPattern = keyword.slice(1, -1)
              const regex = new RegExp(regexPattern)
              if (regex.test(text)) {
                return false
              }
            } catch {
              // 正则表达式无效，当作普通关键词处理
              if (text.includes(keyword)) {
                return false
              }
            }
          } else {
            // 普通关键词匹配
            if (text.includes(keyword)) {
              return false
            }
          }
        }
        return true
      })
      console.log(`Danmaku: shield filtered ${beforeCount} -> ${filteredDanmaku.length} comments`)
    }
    
    console.log(`Danmaku: filtered ${allDanmaku.length} -> ${filteredDanmaku.length} comments`)
    
    return filteredDanmaku
  }, [])

  /**
   * Fetch danmaku comments for an episode
   * 照抄原项目的 getDanDanmakuByBgmBangumiID 方法
   * 支持备用标题搜索 - 照抄原项目的 showDanmakuSwitch
   */
  const fetchDanmaku = useCallback(
    async (bgmBangumiId: number, episodeNumber: number, title?: string) => {
      if (loading) {
        console.log('Danmaku: is loading, ignore duplicate request')
        return
      }

      console.log(`Danmaku: attempting to get danmaku [BgmBangumiID] ${bgmBangumiId}${title ? ` [Title] ${title}` : ''}`)
      setLoading(true)
      setError(null)

      try {
        // Step 1: 从 BGM ID 获取 DanDan 的 bangumiId (支持标题备用搜索)
        const danDanBangumiId = await getDanDanBangumiId(bgmBangumiId, title)
        console.log(`Danmaku: got DanDan bangumiId ${danDanBangumiId}`)
        
        // Step 2: 获取弹幕
        const danmakuList = await getDanmaku(danDanBangumiId, episodeNumber)
        console.log(`Danmaku: loaded ${danmakuList.length} comments`)
        
        // Update state
        setList(danmakuList)
      } catch (err) {
        const error = err instanceof Error ? err : new Error(String(err))
        setError(error)
        console.error(`Danmaku: failed to get danmaku [BgmBangumiID] ${bgmBangumiId}`, error)

        // Clear danmaku list on error
        setList([])
      } finally {
        setLoading(false)
      }
    },
    [loading, getDanDanBangumiId, getDanmaku, setList]
  )

  /**
   * Clear danmaku list
   */
  const clearDanmaku = useCallback(() => {
    setList([])
    setError(null)
  }, [setList])

  /**
   * Get visible danmaku for current time
   */
  const getVisibleDanmaku = useCallback(
    (currentTime: number, windowSize: number = 5): Danmaku[] => {
      if (!enabled) {
        return []
      }

      return list.filter((danmaku) => {
        return (
          danmaku.time >= currentTime &&
          danmaku.time < currentTime + windowSize
        )
      })
    },
    [enabled, list]
  )

  /**
   * Auto-fetch danmaku on mount
   * 支持标题备用搜索 - 照抄原项目的 showDanmakuSwitch
   */
  useEffect(() => {
    if (bgmBangumiId !== undefined && episodeNumber !== undefined && autoFetch && !hasFetchedRef.current) {
      hasFetchedRef.current = true
      fetchDanmaku(bgmBangumiId, episodeNumber, animeTitle)
    }
  }, [bgmBangumiId, episodeNumber, animeTitle, autoFetch]) // 移除 fetchDanmaku 依赖，避免循环

  // Reset fetch flag when anime/episode changes
  useEffect(() => {
    return () => {
      hasFetchedRef.current = false
    }
  }, [bgmBangumiId, episodeNumber])

  return {
    enabled,
    opacity,
    speed,
    fontSize,
    list,
    loading,
    error,
    // 额外设置
    area,
    hideTop,
    hideBottom,
    hideScroll,
    duration,
    lineHeight,
    followSpeed,
    massive,
    border,
    showColor,
    fontWeight,
    // Setters
    setEnabled,
    setOpacity,
    setSpeed,
    setFontSize,
    fetchDanmaku,
    clearDanmaku,
    getVisibleDanmaku,
  }
}
