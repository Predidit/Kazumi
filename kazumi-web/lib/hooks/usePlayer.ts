/**
 * Custom React hook for video player state management
 * Provides methods to control playback, volume, fullscreen, etc.
 */

import { useCallback, useEffect, useRef } from 'react'
import { useAppStore } from '@/lib/store'

interface UsePlayerOptions {
  animeId?: number
  episodeNumber?: number
  autoSaveProgress?: boolean
  saveInterval?: number // milliseconds
}

interface UsePlayerResult {
  isPlaying: boolean
  currentTime: number
  duration: number
  volume: number
  isFullscreen: boolean
  isPiP: boolean
  play: () => void
  pause: () => void
  togglePlay: () => void
  seek: (time: number) => void
  setVolume: (volume: number) => void
  toggleFullscreen: () => void
  togglePiP: () => void
  updateTime: (time: number) => void
  updateDuration: (duration: number) => void
  saveProgress: () => void
  loadProgress: () => number | null
}

/**
 * Hook for managing video player state
 * @param options - Player options including anime ID and episode number for history tracking
 * @returns Player state and control methods
 */
export function usePlayer(options: UsePlayerOptions = {}): UsePlayerResult {
  const {
    animeId,
    episodeNumber,
    autoSaveProgress = true,
    saveInterval = 5000,
  } = options

  // Get individual state values and actions from store
  const isPlaying = useAppStore((state) => state.isPlaying)
  const currentTime = useAppStore((state) => state.currentTime)
  const duration = useAppStore((state) => state.duration)
  const volume = useAppStore((state) => state.volume)
  const isFullscreen = useAppStore((state) => state.isFullscreen)
  const isPiP = useAppStore((state) => state.isPiP)
  
  // Get actions (these are stable references)
  const setIsPlaying = useAppStore((state) => state.setIsPlaying)
  const setCurrentTime = useAppStore((state) => state.setCurrentTime)
  const setDuration = useAppStore((state) => state.setDuration)
  const setVolume = useAppStore((state) => state.setVolume)
  const setIsFullscreen = useAppStore((state) => state.setIsFullscreen)
  const setIsPiP = useAppStore((state) => state.setIsPiP)
  const addItem = useAppStore((state) => state.addItem)
  const getProgress = useAppStore((state) => state.getProgress)

  const saveTimerRef = useRef<NodeJS.Timeout | null>(null)
  const currentTimeRef = useRef(currentTime)
  const durationRef = useRef(duration)

  // Keep refs updated
  useEffect(() => {
    currentTimeRef.current = currentTime
  }, [currentTime])

  useEffect(() => {
    durationRef.current = duration
  }, [duration])

  /**
   * Play video
   */
  const play = useCallback(() => {
    setIsPlaying(true)
  }, [setIsPlaying])

  /**
   * Pause video
   */
  const pause = useCallback(() => {
    setIsPlaying(false)
  }, [setIsPlaying])

  /**
   * Toggle play/pause
   */
  const togglePlay = useCallback(() => {
    setIsPlaying(!isPlaying)
  }, [setIsPlaying, isPlaying])

  /**
   * Seek to specific time
   */
  const seek = useCallback(
    (time: number) => {
      // Clamp time between 0 and duration
      const clampedTime = Math.max(0, Math.min(durationRef.current, time))
      setCurrentTime(clampedTime)
    },
    [setCurrentTime]
  )

  /**
   * Set volume level
   */
  const setVolumeLevel = useCallback(
    (vol: number) => {
      setVolume(vol)
    },
    [setVolume]
  )

  /**
   * Toggle fullscreen mode
   */
  const toggleFullscreen = useCallback(() => {
    setIsFullscreen(!isFullscreen)
  }, [setIsFullscreen, isFullscreen])

  /**
   * Toggle picture-in-picture mode
   */
  const togglePiP = useCallback(() => {
    setIsPiP(!isPiP)
  }, [setIsPiP, isPiP])

  /**
   * Update current time
   */
  const updateTime = useCallback(
    (time: number) => {
      setCurrentTime(time)
    },
    [setCurrentTime]
  )

  /**
   * Update duration
   */
  const updateDuration = useCallback(
    (dur: number) => {
      setDuration(dur)
    },
    [setDuration]
  )

  /**
   * Save watch progress to history
   */
  const saveProgress = useCallback(() => {
    if (animeId !== undefined && episodeNumber !== undefined) {
      const time = currentTimeRef.current
      const dur = durationRef.current
      // Only save if we have meaningful progress (not at the very beginning or end)
      if (time > 5 && time < dur - 10) {
        addItem({
          animeId,
          episodeNumber,
          time,
          timestamp: Date.now(),
          animeTitle: '', // Will be filled by the component
          animeCover: '', // Will be filled by the component
        })
      }
    }
  }, [animeId, episodeNumber, addItem])

  /**
   * Load saved progress from history
   */
  const loadProgress = useCallback((): number | null => {
    if (animeId !== undefined && episodeNumber !== undefined) {
      return getProgress(animeId, episodeNumber)
    }
    return null
  }, [animeId, episodeNumber, getProgress])

  /**
   * Auto-save progress at intervals
   */
  useEffect(() => {
    if (autoSaveProgress && isPlaying) {
      // Clear existing timer
      if (saveTimerRef.current) {
        clearInterval(saveTimerRef.current)
      }

      // Set up new timer
      saveTimerRef.current = setInterval(() => {
        saveProgress()
      }, saveInterval)

      return () => {
        if (saveTimerRef.current) {
          clearInterval(saveTimerRef.current)
        }
      }
    }
  }, [autoSaveProgress, isPlaying, saveProgress, saveInterval])

  /**
   * Save progress when component unmounts
   */
  useEffect(() => {
    return () => {
      if (autoSaveProgress) {
        saveProgress()
      }
    }
  }, [autoSaveProgress, saveProgress])

  return {
    isPlaying,
    currentTime,
    duration,
    volume,
    isFullscreen,
    isPiP,
    play,
    pause,
    togglePlay,
    seek,
    setVolume: setVolumeLevel,
    toggleFullscreen,
    togglePiP,
    updateTime,
    updateDuration,
    saveProgress,
    loadProgress,
  }
}
