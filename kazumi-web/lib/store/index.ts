/**
 * Global application state management using Zustand
 * Organized into slices: anime, player, danmaku, history, favorites
 */

import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
import { useShallow } from 'zustand/react/shallow'
import type { AnimeDetail } from '@/types/anime'
import type { Danmaku } from '@/types/danmaku'
import type { WatchHistoryItem } from '@/types/storage'

// ============================================================================
// State Interfaces
// ============================================================================

interface AnimeState {
  currentAnime: AnimeDetail | null
  setCurrentAnime: (anime: AnimeDetail | null) => void
}

interface PlayerState {
  isPlaying: boolean
  currentTime: number
  duration: number
  volume: number
  isFullscreen: boolean
  isPiP: boolean
  setIsPlaying: (playing: boolean) => void
  setCurrentTime: (time: number) => void
  setDuration: (duration: number) => void
  setVolume: (volume: number) => void
  setIsFullscreen: (fullscreen: boolean) => void
  setIsPiP: (pip: boolean) => void
}

interface DanmakuState {
  enabled: boolean
  opacity: number
  speed: number
  fontSize: number
  list: Danmaku[]
  // 额外设置 - 照抄原项目
  area: number
  hideTop: boolean
  hideBottom: boolean
  hideScroll: boolean
  danmakuDuration: number // 弹幕持续时间（秒）
  lineHeight: number
  followSpeed: boolean
  massive: boolean
  border: boolean
  showColor: boolean
  fontWeight: number
  // 弹幕来源
  sourceBiliBili: boolean
  sourceGamer: boolean
  sourceDanDan: boolean
  // 弹幕屏蔽关键词 - 照抄原项目
  shieldList: string[]
  // Setters
  setEnabled: (enabled: boolean) => void
  setOpacity: (opacity: number) => void
  setSpeed: (speed: number) => void
  setFontSize: (size: number) => void
  setList: (list: Danmaku[]) => void
  setArea: (area: number) => void
  setHideTop: (hide: boolean) => void
  setHideBottom: (hide: boolean) => void
  setHideScroll: (hide: boolean) => void
  setDanmakuDuration: (duration: number) => void
  setLineHeight: (height: number) => void
  setFollowSpeed: (follow: boolean) => void
  setMassive: (massive: boolean) => void
  setBorder: (border: boolean) => void
  setShowColor: (show: boolean) => void
  setFontWeight: (weight: number) => void
  setSourceBiliBili: (enabled: boolean) => void
  setSourceGamer: (enabled: boolean) => void
  setSourceDanDan: (enabled: boolean) => void
  addShieldKeyword: (keyword: string) => void
  removeShieldKeyword: (keyword: string) => void
  clearShieldList: () => void
}

interface HistoryState {
  items: WatchHistoryItem[]
  addItem: (item: WatchHistoryItem) => void
  removeItem: (animeId: number, episodeNumber: number) => void
  clearHistory: () => void
  getProgress: (animeId: number, episodeNumber: number) => number | null
}

interface FavoritesState {
  animeIds: number[]
  addFavorite: (animeId: number) => void
  removeFavorite: (animeId: number) => void
  isFavorited: (animeId: number) => boolean
}

// Combined app state
export interface AppState
  extends AnimeState,
    PlayerState,
    DanmakuState,
    HistoryState,
    FavoritesState {}

// ============================================================================
// Store Implementation
// ============================================================================

export const useAppStore = create<AppState>()(
  persist(
    (set, get) => ({
      // ========================================================================
      // Anime State
      // ========================================================================
      currentAnime: null,
      setCurrentAnime: (anime) => set({ currentAnime: anime }),

      // ========================================================================
      // Player State
      // ========================================================================
      isPlaying: false,
      currentTime: 0,
      duration: 0,
      volume: 1.0,
      isFullscreen: false,
      isPiP: false,
      setIsPlaying: (playing) => set({ isPlaying: playing }),
      setCurrentTime: (time) => set({ currentTime: time }),
      setDuration: (duration) => set({ duration }),
      setVolume: (volume) => {
        // Clamp volume between 0 and 1
        const clampedVolume = Math.max(0, Math.min(1, volume))
        set({ volume: clampedVolume })
      },
      setIsFullscreen: (fullscreen) => set({ isFullscreen: fullscreen }),
      setIsPiP: (pip) => set({ isPiP: pip }),

      // ========================================================================
      // Danmaku State - 照抄原项目默认值
      // 原项目: opacity=1.0, duration=8秒(speed=1.0), fontSize=16-25
      // ========================================================================
      enabled: true,
      opacity: 1.0, // 原项目默认 1.0
      speed: 1.0,   // 1.0 = 8秒持续时间
      fontSize: 20, // 原项目移动端默认 16，桌面端默认 25
      list: [],
      // 额外设置 - 照抄原项目默认值
      area: 1.0,
      hideTop: false,
      hideBottom: true, // 原项目默认隐藏底部弹幕
      hideScroll: false,
      danmakuDuration: 8,
      lineHeight: 1.6,
      followSpeed: true,
      massive: false,
      border: true,
      showColor: true,
      fontWeight: 4,
      sourceBiliBili: true,
      sourceGamer: true,
      sourceDanDan: true,
      shieldList: [],
      // Setters
      setEnabled: (enabled) => set({ enabled }),
      setOpacity: (opacity) => {
        const clampedOpacity = Math.max(0, Math.min(1, opacity))
        set({ opacity: clampedOpacity })
      },
      setSpeed: (speed) => {
        const clampedSpeed = Math.max(0.5, Math.min(2.0, speed))
        set({ speed: clampedSpeed })
      },
      setFontSize: (size) => {
        const clampedSize = Math.max(12, Math.min(32, size))
        set({ fontSize: clampedSize })
      },
      setList: (list) => set({ list }),
      setArea: (area) => set({ area: Math.max(0, Math.min(1, area)) }),
      setHideTop: (hideTop) => set({ hideTop }),
      setHideBottom: (hideBottom) => set({ hideBottom }),
      setHideScroll: (hideScroll) => set({ hideScroll }),
      setDanmakuDuration: (danmakuDuration) => set({ danmakuDuration: Math.max(2, Math.min(16, danmakuDuration)) }),
      setLineHeight: (lineHeight) => set({ lineHeight: Math.max(0, Math.min(3, lineHeight)) }),
      setFollowSpeed: (followSpeed) => set({ followSpeed }),
      setMassive: (massive) => set({ massive }),
      setBorder: (border) => set({ border }),
      setShowColor: (showColor) => set({ showColor }),
      setFontWeight: (fontWeight) => set({ fontWeight: Math.max(1, Math.min(9, fontWeight)) }),
      setSourceBiliBili: (sourceBiliBili) => set({ sourceBiliBili }),
      setSourceGamer: (sourceGamer) => set({ sourceGamer }),
      setSourceDanDan: (sourceDanDan) => set({ sourceDanDan }),
      addShieldKeyword: (keyword) =>
        set((state) => {
          const trimmed = keyword.trim()
          if (trimmed && !state.shieldList.includes(trimmed)) {
            return { shieldList: [...state.shieldList, trimmed] }
          }
          return state
        }),
      removeShieldKeyword: (keyword) =>
        set((state) => ({
          shieldList: state.shieldList.filter((k) => k !== keyword),
        })),
      clearShieldList: () => set({ shieldList: [] }),

      // ========================================================================
      // History State
      // ========================================================================
      items: [],
      addItem: (item) =>
        set((state) => {
          // Remove existing entry for same anime/episode if exists
          const filtered = state.items.filter(
            (i) =>
              !(
                i.animeId === item.animeId &&
                i.episodeNumber === item.episodeNumber
              )
          )
          // Add new item at the beginning (most recent first)
          return { items: [item, ...filtered] }
        }),
      removeItem: (animeId, episodeNumber) =>
        set((state) => ({
          items: state.items.filter(
            (i) =>
              !(i.animeId === animeId && i.episodeNumber === episodeNumber)
          ),
        })),
      clearHistory: () => set({ items: [] }),
      getProgress: (animeId, episodeNumber) => {
        const item = get().items.find(
          (i) => i.animeId === animeId && i.episodeNumber === episodeNumber
        )
        return item ? item.time : null
      },

      // ========================================================================
      // Favorites State
      // ========================================================================
      animeIds: [],
      addFavorite: (animeId) =>
        set((state) => {
          if (!state.animeIds.includes(animeId)) {
            return { animeIds: [...state.animeIds, animeId] }
          }
          return state
        }),
      removeFavorite: (animeId) =>
        set((state) => ({
          animeIds: state.animeIds.filter((id) => id !== animeId),
        })),
      isFavorited: (animeId) => {
        return get().animeIds.includes(animeId)
      },
    }),
    {
      name: 'ios-liquid-glass-player-storage',
      storage: createJSONStorage(() => localStorage),
      // Only persist certain slices
      partialize: (state) => ({
        // Persist danmaku settings
        enabled: state.enabled,
        opacity: state.opacity,
        speed: state.speed,
        fontSize: state.fontSize,
        area: state.area,
        hideTop: state.hideTop,
        hideBottom: state.hideBottom,
        hideScroll: state.hideScroll,
        danmakuDuration: state.danmakuDuration,
        lineHeight: state.lineHeight,
        followSpeed: state.followSpeed,
        massive: state.massive,
        border: state.border,
        showColor: state.showColor,
        fontWeight: state.fontWeight,
        sourceBiliBili: state.sourceBiliBili,
        sourceGamer: state.sourceGamer,
        sourceDanDan: state.sourceDanDan,
        shieldList: state.shieldList,
        // Persist history and favorites
        items: state.items,
        animeIds: state.animeIds,
        // Persist volume
        volume: state.volume,
      }),
    }
  )
)

// ============================================================================
// Slice Selectors (for optimized re-renders)
// Using useShallow for shallow comparison to prevent unnecessary re-renders
// ============================================================================

export const useAnimeState = () =>
  useAppStore(
    useShallow((state) => ({
      currentAnime: state.currentAnime,
      setCurrentAnime: state.setCurrentAnime,
    }))
  )

export const usePlayerState = () =>
  useAppStore(
    useShallow((state) => ({
      isPlaying: state.isPlaying,
      currentTime: state.currentTime,
      duration: state.duration,
      volume: state.volume,
      isFullscreen: state.isFullscreen,
      isPiP: state.isPiP,
      setIsPlaying: state.setIsPlaying,
      setCurrentTime: state.setCurrentTime,
      setDuration: state.setDuration,
      setVolume: state.setVolume,
      setIsFullscreen: state.setIsFullscreen,
      setIsPiP: state.setIsPiP,
    }))
  )

export const useDanmakuState = () =>
  useAppStore(
    useShallow((state) => ({
      enabled: state.enabled,
      opacity: state.opacity,
      speed: state.speed,
      fontSize: state.fontSize,
      list: state.list,
      area: state.area,
      hideTop: state.hideTop,
      hideBottom: state.hideBottom,
      hideScroll: state.hideScroll,
      duration: state.danmakuDuration,
      lineHeight: state.lineHeight,
      followSpeed: state.followSpeed,
      massive: state.massive,
      border: state.border,
      showColor: state.showColor,
      fontWeight: state.fontWeight,
      sourceBiliBili: state.sourceBiliBili,
      sourceGamer: state.sourceGamer,
      sourceDanDan: state.sourceDanDan,
      shieldList: state.shieldList,
      setEnabled: state.setEnabled,
      setOpacity: state.setOpacity,
      setSpeed: state.setSpeed,
      setFontSize: state.setFontSize,
      setList: state.setList,
      setArea: state.setArea,
      setHideTop: state.setHideTop,
      setHideBottom: state.setHideBottom,
      setHideScroll: state.setHideScroll,
      setDuration: state.setDanmakuDuration,
      setLineHeight: state.setLineHeight,
      setFollowSpeed: state.setFollowSpeed,
      setMassive: state.setMassive,
      setBorder: state.setBorder,
      setShowColor: state.setShowColor,
      setFontWeight: state.setFontWeight,
      setSourceBiliBili: state.setSourceBiliBili,
      setSourceGamer: state.setSourceGamer,
      setSourceDanDan: state.setSourceDanDan,
      addShieldKeyword: state.addShieldKeyword,
      removeShieldKeyword: state.removeShieldKeyword,
      clearShieldList: state.clearShieldList,
    }))
  )

export const useHistoryState = () =>
  useAppStore(
    useShallow((state) => ({
      items: state.items,
      addItem: state.addItem,
      removeItem: state.removeItem,
      clearHistory: state.clearHistory,
      getProgress: state.getProgress,
    }))
  )

export const useFavoritesState = () =>
  useAppStore(
    useShallow((state) => ({
      animeIds: state.animeIds,
      addFavorite: state.addFavorite,
      removeFavorite: state.removeFavorite,
      isFavorited: state.isFavorited,
    }))
  )
