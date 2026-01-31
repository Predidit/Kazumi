/**
 * PlayerControls Component
 * iOS-styled video player controls with Material Symbols icons
 * 
 * Features:
 * - Play/pause button with smooth transitions
 * - Seek bar with touch-friendly interactions
 * - Volume control with visual feedback
 * - Fullscreen and Picture-in-Picture buttons
 * - GPU-accelerated animations (transform, opacity)
 * - Minimum 44px touch targets for accessibility
 * - Auto-hide controls after inactivity
 * 
 * Requirements: 5.2, 5.3, 5.4, 5.5, 5.7, 12.5
 */

'use client'

import { useCallback, useEffect, useRef, useState } from 'react'
import { cn } from '@/lib/utils/cn'

export interface PlayerControlsProps {
  /** Whether video is currently playing */
  isPlaying: boolean
  /** Current playback time in seconds */
  currentTime: number
  /** Total video duration in seconds */
  duration: number
  /** Volume level (0-1) */
  volume: number
  /** Whether player is in fullscreen mode */
  isFullscreen: boolean
  /** Whether player is in Picture-in-Picture mode */
  isPiP: boolean
  /** Callback to toggle play/pause */
  onPlayPause: () => void
  /** Callback to seek to specific time */
  onSeek: (time: number) => void
  /** Callback to change volume */
  onVolumeChange: (volume: number) => void
  /** Callback to toggle fullscreen */
  onFullscreenToggle: () => void
  /** Callback to toggle Picture-in-Picture */
  onPiPToggle: () => void
  /** Whether to show controls (for external control) */
  visible?: boolean
  /** Callback when controls visibility changes */
  onVisibilityChange?: (visible: boolean) => void
  /** Class name for styling */
  className?: string
}

/**
 * Format seconds to MM:SS or HH:MM:SS
 */
function formatTime(seconds: number): string {
  if (!isFinite(seconds) || seconds < 0) return '0:00'
  
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const secs = Math.floor(seconds % 60)
  
  if (hours > 0) {
    return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }
  
  return `${minutes}:${secs.toString().padStart(2, '0')}`
}

/**
 * PlayerControls component with iOS-styled controls
 * Uses Material Symbols icons and liquid glass aesthetic
 */
export function PlayerControls({
  isPlaying,
  currentTime,
  duration,
  volume,
  isFullscreen,
  isPiP,
  onPlayPause,
  onSeek,
  onVolumeChange,
  onFullscreenToggle,
  onPiPToggle,
  visible: externalVisible,
  onVisibilityChange,
  className = '',
}: PlayerControlsProps) {
  const [internalVisible, setInternalVisible] = useState(true)
  const [isSeeking, setIsSeeking] = useState(false)
  const [seekPreview, setSeekPreview] = useState<number | null>(null)
  const [showVolumeSlider, setShowVolumeSlider] = useState(false)
  const hideTimerRef = useRef<NodeJS.Timeout | null>(null)
  const seekBarRef = useRef<HTMLDivElement>(null)
  const volumeSliderRef = useRef<HTMLDivElement>(null)

  // Use external visibility if provided, otherwise use internal state
  const visible = externalVisible !== undefined ? externalVisible : internalVisible

  /**
   * Reset hide timer
   */
  const resetHideTimer = useCallback(() => {
    if (hideTimerRef.current) {
      clearTimeout(hideTimerRef.current)
    }

    // Show controls
    if (externalVisible === undefined) {
      setInternalVisible(true)
      onVisibilityChange?.(true)
    }

    // Hide after 3 seconds of inactivity (only when playing)
    if (isPlaying) {
      hideTimerRef.current = setTimeout(() => {
        if (externalVisible === undefined) {
          setInternalVisible(false)
          onVisibilityChange?.(false)
        }
        setShowVolumeSlider(false)
      }, 3000)
    }
  }, [isPlaying, externalVisible, onVisibilityChange])

  /**
   * Handle mouse move to show controls
   */
  const handleMouseMove = useCallback(() => {
    resetHideTimer()
  }, [resetHideTimer])

  /**
   * Handle touch to show controls
   */
  const handleTouch = useCallback(() => {
    resetHideTimer()
  }, [resetHideTimer])

  /**
   * Set up auto-hide behavior
   */
  useEffect(() => {
    resetHideTimer()

    return () => {
      if (hideTimerRef.current) {
        clearTimeout(hideTimerRef.current)
      }
    }
  }, [resetHideTimer])

  /**
   * Handle seek bar click/touch
   */
  const handleSeekBarInteraction = useCallback(
    (clientX: number) => {
      if (!seekBarRef.current || !duration) return

      const rect = seekBarRef.current.getBoundingClientRect()
      const percent = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width))
      const time = percent * duration

      if (isSeeking) {
        setSeekPreview(time)
      } else {
        onSeek(time)
      }
    },
    [duration, isSeeking, onSeek]
  )

  /**
   * Handle seek bar mouse down
   */
  const handleSeekMouseDown = useCallback(
    (e: React.MouseEvent) => {
      setIsSeeking(true)
      handleSeekBarInteraction(e.clientX)
    },
    [handleSeekBarInteraction]
  )

  /**
   * Handle seek bar touch start
   */
  const handleSeekTouchStart = useCallback(
    (e: React.TouchEvent) => {
      setIsSeeking(true)
      handleSeekBarInteraction(e.touches[0].clientX)
    },
    [handleSeekBarInteraction]
  )

  /**
   * Handle seek bar mouse move
   */
  const handleSeekMouseMove = useCallback(
    (e: MouseEvent) => {
      if (isSeeking) {
        handleSeekBarInteraction(e.clientX)
      }
    },
    [isSeeking, handleSeekBarInteraction]
  )

  /**
   * Handle seek bar touch move
   */
  const handleSeekTouchMove = useCallback(
    (e: TouchEvent) => {
      if (isSeeking) {
        e.preventDefault()
        handleSeekBarInteraction(e.touches[0].clientX)
      }
    },
    [isSeeking, handleSeekBarInteraction]
  )

  /**
   * Handle seek bar mouse up
   */
  const handleSeekMouseUp = useCallback(() => {
    if (isSeeking && seekPreview !== null) {
      onSeek(seekPreview)
      setSeekPreview(null)
    }
    setIsSeeking(false)
  }, [isSeeking, seekPreview, onSeek])

  /**
   * Handle seek bar touch end
   */
  const handleSeekTouchEnd = useCallback(() => {
    if (isSeeking && seekPreview !== null) {
      onSeek(seekPreview)
      setSeekPreview(null)
    }
    setIsSeeking(false)
  }, [isSeeking, seekPreview, onSeek])

  /**
   * Set up global mouse/touch event listeners for seeking
   */
  useEffect(() => {
    if (isSeeking) {
      window.addEventListener('mousemove', handleSeekMouseMove)
      window.addEventListener('mouseup', handleSeekMouseUp)
      window.addEventListener('touchmove', handleSeekTouchMove, { passive: false })
      window.addEventListener('touchend', handleSeekTouchEnd)

      return () => {
        window.removeEventListener('mousemove', handleSeekMouseMove)
        window.removeEventListener('mouseup', handleSeekMouseUp)
        window.removeEventListener('touchmove', handleSeekTouchMove)
        window.removeEventListener('touchend', handleSeekTouchEnd)
      }
    }
  }, [isSeeking, handleSeekMouseMove, handleSeekMouseUp, handleSeekTouchMove, handleSeekTouchEnd])

  /**
   * Handle volume slider interaction
   */
  const handleVolumeSliderInteraction = useCallback(
    (clientY: number) => {
      if (!volumeSliderRef.current) return

      const rect = volumeSliderRef.current.getBoundingClientRect()
      // Invert Y axis (top = 1, bottom = 0)
      const percent = Math.max(0, Math.min(1, 1 - (clientY - rect.top) / rect.height))
      onVolumeChange(percent)
    },
    [onVolumeChange]
  )

  /**
   * Handle volume slider mouse down
   */
  const handleVolumeMouseDown = useCallback(
    (e: React.MouseEvent) => {
      e.stopPropagation()
      handleVolumeSliderInteraction(e.clientY)
    },
    [handleVolumeSliderInteraction]
  )

  /**
   * Handle volume slider touch start
   */
  const handleVolumeTouchStart = useCallback(
    (e: React.TouchEvent) => {
      e.stopPropagation()
      handleVolumeSliderInteraction(e.touches[0].clientY)
    },
    [handleVolumeSliderInteraction]
  )

  /**
   * Toggle volume slider visibility
   */
  const toggleVolumeSlider = useCallback(() => {
    setShowVolumeSlider((prev) => !prev)
    resetHideTimer()
  }, [resetHideTimer])

  /**
   * Calculate progress percentage
   */
  const progress = duration > 0 ? (currentTime / duration) * 100 : 0
  const displayTime = seekPreview !== null ? seekPreview : currentTime

  return (
    <div
      className={cn(
        'absolute inset-0 flex flex-col justify-end',
        'transition-opacity duration-300 gpu-accelerated',
        visible ? 'opacity-100' : 'opacity-0 pointer-events-none',
        className
      )}
      onMouseMove={handleMouseMove}
      onTouchStart={handleTouch}
    >
      {/* Gradient overlay for better contrast */}
      <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent pointer-events-none" />

      {/* Controls container */}
      <div className="relative z-10 px-4 pb-4 safe-area-bottom">
        {/* Seek bar */}
        <div className="mb-4">
          <div
            ref={seekBarRef}
            className="relative h-[44px] flex items-center cursor-pointer group"
            onMouseDown={handleSeekMouseDown}
            onTouchStart={handleSeekTouchStart}
            role="slider"
            aria-label="进度条"
            aria-valuemin={0}
            aria-valuemax={duration}
            aria-valuenow={currentTime}
            tabIndex={0}
          >
            {/* Track background */}
            <div className="absolute inset-x-0 h-1 bg-white/30 rounded-full overflow-hidden">
              {/* Progress fill */}
              <div
                className="h-full bg-white transition-all duration-100 gpu-accelerated"
                style={{ width: `${progress}%` }}
              />
            </div>

            {/* Seek thumb */}
            <div
              className="absolute h-4 w-4 bg-white rounded-full shadow-lg transition-transform duration-100 gpu-accelerated group-hover:scale-125"
              style={{ left: `calc(${progress}% - 8px)` }}
            />
          </div>

          {/* Time display */}
          <div className="flex justify-between items-center mt-2 px-1">
            <span className="text-white text-sm font-medium">
              {formatTime(displayTime)}
            </span>
            <span className="text-white/70 text-sm font-medium">
              {formatTime(duration)}
            </span>
          </div>
        </div>

        {/* Control buttons */}
        <div className="flex items-center justify-between gap-2">
          {/* Left controls */}
          <div className="flex items-center gap-2">
            {/* Play/Pause button */}
            <button
              onClick={onPlayPause}
              className={cn(
                'flex items-center justify-center',
                'min-h-[44px] min-w-[44px] h-[44px] w-[44px]',
                'bg-white/20 hover:bg-white/30 active:bg-white/10',
                'backdrop-blur-glass rounded-full',
                'transition-all duration-200 gpu-accelerated',
                'active:scale-95 spring-animation',
                'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2',
                'focus-visible:outline-white/80'
              )}
              aria-label={isPlaying ? '暂停' : '播放'}
            >
              <span className="material-symbols-rounded text-white text-[28px]">
                {isPlaying ? 'pause' : 'play_arrow'}
              </span>
            </button>

            {/* Volume button with slider */}
            <div className="relative">
              <button
                onClick={toggleVolumeSlider}
                className={cn(
                  'flex items-center justify-center',
                  'min-h-[44px] min-w-[44px] h-[44px] w-[44px]',
                  'bg-white/20 hover:bg-white/30 active:bg-white/10',
                  'backdrop-blur-glass rounded-full',
                  'transition-all duration-200 gpu-accelerated',
                  'active:scale-95 spring-animation',
                  'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2',
                  'focus-visible:outline-white/80'
                )}
                aria-label="音量"
              >
                <span className="material-symbols-rounded text-white text-[24px]">
                  {volume === 0 ? 'volume_off' : volume < 0.5 ? 'volume_down' : 'volume_up'}
                </span>
              </button>

              {/* Volume slider */}
              {showVolumeSlider && (
                <div
                  className={cn(
                    'absolute bottom-full left-1/2 -translate-x-1/2 mb-2',
                    'w-[44px] h-[120px] p-2',
                    'bg-white/20 backdrop-blur-glass rounded-full',
                    'transition-all duration-200 gpu-accelerated',
                    'animate-slide-up'
                  )}
                >
                  <div
                    ref={volumeSliderRef}
                    className="relative h-full cursor-pointer"
                    onMouseDown={handleVolumeMouseDown}
                    onTouchStart={handleVolumeTouchStart}
                    role="slider"
                    aria-label="音量滑块"
                    aria-valuemin={0}
                    aria-valuemax={100}
                    aria-valuenow={Math.round(volume * 100)}
                    tabIndex={0}
                  >
                    {/* Track background */}
                    <div className="absolute inset-x-0 top-0 bottom-0 w-1 mx-auto bg-white/30 rounded-full overflow-hidden">
                      {/* Volume fill (from bottom) */}
                      <div
                        className="absolute bottom-0 inset-x-0 bg-white transition-all duration-100 gpu-accelerated"
                        style={{ height: `${volume * 100}%` }}
                      />
                    </div>

                    {/* Volume thumb */}
                    <div
                      className="absolute left-1/2 -translate-x-1/2 h-3 w-3 bg-white rounded-full shadow-lg transition-all duration-100 gpu-accelerated"
                      style={{ bottom: `calc(${volume * 100}% - 6px)` }}
                    />
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Right controls */}
          <div className="flex items-center gap-2">
            {/* Picture-in-Picture button */}
            {document.pictureInPictureEnabled && (
              <button
                onClick={onPiPToggle}
                className={cn(
                  'flex items-center justify-center',
                  'min-h-[44px] min-w-[44px] h-[44px] w-[44px]',
                  'bg-white/20 hover:bg-white/30 active:bg-white/10',
                  'backdrop-blur-glass rounded-full',
                  'transition-all duration-200 gpu-accelerated',
                  'active:scale-95 spring-animation',
                  'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2',
                  'focus-visible:outline-white/80',
                  isPiP && 'bg-white/30'
                )}
                aria-label="画中画"
                aria-pressed={isPiP}
              >
                <span className="material-symbols-rounded text-white text-[24px]">
                  picture_in_picture_alt
                </span>
              </button>
            )}

            {/* Fullscreen button */}
            <button
              onClick={onFullscreenToggle}
              className={cn(
                'flex items-center justify-center',
                'min-h-[44px] min-w-[44px] h-[44px] w-[44px]',
                'bg-white/20 hover:bg-white/30 active:bg-white/10',
                'backdrop-blur-glass rounded-full',
                'transition-all duration-200 gpu-accelerated',
                'active:scale-95 spring-animation',
                'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2',
                'focus-visible:outline-white/80'
              )}
              aria-label={isFullscreen ? '退出全屏' : '全屏'}
              aria-pressed={isFullscreen}
            >
              <span className="material-symbols-rounded text-white text-[24px]">
                {isFullscreen ? 'fullscreen_exit' : 'fullscreen'}
              </span>
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
