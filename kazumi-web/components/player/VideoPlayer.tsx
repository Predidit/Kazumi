/**
 * VideoPlayer Component - 照抄 Kazumi 的 player_item.dart + player_item_panel.dart
 * 
 * 功能:
 * - 视频播放 (HLS/MP4)
 * - 进度条 (可拖动) - 照抄原项目的 ProgressBar
 * - 播放/暂停按钮
 * - 时间显示 (当前时间 / 总时长)
 * - 下一集按钮
 * - 弹幕显示和设置
 * - 自动隐藏控制栏 (4秒)
 * - 手势控制 - 照抄原项目:
 *   - 长按加速 (2x) - onLongPressStart/End
 *   - 水平滑动快进/快退 - onHorizontalDragUpdate
 *   - 左侧垂直滑动调节亮度 - onVerticalDragUpdate
 *   - 右侧垂直滑动调节音量 - onVerticalDragUpdate
 * 
 * Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 6.1, 8.1
 */

'use client'

import { useEffect, useRef, useState, useCallback } from 'react'
import Hls from 'hls.js'
import { usePlayer } from '@/lib/hooks/usePlayer'
import { useDanmaku } from '@/lib/hooks/useDanmaku'
import { usePlayerSettings } from '@/lib/hooks/usePlayerSettings'
import { historyManager } from '@/lib/storage/history'
import { NextEpisodeSuggestion } from './NextEpisodeSuggestion'
import { DanmakuCanvas } from './DanmakuCanvas'
import { DanmakuSettings } from './DanmakuSettings'
import { SuperResolutionRenderer } from './SuperResolutionRenderer'

export interface VideoPlayerProps {
  videoUrl: string
  animeId: number
  episodeNumber: number
  totalEpisodes?: number
  animeTitle?: string
  animeCover?: string
  nextEpisodeTitle?: string
  onTimeUpdate?: (time: number) => void
  onEnded?: () => void
  onPlayNext?: () => void
  onReady?: () => void
  onError?: (error: string) => void
  autoPlay?: boolean
  showNativeControls?: boolean
  showNextEpisodeSuggestion?: boolean
  enableDanmaku?: boolean
  showDanmakuSettings?: boolean
  className?: string
}

/**
 * 格式化时间 - 照抄原项目的 Utils.durationToString
 */
function formatDuration(seconds: number): string {
  if (!isFinite(seconds) || seconds < 0) return '00:00'
  
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const secs = Math.floor(seconds % 60)
  
  if (hours > 0) {
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }
  
  return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
}

/**
 * 可选播放倍速 - 照抄原项目的 defaultPlaySpeedList
 */
const DEFAULT_PLAY_SPEED_LIST = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0]

export function VideoPlayer({
  videoUrl,
  animeId,
  episodeNumber,
  totalEpisodes,
  animeTitle = '',
  animeCover = '',
  nextEpisodeTitle,
  onTimeUpdate,
  onEnded,
  onPlayNext,
  onReady,
  onError,
  autoPlay = false,
  showNativeControls = false,
  showNextEpisodeSuggestion = true,
  enableDanmaku = true,
  showDanmakuSettings = true,
  className = '',
}: VideoPlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const containerRef = useRef<HTMLDivElement>(null)
  const progressBarRef = useRef<HTMLDivElement>(null)
  const hlsRef = useRef<Hls | null>(null)
  const hideTimerRef = useRef<NodeJS.Timeout | null>(null)
  const playerTimerRef = useRef<NodeJS.Timeout | null>(null)
  
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [hasLoadedProgress, setHasLoadedProgress] = useState(false)
  const [showNextEpisode, setShowNextEpisode] = useState(false)
  const [showSettings, setShowSettings] = useState(false)
  const [containerSize, setContainerSize] = useState({ width: 0, height: 0 })

  // 控制栏状态
  const [showControls, setShowControls] = useState(true)
  const [isDragging, setIsDragging] = useState(false)
  const [dragTime, setDragTime] = useState<number | null>(null)
  const [showSpeedMenu, setShowSpeedMenu] = useState(false)
  const [wasPlayingBeforeDrag, setWasPlayingBeforeDrag] = useState(false)
  
  // 手势控制状态 - 照抄原项目
  const [isLongPressing, setIsLongPressing] = useState(false)
  const [showPlaySpeed, setShowPlaySpeed] = useState(false)
  const [isHorizontalDragging, setIsHorizontalDragging] = useState(false)
  const [isVerticalDragging, setIsVerticalDragging] = useState(false)
  const [showBrightness, setShowBrightness] = useState(false)
  const [showVolume, setShowVolume] = useState(false)
  const [brightness, setBrightness] = useState(1.0)
  const [volume, setVolume] = useState(1.0)
  const [seekTime, setSeekTime] = useState<number | null>(null)
  const [showSeekTime, setShowSeekTime] = useState(false)
  const longPressTimerRef = useRef<NodeJS.Timeout | null>(null)
  const gestureStartRef = useRef<{ x: number; y: number } | null>(null)
  
  // 双击快进/快退状态 - 类似YouTube/抖音
  const [doubleTapSkip, setDoubleTapSkip] = useState<{ side: 'left' | 'right'; seconds: number } | null>(null)
  const doubleTapTimerRef = useRef<NodeJS.Timeout | null>(null)
  const lastTapRef = useRef<{ time: number; x: number } | null>(null)
  
  // 倍速锁定状态 - 用户自定义功能
  // speedLocked: 当前是否锁定了倍速（下滑锁定后，松手保持2倍速）
  const [speedLocked, setSpeedLocked] = useState(false)
  const speedLockedRef = useRef(false) // 使用 ref 来跟踪最新状态
  const longPressStartYRef = useRef<number | null>(null)
  // 保存用户的原始速度（锁定前的速度，默认1.0）
  const originalSpeedRef = useRef(1.0)
  
  // 同步 speedLocked 状态到 ref
  useEffect(() => {
    speedLockedRef.current = speedLocked
  }, [speedLocked])
  
  // 网速监测状态 - 使用 EWMA 算法，iOS Safari 兼容
  const [networkSpeed, setNetworkSpeed] = useState<string>('')
  const lastBytesRef = useRef<number>(0)
  const lastTimeRef = useRef<number>(0)
  // EWMA 带宽估算（字节/秒）
  const ewmaBandwidthRef = useRef<number>(0)
  // EWMA 平滑因子 (0-1)，值越小越平滑
  const EWMA_ALPHA = 0.3
  
  // 播放状态 - 照抄原项目的 playerController 状态
  const [isPlaying, setIsPlaying] = useState(false)
  const [currentTime, setCurrentTime] = useState(0)
  const [duration, setDuration] = useState(0)
  const [buffered, setBuffered] = useState(0)
  const [isBuffering, setIsBuffering] = useState(false)
  const [playbackSpeed, setPlaybackSpeed] = useState(1.0)

  // Use player settings hook - 照抄原项目的播放设置
  const { settings: playerSettings, loaded: settingsLoaded } = usePlayerSettings()

  // Use player hook for state management
  // 根据 privateMode 设置决定是否自动保存进度
  const player = usePlayer({
    animeId,
    episodeNumber,
    autoSaveProgress: !playerSettings.privateMode, // 隐身模式下不保存进度
    saveInterval: 5000,
  })

  // Use danmaku hook - 支持标题备用搜索
  const danmaku = useDanmaku({
    animeId,
    episodeNumber,
    animeTitle,
    autoFetch: enableDanmaku,
  })

  /**
   * 自动隐藏控制栏 - 照抄原项目的 startHideTimer (4秒)
   */
  const startHideTimer = useCallback(() => {
    if (hideTimerRef.current) {
      clearTimeout(hideTimerRef.current)
    }
    hideTimerRef.current = setTimeout(() => {
      if (isPlaying && !isDragging && !showSettings && !showSpeedMenu) {
        setShowControls(false)
      }
    }, 4000)
  }, [isPlaying, isDragging, showSettings, showSpeedMenu])

  const cancelHideTimer = useCallback(() => {
    if (hideTimerRef.current) {
      clearTimeout(hideTimerRef.current)
      hideTimerRef.current = null
    }
  }, [])

  const displayControls = useCallback(() => {
    setShowControls(true)
    cancelHideTimer()
    startHideTimer()
  }, [cancelHideTimer, startHideTimer])

  /**
   * 播放/暂停 - 照抄原项目的 playOrPause
   */
  const handlePlayPause = useCallback(() => {
    const video = videoRef.current
    if (!video) return

    if (video.paused) {
      video.play().catch(console.error)
    } else {
      video.pause()
    }
  }, [])

  /**
   * 跳转 - 照抄原项目的 seek
   */
  const handleSeek = useCallback((time: number) => {
    const video = videoRef.current
    if (!video || !isFinite(time)) return

    const clampedTime = Math.max(0, Math.min(time, duration))
    video.currentTime = clampedTime
    setCurrentTime(clampedTime)
    player.seek(clampedTime)
  }, [duration, player])

  /**
   * 设置播放倍速 - 照抄原项目的 setPlaybackSpeed
   */
  const handleSetPlaybackSpeed = useCallback((speed: number) => {
    const video = videoRef.current
    if (!video) return

    video.playbackRate = speed
    setPlaybackSpeed(speed)
    setShowSpeedMenu(false)
    startHideTimer()
  }, [startHideTimer])

  /**
   * 计算进度条位置对应的时间
   */
  const getTimeFromProgressBar = useCallback((clientX: number): number => {
    if (!progressBarRef.current || duration <= 0) return 0
    const rect = progressBarRef.current.getBoundingClientRect()
    const percent = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width))
    return percent * duration
  }, [duration])

  /**
   * 进度条拖动开始 - 照抄原项目的 handleProgressBarDragStart
   */
  const handleProgressDragStart = useCallback((clientX: number) => {
    const video = videoRef.current
    if (!video) return

    setIsDragging(true)
    setWasPlayingBeforeDrag(!video.paused)
    cancelHideTimer()
    
    // 暂停视频 - 照抄原项目
    if (!video.paused) {
      video.pause()
    }
    
    const time = getTimeFromProgressBar(clientX)
    setDragTime(time)
  }, [cancelHideTimer, getTimeFromProgressBar])

  /**
   * 进度条拖动中
   */
  const handleProgressDragMove = useCallback((clientX: number) => {
    if (!isDragging) return
    const time = getTimeFromProgressBar(clientX)
    setDragTime(time)
  }, [isDragging, getTimeFromProgressBar])

  /**
   * 进度条拖动结束 - 照抄原项目的 handleProgressBarDragEnd
   */
  const handleProgressDragEnd = useCallback(() => {
    if (!isDragging) return
    
    const video = videoRef.current
    if (video && dragTime !== null) {
      video.currentTime = dragTime
      setCurrentTime(dragTime)
      
      // 恢复播放 - 照抄原项目
      if (wasPlayingBeforeDrag) {
        video.play().catch(console.error)
      }
    }
    
    setIsDragging(false)
    setDragTime(null)
    startHideTimer()
  }, [isDragging, dragTime, wasPlayingBeforeDrag, startHideTimer])

  /**
   * 进度条点击
   */
  const handleProgressClick = useCallback((e: React.MouseEvent) => {
    if (isDragging) return
    const time = getTimeFromProgressBar(e.clientX)
    handleSeek(time)
  }, [isDragging, getTimeFromProgressBar, handleSeek])

  /**
   * 鼠标事件处理
   */
  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    e.preventDefault()
    handleProgressDragStart(e.clientX)
  }, [handleProgressDragStart])

  /**
   * 触摸事件处理
   */
  const handleTouchStart = useCallback((e: React.TouchEvent) => {
    e.preventDefault()
    if (e.touches.length > 0) {
      handleProgressDragStart(e.touches[0].clientX)
    }
  }, [handleProgressDragStart])

  /**
   * 长按开始 - 照抄原项目的 onLongPressStart
   * 长按加速到 2x
   */
  const handleLongPressStart = useCallback((startY: number) => {
    const video = videoRef.current
    if (!video) return

    setIsLongPressing(true)
    setShowPlaySpeed(true)
    
    // 只有在未锁定状态下才保存原始速度
    // 如果已经锁定了2倍速，不要覆盖原始速度
    if (!speedLockedRef.current) {
      originalSpeedRef.current = video.playbackRate
    }
    
    longPressStartYRef.current = startY
    
    // 长按时始终设置为2倍速
    video.playbackRate = 2.0
    setPlaybackSpeed(2.0)
  }, [])

  /**
   * 长按结束 - 照抄原项目的 onLongPressEnd
   * 松手时：如果已锁定倍速则保持2倍速，否则恢复原来的速度
   */
  const handleLongPressEnd = useCallback(() => {
    const video = videoRef.current
    if (!video || !isLongPressing) return

    setIsLongPressing(false)
    setShowPlaySpeed(false)
    longPressStartYRef.current = null
    
    // 使用 ref 获取最新的 speedLocked 状态
    const isLocked = speedLockedRef.current
    const originalSpeed = originalSpeedRef.current
    console.log('长按结束，speedLocked:', isLocked, 'originalSpeed:', originalSpeed)
    
    // 如果已锁定倍速，保持2倍速；否则恢复原来的速度
    if (isLocked) {
      // 保持2倍速
      video.playbackRate = 2.0
      setPlaybackSpeed(2.0)
    } else {
      // 恢复原始速度（锁定前的速度）
      video.playbackRate = originalSpeed
      setPlaybackSpeed(originalSpeed)
    }
  }, [isLongPressing])

  /**
   * 手势触摸开始 - 记录起始位置
   */
  const handleGestureTouchStart = useCallback((e: React.TouchEvent) => {
    if (e.touches.length !== 1) return
    
    const touch = e.touches[0]
    gestureStartRef.current = { x: touch.clientX, y: touch.clientY }
    
    // 启动长按计时器 - 照抄原项目
    longPressTimerRef.current = setTimeout(() => {
      handleLongPressStart(touch.clientY)
    }, 500) // 500ms 触发长按
  }, [handleLongPressStart])

  /**
   * 手势触摸移动 - 照抄原项目的 onHorizontalDragUpdate / onVerticalDragUpdate
   * 新增: 长按状态下上滑解锁倍速，下滑锁定倍速
   */
  const handleGestureTouchMove = useCallback((e: React.TouchEvent) => {
    if (e.touches.length !== 1 || !gestureStartRef.current) return
    
    const touch = e.touches[0]
    const deltaX = touch.clientX - gestureStartRef.current.x
    const deltaY = touch.clientY - gestureStartRef.current.y
    const container = containerRef.current
    if (!container) return

    const containerRect = container.getBoundingClientRect()
    const totalWidth = containerRect.width
    const totalHeight = containerRect.height

    // 如果正在长按，检测上滑/下滑来解锁/锁定倍速
    if (isLongPressing && longPressStartYRef.current !== null) {
      const verticalDelta = touch.clientY - longPressStartYRef.current
      const verticalThreshold = 50 // 需要滑动50px才触发
      
      if (verticalDelta < -verticalThreshold) {
        // 上滑 - 解锁倍速（松手后恢复正常速度）
        console.log('检测到上滑，当前speedLocked:', speedLocked, '解锁倍速')
        setSpeedLocked(false)
        // 重置起始位置，避免重复触发
        longPressStartYRef.current = touch.clientY
      } else if (verticalDelta > verticalThreshold) {
        // 下滑 - 锁定倍速（松手后保持2倍速）
        console.log('检测到下滑，当前speedLocked:', speedLocked, '锁定倍速')
        setSpeedLocked(true)
        // 重置起始位置，避免重复触发
        longPressStartYRef.current = touch.clientY
      }
      return
    }

    // 判断是水平还是垂直滑动 (首次移动超过阈值时确定方向)
    const threshold = 10
    if (!isHorizontalDragging && !isVerticalDragging) {
      if (Math.abs(deltaX) > threshold || Math.abs(deltaY) > threshold) {
        // 取消长按计时器
        if (longPressTimerRef.current) {
          clearTimeout(longPressTimerRef.current)
          longPressTimerRef.current = null
        }

        if (Math.abs(deltaX) > Math.abs(deltaY)) {
          // 水平滑动 - 快进/快退
          setIsHorizontalDragging(true)
          setShowSeekTime(true)
          cancelHideTimer()
        } else {
          // 垂直滑动 - 亮度/音量
          setIsVerticalDragging(true)
        }
      }
      return
    }

    // 水平滑动 - 照抄原项目的 onHorizontalDragUpdate
    if (isHorizontalDragging) {
      const video = videoRef.current
      if (!video) return

      // 照抄原项目: scale = 180000 / width (毫秒)
      const scale = 180 / totalWidth // 秒
      const seekDelta = deltaX * scale
      const newTime = Math.max(0, Math.min(duration, currentTime + seekDelta))
      setSeekTime(newTime)
    }

    // 垂直滑动 - 照抄原项目的 onVerticalDragUpdate
    if (isVerticalDragging) {
      const tapPosition = gestureStartRef.current.x
      const sectionWidth = totalWidth / 2
      const level = totalHeight * 2

      // 计算增量 (向上滑动为负值，需要增加)
      const delta = -deltaY / level

      if (tapPosition < sectionWidth) {
        // 左边区域 - 调节亮度
        setShowBrightness(true)
        const newBrightness = Math.max(0, Math.min(1, brightness + delta))
        setBrightness(newBrightness)
        // 应用亮度 (CSS filter)
        if (containerRef.current) {
          const videoEl = containerRef.current.querySelector('video')
          if (videoEl) {
            videoEl.style.filter = `brightness(${newBrightness})`
          }
        }
      } else {
        // 右边区域 - 调节音量
        setShowVolume(true)
        const video = videoRef.current
        if (video) {
          const newVolume = Math.max(0, Math.min(1, volume + delta))
          setVolume(newVolume)
          video.volume = newVolume
        }
      }

      // 更新起始位置以实现连续调节
      gestureStartRef.current = { x: gestureStartRef.current.x, y: touch.clientY }
    }
  }, [isLongPressing, isHorizontalDragging, isVerticalDragging, duration, currentTime, brightness, volume, cancelHideTimer, speedLocked])

  /**
   * 手势触摸结束 - 照抄原项目的 onHorizontalDragEnd / onVerticalDragEnd
   */
  const handleGestureTouchEnd = useCallback(() => {
    // 清除长按计时器
    if (longPressTimerRef.current) {
      clearTimeout(longPressTimerRef.current)
      longPressTimerRef.current = null
    }

    // 处理长按结束
    if (isLongPressing) {
      handleLongPressEnd()
    }

    // 处理水平滑动结束 - 跳转到目标时间
    if (isHorizontalDragging && seekTime !== null) {
      const video = videoRef.current
      if (video) {
        video.currentTime = seekTime
        setCurrentTime(seekTime)
      }
      setShowSeekTime(false)
      setSeekTime(null)
      startHideTimer()
    }

    // 处理垂直滑动结束
    if (isVerticalDragging) {
      // 延迟隐藏亮度/音量指示器
      setTimeout(() => {
        setShowBrightness(false)
        setShowVolume(false)
      }, 500)
    }

    // 重置状态
    setIsHorizontalDragging(false)
    setIsVerticalDragging(false)
    gestureStartRef.current = null
  }, [isLongPressing, isHorizontalDragging, isVerticalDragging, seekTime, handleLongPressEnd, startHideTimer])

  // 全局鼠标/触摸事件
  useEffect(() => {
    if (!isDragging) return

    const handleMouseMove = (e: MouseEvent) => {
      handleProgressDragMove(e.clientX)
    }

    const handleMouseUp = () => {
      handleProgressDragEnd()
    }

    const handleTouchMove = (e: TouchEvent) => {
      if (e.touches.length > 0) {
        handleProgressDragMove(e.touches[0].clientX)
      }
    }

    const handleTouchEnd = () => {
      handleProgressDragEnd()
    }

    window.addEventListener('mousemove', handleMouseMove)
    window.addEventListener('mouseup', handleMouseUp)
    window.addEventListener('touchmove', handleTouchMove, { passive: false })
    window.addEventListener('touchend', handleTouchEnd)

    return () => {
      window.removeEventListener('mousemove', handleMouseMove)
      window.removeEventListener('mouseup', handleMouseUp)
      window.removeEventListener('touchmove', handleTouchMove)
      window.removeEventListener('touchend', handleTouchEnd)
    }
  }, [isDragging, handleProgressDragMove, handleProgressDragEnd])

  /**
   * 播放器定时器 - 照抄原项目的 getPlayerTimer
   * 原项目每秒更新一次状态
   */
  useEffect(() => {
    playerTimerRef.current = setInterval(() => {
      const video = videoRef.current
      if (!video) return

      // 不在拖动时更新时间
      if (!isDragging) {
        setCurrentTime(video.currentTime)
      }
      setIsPlaying(!video.paused)
      setIsBuffering(video.readyState < 3 && !video.paused)
      
      if (video.buffered.length > 0) {
        setBuffered(video.buffered.end(video.buffered.length - 1))
      }

      // 网速计算 - 使用 EWMA 算法估算带宽，iOS Safari 兼容
      // 原理：通过监测视频缓冲区增长来估算下载速度
      // 假设视频比特率约 2-4 Mbps（常见的720p-1080p视频）
      const now = Date.now()
      if (video.buffered.length > 0 && video.duration > 0) {
        const currentBufferedEnd = video.buffered.end(video.buffered.length - 1)
        
        if (lastTimeRef.current > 0 && lastBytesRef.current >= 0) {
          const timeDeltaMs = now - lastTimeRef.current
          const bufferDeltaSec = currentBufferedEnd - lastBytesRef.current // 缓冲增量（视频秒数）
          
          // 至少500ms才更新，避免抖动
          if (timeDeltaMs >= 500) {
            if (bufferDeltaSec > 0) {
              // 估算视频比特率（根据视频时长估算）
              // 短视频（<10分钟）通常比特率较高，长视频较低
              const estimatedBitrate = video.duration < 600 
                ? 4 * 1024 * 1024  // 4 Mbps for short videos
                : 2.5 * 1024 * 1024 // 2.5 Mbps for longer videos
              
              // 计算下载的字节数 = 缓冲的视频秒数 * 比特率 / 8
              const downloadedBytes = bufferDeltaSec * estimatedBitrate / 8
              // 计算当前速度（字节/秒）
              const currentSpeed = downloadedBytes / (timeDeltaMs / 1000)
              
              // 使用 EWMA 平滑速度估算
              if (ewmaBandwidthRef.current === 0) {
                ewmaBandwidthRef.current = currentSpeed
              } else {
                ewmaBandwidthRef.current = EWMA_ALPHA * currentSpeed + (1 - EWMA_ALPHA) * ewmaBandwidthRef.current
              }
              
              // 格式化显示
              const speedBps = ewmaBandwidthRef.current
              if (speedBps >= 1024 * 1024) {
                setNetworkSpeed(`${(speedBps / (1024 * 1024)).toFixed(1)} MB/s`)
              } else if (speedBps >= 1024) {
                setNetworkSpeed(`${Math.round(speedBps / 1024)} KB/s`)
              } else if (speedBps > 0) {
                setNetworkSpeed(`${Math.round(speedBps)} B/s`)
              }
            } else if (currentBufferedEnd >= video.duration - 0.5) {
              // 缓冲完成
              setNetworkSpeed('')
              ewmaBandwidthRef.current = 0
            } else if (bufferDeltaSec === 0 && !video.paused) {
              // 没有新的缓冲，显示缓冲中
              setNetworkSpeed('缓冲中...')
            }
            
            // 更新记录
            lastBytesRef.current = currentBufferedEnd
            lastTimeRef.current = now
          }
        } else {
          // 初始化
          lastBytesRef.current = currentBufferedEnd
          lastTimeRef.current = now
        }
      }

      // 更新播放器状态
      player.updateTime(video.currentTime)
      onTimeUpdate?.(video.currentTime)
    }, 1000)

    return () => {
      if (playerTimerRef.current) {
        clearInterval(playerTimerRef.current)
      }
    }
  }, [isDragging, player, onTimeUpdate])

  /**
   * 视频事件处理
   */
  const handleLoadedMetadata = useCallback(() => {
    const video = videoRef.current
    if (!video) return

    setDuration(video.duration)
    player.updateDuration(video.duration)
    setIsLoading(false)

    // 应用默认倍速 - 照抄原项目的 defaultPlaySpeed
    if (settingsLoaded && playerSettings.defaultPlaySpeed !== 1.0) {
      video.playbackRate = playerSettings.defaultPlaySpeed
      setPlaybackSpeed(playerSettings.defaultPlaySpeed)
    }

    // 恢复进度 - 照抄原项目的 playResume 设置
    if (!hasLoadedProgress) {
      // 只有在 playResume 开启时才恢复进度
      if (playerSettings.playResume) {
        const savedProgress = player.loadProgress()
        if (savedProgress !== null && savedProgress > 5) {
          video.currentTime = savedProgress
          setCurrentTime(savedProgress)
        }
      }
      setHasLoadedProgress(true)
    }

    onReady?.()
  }, [player, hasLoadedProgress, onReady, settingsLoaded, playerSettings.defaultPlaySpeed, playerSettings.playResume])

  const handlePlay = useCallback(() => {
    setIsPlaying(true)
    player.play()
    startHideTimer()
  }, [player, startHideTimer])

  const handlePause = useCallback(() => {
    setIsPlaying(false)
    player.pause()
    cancelHideTimer()
    setShowControls(true)
  }, [player, cancelHideTimer])

  const handleEnded = useCallback(() => {
    setIsPlaying(false)
    player.pause()
    
    // 只有在非隐身模式下才保存进度
    if (!playerSettings.privateMode) {
      player.saveProgress()
    }
    
    // 自动连播 - 照抄原项目的 autoPlayNext 设置
    if (playerSettings.autoPlayNext && totalEpisodes && episodeNumber < totalEpisodes) {
      // 自动播放下一集
      onPlayNext?.()
    } else if (showNextEpisodeSuggestion && totalEpisodes && episodeNumber < totalEpisodes) {
      // 显示下一集建议
      setShowNextEpisode(true)
    }
    
    onEnded?.()
  }, [player, onEnded, showNextEpisodeSuggestion, totalEpisodes, episodeNumber, playerSettings.autoPlayNext, playerSettings.privateMode, onPlayNext])

  const handleVideoError = useCallback(() => {
    const video = videoRef.current
    if (!video) return

    let errorMessage = '无法加载视频'
    
    if (video.error) {
      switch (video.error.code) {
        case MediaError.MEDIA_ERR_ABORTED:
          errorMessage = '视频加载已中止'
          break
        case MediaError.MEDIA_ERR_NETWORK:
          errorMessage = '网络错误，无法加载视频'
          break
        case MediaError.MEDIA_ERR_DECODE:
          errorMessage = '视频解码失败，请尝试其他视频源'
          break
        case MediaError.MEDIA_ERR_SRC_NOT_SUPPORTED:
          // 照抄原项目: 这个错误通常是因为视频 URL 无效或解析失败
          // 原项目会显示 "解析视频资源超时，请切换到其他播放列表或视频源"
          errorMessage = '视频源无效，请尝试其他播放列表或视频源'
          break
      }
      // 输出详细错误信息到控制台以便调试
      console.error('Video error:', video.error.code, video.error.message, 'src:', video.src)
    }

    setError(errorMessage)
    setIsLoading(false)
    onError?.(errorMessage)
  }, [onError])

  // Update history metadata - 只有在非隐身模式下才更新
  useEffect(() => {
    if (animeTitle && animeCover && !playerSettings.privateMode) {
      historyManager.updateMetadata(animeId, episodeNumber, animeTitle, animeCover)
    }
  }, [animeId, episodeNumber, animeTitle, animeCover, playerSettings.privateMode])

  // 键盘快捷键 - 照抄原项目的方向键快进/快退
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const video = videoRef.current
      if (!video) return

      // 忽略输入框中的按键
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
        return
      }

      switch (e.key) {
        case 'ArrowLeft':
          // 左方向键 - 快退
          e.preventDefault()
          handleSeek(Math.max(0, video.currentTime - playerSettings.arrowKeySkipTime))
          break
        case 'ArrowRight':
          // 右方向键 - 快进
          e.preventDefault()
          handleSeek(Math.min(duration, video.currentTime + playerSettings.arrowKeySkipTime))
          break
        case 'ArrowUp':
          // 上方向键 - 增加音量
          e.preventDefault()
          const newVolumeUp = Math.min(1, video.volume + 0.1)
          video.volume = newVolumeUp
          setVolume(newVolumeUp)
          break
        case 'ArrowDown':
          // 下方向键 - 减少音量
          e.preventDefault()
          const newVolumeDown = Math.max(0, video.volume - 0.1)
          video.volume = newVolumeDown
          setVolume(newVolumeDown)
          break
        case ' ':
          // 空格键 - 播放/暂停
          e.preventDefault()
          handlePlayPause()
          break
        case 'f':
        case 'F':
          // F键 - 全屏
          e.preventDefault()
          if (document.fullscreenElement) {
            document.exitFullscreen()
          } else {
            containerRef.current?.requestFullscreen()
          }
          break
        case 'm':
        case 'M':
          // M键 - 静音
          e.preventDefault()
          if (video.volume > 0) {
            video.volume = 0
            setVolume(0)
          } else {
            video.volume = 1
            setVolume(1)
          }
          break
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [duration, handleSeek, handlePlayPause, playerSettings.arrowKeySkipTime])

  // Track container size
  useEffect(() => {
    const updateSize = () => {
      if (containerRef.current) {
        const { width, height } = containerRef.current.getBoundingClientRect()
        setContainerSize({ width, height })
      }
    }
    updateSize()
    window.addEventListener('resize', updateSize)
    return () => window.removeEventListener('resize', updateSize)
  }, [])

  // Reset state when video URL changes
  useEffect(() => {
    setIsLoading(true)
    setError(null)
    setHasLoadedProgress(false)
    setShowNextEpisode(false)
    setShowSettings(false)
    setCurrentTime(0)
    setDuration(0)
  }, [videoUrl])

  // Initialize HLS.js
  useEffect(() => {
    const video = videoRef.current
    if (!video || !videoUrl) return

    if (hlsRef.current) {
      hlsRef.current.destroy()
      hlsRef.current = null
    }

    const isHls = videoUrl.includes('.m3u8') || videoUrl.includes('/hls/')

    if (isHls) {
      if (Hls.isSupported()) {
        const hls = new Hls({
          enableWorker: true,
          lowLatencyMode: false,
          backBufferLength: 90,
        })
        
        hlsRef.current = hls
        hls.loadSource(videoUrl)
        hls.attachMedia(video)
        
        hls.on(Hls.Events.MANIFEST_PARSED, () => {
          setIsLoading(false)
          if (autoPlay) {
            video.play().catch(console.log)
          }
        })
        
        hls.on(Hls.Events.ERROR, (_event, data) => {
          console.error('HLS error:', data)
          if (data.fatal) {
            switch (data.type) {
              case Hls.ErrorTypes.NETWORK_ERROR:
                // 照抄原项目: 网络错误时自动重试
                console.log('HLS network error, attempting to recover...')
                hls.startLoad()
                // 只有在多次重试失败后才显示错误
                setTimeout(() => {
                  if (hlsRef.current === hls && !video.paused) {
                    setError('网络错误，请检查网络连接或尝试其他视频源')
                  }
                }, 5000)
                break
              case Hls.ErrorTypes.MEDIA_ERROR:
                // 照抄原项目: 媒体错误时尝试恢复
                console.log('HLS media error, attempting to recover...')
                hls.recoverMediaError()
                break
              default:
                // 其他错误，可能是视频源问题
                setError('视频源无效，请尝试其他播放列表或视频源')
                hls.destroy()
            }
          }
        })
      } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = videoUrl
      } else {
        setError('您的浏览器不支持 HLS 视频格式')
      }
    } else {
      video.src = videoUrl
      if (autoPlay) {
        video.play().catch(console.log)
      }
    }

    return () => {
      if (hlsRef.current) {
        hlsRef.current.destroy()
        hlsRef.current = null
      }
    }
  }, [videoUrl, autoPlay])

  // 计算进度百分比
  const displayTime = isDragging && dragTime !== null ? dragTime : currentTime
  const progressPercent = duration > 0 ? (displayTime / duration) * 100 : 0
  const bufferedPercent = duration > 0 ? (buffered / duration) * 100 : 0

  // 计算快进/快退提示
  const seekDelta = isDragging && dragTime !== null ? Math.round(dragTime - currentTime) : 0
  const seekText = seekDelta > 0 ? `快进 ${seekDelta} 秒` : seekDelta < 0 ? `快退 ${Math.abs(seekDelta)} 秒` : ''

  // 计算手势滑动的快进/快退提示
  const gestureSeekDelta = showSeekTime && seekTime !== null ? Math.round(seekTime - currentTime) : 0
  const gestureSeekText = gestureSeekDelta > 0 ? `快进 ${gestureSeekDelta} 秒` : gestureSeekDelta < 0 ? `快退 ${Math.abs(gestureSeekDelta)} 秒` : ''

  return (
    <div 
      ref={containerRef} 
      className={`relative w-full h-full bg-black ${className}`}
      onClick={displayControls}
      onMouseMove={displayControls}
    >
      {/* Video Element - 照抄原项目，不使用原生控件 */}
      <video
        ref={videoRef}
        className="w-full h-full"
        style={{
          // 视频比例设置 - 照抄原项目的 aspectRatioTypeMap
          objectFit: playerSettings.defaultAspectRatioType === 0 ? 'contain' // 自动
            : playerSettings.defaultAspectRatioType === 1 ? 'fill' // 拉伸
            : playerSettings.defaultAspectRatioType === 2 ? 'cover' // 填充
            : 'contain', // 16:9, 4:3 等使用 contain
          aspectRatio: playerSettings.defaultAspectRatioType === 3 ? '16/9'
            : playerSettings.defaultAspectRatioType === 4 ? '4/3'
            : undefined,
        }}
        controls={showNativeControls}
        playsInline
        preload="metadata"
        onLoadedMetadata={handleLoadedMetadata}
        onPlay={handlePlay}
        onPause={handlePause}
        onEnded={handleEnded}
        onError={handleVideoError}
        onWaiting={() => setIsBuffering(true)}
        onPlaying={() => setIsBuffering(false)}
        onCanPlay={() => setIsLoading(false)}
        // iOS Safari specific attributes for inline playback
        {...{ 'webkit-playsinline': 'true', 'x-webkit-airplay': 'allow' }}
      />

      {/* Super Resolution Renderer - 基于 anime4k-webgpu */}
      <SuperResolutionRenderer videoRef={videoRef} enabled={true} />

      {/* 手势控制层 - 照抄原项目的 GestureDetector */}
      {!showNativeControls && (
        <div
          className="absolute inset-0 z-[5]"
          onTouchStart={handleGestureTouchStart}
          onTouchMove={handleGestureTouchMove}
          onTouchEnd={handleGestureTouchEnd}
          onClick={(e) => { 
            e.stopPropagation();
            const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
            const x = e.clientX - rect.left;
            const width = rect.width;
            const now = Date.now();
            
            // 检测双击 - 300ms内的两次点击
            if (lastTapRef.current && now - lastTapRef.current.time < 300) {
              // 双击检测成功
              const isLeftSide = x < width / 3;
              const isRightSide = x > width * 2 / 3;
              
              if (isLeftSide) {
                // 左侧双击 - 快退
                const skipSeconds = playerSettings.arrowKeySkipTime || 10;
                handleSeek(Math.max(0, currentTime - skipSeconds));
                setDoubleTapSkip({ side: 'left', seconds: skipSeconds });
                if (doubleTapTimerRef.current) clearTimeout(doubleTapTimerRef.current);
                doubleTapTimerRef.current = setTimeout(() => setDoubleTapSkip(null), 800);
              } else if (isRightSide) {
                // 右侧双击 - 快进
                const skipSeconds = playerSettings.arrowKeySkipTime || 10;
                handleSeek(Math.min(duration, currentTime + skipSeconds));
                setDoubleTapSkip({ side: 'right', seconds: skipSeconds });
                if (doubleTapTimerRef.current) clearTimeout(doubleTapTimerRef.current);
                doubleTapTimerRef.current = setTimeout(() => setDoubleTapSkip(null), 800);
              } else {
                // 中间双击 - 播放/暂停
                handlePlayPause();
              }
              lastTapRef.current = null;
            } else {
              // 第一次点击，记录时间和位置
              lastTapRef.current = { time: now, x };
              // 延迟执行单击操作
              setTimeout(() => {
                if (lastTapRef.current && Date.now() - lastTapRef.current.time >= 300) {
                  // 单击 - 切换控件显示/隐藏
                  if (showControls) {
                    setShowControls(false);
                    cancelHideTimer();
                  } else {
                    displayControls();
                  }
                  lastTapRef.current = null;
                }
              }, 300);
            }
          }}
        />
      )}

      {/* 长按加速提示 - 照抄原项目的 showPlaySpeed，位置下移避免与顶部控制栏重叠 */}
      {showPlaySpeed && (
        <div className="absolute top-24 left-1/2 -translate-x-1/2 z-30 px-4 py-2 bg-black/70 backdrop-blur-sm rounded-lg flex flex-col items-center gap-1">
          <div className="flex items-center gap-2">
            <span className="material-symbols-rounded text-white text-lg">fast_forward</span>
            <span className="text-white text-sm font-medium">
              {playbackSpeed}x 倍速播放中
            </span>
            {speedLocked && (
              <span className="material-symbols-rounded text-yellow-400 text-sm">lock</span>
            )}
          </div>
          <span className="text-white/60 text-xs">
            {speedLocked ? '↑ 上滑解除锁定 (松手保持2x)' : '↓ 下滑锁定倍速 (松手恢复)'}
          </span>
        </div>
      )}

      {/* 双击快进/快退提示 - 类似YouTube/抖音 */}
      {doubleTapSkip && (
        <div 
          className={`absolute top-1/2 -translate-y-1/2 z-30 pointer-events-none ${
            doubleTapSkip.side === 'left' ? 'left-8' : 'right-8'
          }`}
        >
          <div className="flex flex-col items-center gap-1 animate-pulse">
            <div className="w-12 h-12 rounded-full bg-white/20 backdrop-blur-sm flex items-center justify-center">
              <span className="material-symbols-rounded text-white text-2xl">
                {doubleTapSkip.side === 'left' ? 'fast_rewind' : 'fast_forward'}
              </span>
            </div>
            <span className="text-white text-sm font-medium">
              {doubleTapSkip.side === 'left' ? '-' : '+'}{doubleTapSkip.seconds}s
            </span>
          </div>
        </div>
      )}

      {/* 手势滑动快进/快退提示 - 照抄原项目的 showSeekTime */}
      {showSeekTime && gestureSeekText && (
        <div className="absolute top-1/3 left-1/2 -translate-x-1/2 z-30 px-4 py-2 bg-black/70 backdrop-blur-sm rounded-lg">
          <div className="flex flex-col items-center gap-1">
            <span className="text-white text-lg font-medium">{formatDuration(seekTime ?? 0)}</span>
            <span className="text-white/80 text-sm">{gestureSeekText}</span>
          </div>
        </div>
      )}

      {/* 亮度调节提示 - 照抄原项目的 showBrightness，位置下移 */}
      {showBrightness && (
        <div className="absolute top-24 left-1/2 -translate-x-1/2 z-30 px-4 py-2 bg-black/70 backdrop-blur-sm rounded-lg flex items-center gap-2">
          <span className="material-symbols-rounded text-white text-lg">brightness_7</span>
          <span className="text-white text-sm font-medium">{Math.round(brightness * 100)}%</span>
        </div>
      )}

      {/* 音量调节提示 - 照抄原项目的 showVolume，位置下移 */}
      {showVolume && (
        <div className="absolute top-24 left-1/2 -translate-x-1/2 z-30 px-4 py-2 bg-black/70 backdrop-blur-sm rounded-lg flex items-center gap-2">
          <span className="material-symbols-rounded text-white text-lg">
            {volume === 0 ? 'volume_off' : volume < 0.5 ? 'volume_down' : 'volume_up'}
          </span>
          <span className="text-white text-sm font-medium">{Math.round(volume * 100)}%</span>
        </div>
      )}

      {/* Danmaku Canvas */}
      {enableDanmaku && containerSize.width > 0 && containerSize.height > 0 && (
        <DanmakuCanvas
          danmakuList={danmaku.list}
          currentTime={currentTime}
          enabled={danmaku.enabled}
          opacity={danmaku.opacity}
          speed={danmaku.speed}
          fontSize={danmaku.fontSize}
          containerWidth={containerSize.width}
          containerHeight={containerSize.height}
          area={danmaku.area}
          hideTop={danmaku.hideTop}
          hideBottom={danmaku.hideBottom}
          hideScroll={danmaku.hideScroll}
          duration={danmaku.duration}
          lineHeight={danmaku.lineHeight}
          border={danmaku.border}
          showColor={danmaku.showColor}
          fontWeight={danmaku.fontWeight}
          playbackSpeed={playbackSpeed}
          followSpeed={danmaku.followSpeed}
          massive={danmaku.massive}
        />
      )}

      {/* 拖动时显示快进/快退提示 - 照抄原项目的 showSeekTime */}
      {isDragging && seekText && (
        <div className="absolute top-1/3 left-1/2 -translate-x-1/2 z-30 px-4 py-2 bg-black/70 backdrop-blur-sm rounded-lg">
          <span className="text-white text-sm font-medium">{seekText}</span>
        </div>
      )}

      {/* 始终可见的迷你进度条 - 底部细进度条，始终显示，不受showControls影响 */}
      {!showNativeControls && !showControls && (
        <div 
          className="absolute left-0 right-0 z-[100] h-[3px] cursor-pointer"
          style={{ bottom: 0 }}
          onClick={(e) => { e.stopPropagation(); displayControls(); }}
          onTouchStart={(e) => { e.stopPropagation(); displayControls(); }}
        >
          {/* 背景 */}
          <div className="absolute inset-0 bg-black/60" />
          {/* 缓冲进度 */}
          <div 
            className="absolute top-0 bottom-0 left-0 bg-white/40"
            style={{ width: `${bufferedPercent}%` }}
          />
          {/* 播放进度 - 红色主题 */}
          <div 
            className="absolute top-0 bottom-0 left-0 bg-red-500"
            style={{ width: `${progressPercent}%` }}
          />
        </div>
      )}

      {/* Top Controls - 只在没有外部控制栏时显示（由 showNativeControls 控制） */}
      {/* 注意：播放页面 (watch/[episode]/page.tsx) 已经有顶部控制栏，这里不再重复显示标题 */}

      {/* Bottom Controls - 照抄原项目的 playerPanel */}
      {!showNativeControls && (
        <div 
          className={`absolute bottom-0 left-0 right-0 z-[50] ${
            playerSettings.playerDisableAnimations ? '' : 'transition-opacity duration-300'
          } ${
            showControls ? 'opacity-100' : 'opacity-0 pointer-events-none'
          }`}
          onClick={(e) => e.stopPropagation()}
        >
          {/* 渐变背景 */}
          <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/40 to-transparent pointer-events-none" />
          
          <div className="relative px-4 pb-4 pt-12 safe-area-bottom">
            {/* 进度条 - 照抄原项目的 ProgressBar */}
            <div 
              ref={progressBarRef}
              className="relative h-12 flex items-center cursor-pointer group touch-none select-none"
              onClick={handleProgressClick}
              onMouseDown={handleMouseDown}
              onTouchStart={handleTouchStart}
            >
              {/* 进度条背景 - 增大触摸区域 */}
              <div className="absolute inset-x-0 h-[4px] bg-white/30 rounded-full group-hover:h-[6px] transition-all" style={{ top: '50%', transform: 'translateY(-50%)' }}>
                {/* 缓冲进度 */}
                <div 
                  className="absolute h-full bg-white/40 rounded-full"
                  style={{ width: `${bufferedPercent}%` }}
                />
                {/* 播放进度 - 使用红色主题色 */}
                <div 
                  className="absolute h-full bg-red-500 rounded-full"
                  style={{ width: `${progressPercent}%` }}
                />
              </div>
              
              {/* 进度条滑块 - 始终可见 */}
              <div 
                className={`absolute w-4 h-4 bg-white rounded-full shadow-lg transition-transform ${
                  isDragging ? 'scale-150' : 'group-hover:scale-125'
                }`}
                style={{ 
                  left: `calc(${progressPercent}% - 8px)`,
                  top: '50%',
                  transform: `translateY(-50%) ${isDragging ? 'scale(1.5)' : ''}`
                }}
              />
            </div>

            {/* 控制按钮行 - 使用 flex-nowrap 防止换行 */}
            <div className="flex items-center justify-between flex-nowrap overflow-hidden">
              {/* 左侧: 播放/暂停 + 时间 + 倍速 */}
              <div className="flex items-center gap-1 sm:gap-2 flex-shrink-0">
                <button
                  onClick={handlePlayPause}
                  className="w-9 h-9 sm:w-10 sm:h-10 flex items-center justify-center bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full transition-all active:scale-95 flex-shrink-0"
                  aria-label={isPlaying ? '暂停' : '播放'}
                >
                  <span className="material-symbols-rounded text-white text-lg sm:text-xl">
                    {isPlaying ? 'pause' : 'play_arrow'}
                  </span>
                </button>
                
                {/* 时间显示 - 移动端也显示 */}
                <span className="text-white text-xs sm:text-sm font-medium tabular-nums whitespace-nowrap">
                  {formatDuration(displayTime)}/{formatDuration(duration)}
                </span>

                {/* 倍速按钮 - 照抄原项目的 showSetSpeedSheet */}
                <div className="relative flex-shrink-0">
                  <button
                    onClick={() => {
                      setShowSpeedMenu(!showSpeedMenu)
                      cancelHideTimer()
                    }}
                    className="h-7 sm:h-8 px-2 sm:px-3 flex items-center justify-center bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full transition-all active:scale-95"
                    aria-label="播放速度"
                  >
                    <span className="text-white text-xs sm:text-sm font-medium whitespace-nowrap">
                      {playbackSpeed === 1.0 ? '倍速' : `${playbackSpeed}x`}
                    </span>
                  </button>

                  {/* 倍速选择菜单 - 照抄原项目的 AlertDialog */}
                  {showSpeedMenu && (
                    <>
                      <div 
                        className="fixed inset-0 z-40"
                        onClick={() => {
                          setShowSpeedMenu(false)
                          startHideTimer()
                        }}
                      />
                      <div className="absolute bottom-full left-0 mb-2 z-50 py-2 bg-black/80 backdrop-blur-md rounded-xl border border-white/20 max-h-60 overflow-y-auto">
                        <div className="px-3 py-1 text-white/60 text-xs border-b border-white/10 mb-1">
                          播放速度
                        </div>
                        <div className="flex flex-wrap gap-1 p-2 w-48">
                          {DEFAULT_PLAY_SPEED_LIST.map((speed) => (
                            <button
                              key={speed}
                              onClick={() => handleSetPlaybackSpeed(speed)}
                              className={`
                                px-3 py-1.5 rounded-lg text-sm font-medium transition-all active:scale-95
                                ${playbackSpeed === speed 
                                  ? 'bg-red-500 text-white' 
                                  : 'bg-white/10 text-white hover:bg-white/20'
                                }
                              `}
                            >
                              {speed}x
                            </button>
                          ))}
                        </div>
                        <div className="px-2 pt-1 border-t border-white/10 mt-1">
                          <button
                            onClick={() => handleSetPlaybackSpeed(1.0)}
                            className="w-full px-3 py-1.5 text-sm text-white/80 hover:text-white hover:bg-white/10 rounded-lg transition-all"
                          >
                            默认速度
                          </button>
                        </div>
                      </div>
                    </>
                  )}
                </div>
              </div>

              {/* 右侧: 音量 + 下一集 + 弹幕设置 */}
              <div className="flex items-center gap-1 sm:gap-2 flex-shrink-0">
                {/* 音量控制按钮 - 移动端隐藏 */}
                <div className="relative hidden sm:block">
                  <button
                    onClick={() => {
                      const video = videoRef.current
                      if (video) {
                        // 点击切换静音
                        if (video.volume > 0) {
                          setVolume(0)
                          video.volume = 0
                        } else {
                          setVolume(1)
                          video.volume = 1
                        }
                      }
                    }}
                    className="w-10 h-10 flex items-center justify-center bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full transition-all active:scale-95"
                    aria-label="音量"
                  >
                    <span className="material-symbols-rounded text-white text-xl">
                      {volume === 0 ? 'volume_off' : volume < 0.5 ? 'volume_down' : 'volume_up'}
                    </span>
                  </button>
                </div>

                {/* 下一集按钮 - 始终显示，如果没有下一集则禁用 */}
                {onPlayNext && (
                  <button
                    onClick={onPlayNext}
                    disabled={!totalEpisodes || episodeNumber >= totalEpisodes}
                    className={`w-9 h-9 sm:w-10 sm:h-10 flex items-center justify-center bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full transition-all active:scale-95 flex-shrink-0 ${
                      !totalEpisodes || episodeNumber >= totalEpisodes ? 'opacity-40 cursor-not-allowed' : ''
                    }`}
                    aria-label="下一集"
                  >
                    <span className="material-symbols-rounded text-white text-lg sm:text-xl">
                      skip_next
                    </span>
                  </button>
                )}

                {/* 弹幕设置按钮 */}
                {enableDanmaku && showDanmakuSettings && (
                  <button
                    onClick={() => setShowSettings(!showSettings)}
                    className="w-9 h-9 sm:w-10 sm:h-10 flex items-center justify-center bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full transition-all active:scale-95 flex-shrink-0"
                    aria-label="弹幕设置"
                  >
                    <span className="material-symbols-rounded text-white text-base sm:text-lg">
                      {danmaku.enabled ? 'chat_bubble' : 'speaker_notes_off'}
                    </span>
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Danmaku Settings Panel */}
      {enableDanmaku && showSettings && (
        <DanmakuSettings
          visible={showSettings}
          onClose={() => setShowSettings(false)}
          className="z-[70]"
        />
      )}

      {/* Danmaku Status Indicator - 位置下移避免与顶部控制栏重叠 */}
      {enableDanmaku && !showNativeControls && showControls && (
        <div className="absolute top-24 left-4 z-[60]">
          {danmaku.loading ? (
            <div className="px-3 py-2 bg-black/50 backdrop-blur-sm rounded-full">
              <div className="flex items-center gap-2">
                <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                <span className="text-white text-xs">加载弹幕...</span>
              </div>
            </div>
          ) : danmaku.error ? (
            <div className="px-3 py-2 bg-black/50 backdrop-blur-sm rounded-full">
              <div className="flex items-center gap-2">
                <span className="material-symbols-rounded text-yellow-400 text-sm">warning</span>
                <span className="text-white/80 text-xs">弹幕加载失败</span>
              </div>
            </div>
          ) : danmaku.list.length > 0 ? (
            <div className="px-3 py-2 bg-black/50 backdrop-blur-sm rounded-full">
              <span className="text-white/80 text-xs">{danmaku.list.length} 条弹幕</span>
            </div>
          ) : null}
        </div>
      )}

      {/* Network Speed Indicator - iOS Safari 兼容，位置下移 */}
      {!showNativeControls && showControls && networkSpeed && (
        <div className="absolute top-24 right-4 z-[60]">
          <div className="px-3 py-2 bg-black/50 backdrop-blur-sm rounded-full">
            <div className="flex items-center gap-1.5">
              <span className="material-symbols-rounded text-blue-400 text-sm">download</span>
              <span className="text-white/80 text-xs tabular-nums">{networkSpeed}</span>
            </div>
          </div>
        </div>
      )}

      {/* Loading Indicator */}
      {(isLoading || isBuffering) && !error && (
        <div className="absolute inset-0 flex items-center justify-center bg-black/30 z-10 pointer-events-none">
          <div className="flex flex-col items-center gap-3">
            <div className="w-12 h-12 border-4 border-white/20 border-t-white rounded-full animate-spin" />
            <p className="text-white text-sm">{isLoading ? '加载中...' : '缓冲中...'}</p>
          </div>
        </div>
      )}

      {/* Error Display - 使用 showPlayerError 设置控制是否显示 */}
      {error && playerSettings.showPlayerError && (
        <div className="absolute inset-0 flex items-center justify-center bg-black/80 z-10">
          <div className="flex flex-col items-center gap-4 px-6 py-8 bg-white/10 backdrop-blur-md rounded-2xl border border-white/20">
            <span className="material-symbols-rounded text-red-400 text-5xl">error</span>
            <p className="text-white text-base text-center max-w-xs">{error}</p>
            <button
              onClick={() => {
                setError(null)
                setIsLoading(true)
                videoRef.current?.load()
              }}
              className="px-6 py-2 bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full text-white text-sm transition-all active:scale-95"
            >
              重试
            </button>
          </div>
        </div>
      )}

      {/* Next Episode Suggestion */}
      {showNextEpisodeSuggestion && totalEpisodes && (
        <NextEpisodeSuggestion
          animeId={animeId}
          currentEpisode={episodeNumber}
          totalEpisodes={totalEpisodes}
          animeTitle={animeTitle}
          nextEpisodeTitle={nextEpisodeTitle}
          show={showNextEpisode}
          onCancel={() => setShowNextEpisode(false)}
          onPlayNext={onPlayNext}
        />
      )}
    </div>
  )
}
