/**
 * usePlayerSettings - 播放设置 Hook
 * 照抄原项目的 player_settings.dart
 * 
 * 功能:
 * - 自动跳转 (恢复上次播放位置)
 * - 自动连播
 * - 默认倍速
 * - 广告过滤
 * - 隐身模式 (不保留观看记录)
 * - 错误提示
 * - 调试模式
 * - 禁用动画
 * - 默认视频比例
 * - 方向键快进秒数
 */

import { useState, useEffect, useCallback } from 'react'

const SETTINGS_KEY = 'kazumi_player_settings'

// 视频比例类型 - 照抄原项目 aspectRatioTypeMap
export const ASPECT_RATIO_MAP: Record<number, string> = {
  0: '自动',
  1: '拉伸',
  2: '填充',
  3: '16:9',
  4: '4:3',
}

export interface PlayerSettings {
  /** 自动跳转到上次播放位置 */
  playResume: boolean
  /** 自动连播 */
  autoPlayNext: boolean
  /** 默认倍速 */
  defaultPlaySpeed: number
  /** 强制广告过滤 */
  forceAdBlocker: boolean
  /** 隐身模式 - 不保留观看记录 */
  privateMode: boolean
  /** 跳过按钮秒数 */
  buttonSkipTime: number
  /** 方向键快进/快退秒数 */
  arrowKeySkipTime: number
  /** 默认视频比例 */
  defaultAspectRatioType: number
  /** 显示播放器错误提示 */
  showPlayerError: boolean
  /** 调试模式 - 记录播放器日志 */
  playerDebugMode: boolean
  /** 禁用播放器动画 */
  playerDisableAnimations: boolean
}

const DEFAULT_SETTINGS: PlayerSettings = {
  playResume: true,
  autoPlayNext: true,
  defaultPlaySpeed: 1.0,
  forceAdBlocker: false,
  privateMode: false,
  buttonSkipTime: 80,
  arrowKeySkipTime: 10,
  defaultAspectRatioType: 0,
  showPlayerError: true,
  playerDebugMode: false,
  playerDisableAnimations: false,
}

export function usePlayerSettings() {
  const [settings, setSettings] = useState<PlayerSettings>(DEFAULT_SETTINGS)
  const [loaded, setLoaded] = useState(false)

  // 加载设置
  useEffect(() => {
    try {
      if (typeof window === 'undefined') return
      
      const saved = localStorage.getItem(SETTINGS_KEY)
      if (saved) {
        const parsed = JSON.parse(saved)
        setSettings({ ...DEFAULT_SETTINGS, ...parsed })
      }
    } catch (e) {
      console.error('Failed to load player settings:', e)
    }
    setLoaded(true)
  }, [])

  // 更新单个设置
  const updateSetting = useCallback(<K extends keyof PlayerSettings>(
    key: K,
    value: PlayerSettings[K]
  ) => {
    setSettings(prev => {
      const newSettings = { ...prev, [key]: value }
      try {
        localStorage.setItem(SETTINGS_KEY, JSON.stringify(newSettings))
      } catch (e) {
        console.error('Failed to save player settings:', e)
      }
      return newSettings
    })
  }, [])

  // 更新多个设置
  const updateSettings = useCallback((updates: Partial<PlayerSettings>) => {
    setSettings(prev => {
      const newSettings = { ...prev, ...updates }
      try {
        localStorage.setItem(SETTINGS_KEY, JSON.stringify(newSettings))
      } catch (e) {
        console.error('Failed to save player settings:', e)
      }
      return newSettings
    })
  }, [])

  // 重置为默认设置
  const resetSettings = useCallback(() => {
    setSettings(DEFAULT_SETTINGS)
    try {
      localStorage.setItem(SETTINGS_KEY, JSON.stringify(DEFAULT_SETTINGS))
    } catch (e) {
      console.error('Failed to reset player settings:', e)
    }
  }, [])

  return {
    settings,
    loaded,
    updateSetting,
    updateSettings,
    resetSettings,
  }
}
