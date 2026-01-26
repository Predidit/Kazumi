/**
 * NextEpisodeSuggestion Component
 * Displays next episode suggestion when video ends
 * Only shows if next episode exists
 * 
 * Requirements: 5.8
 * Validates: Property 10 - Next Episode Suggestion Conditional Display
 */

'use client'

import { useEffect, useState, useCallback } from 'react'
import { useRouter } from 'next/navigation'

export interface NextEpisodeSuggestionProps {
  /** Current anime ID */
  animeId: number
  /** Current episode number */
  currentEpisode: number
  /** Total number of episodes */
  totalEpisodes: number
  /** Anime title for display */
  animeTitle?: string
  /** Next episode title (optional) */
  nextEpisodeTitle?: string
  /** Whether to show the suggestion */
  show: boolean
  /** Callback when user cancels */
  onCancel?: () => void
  /** Callback when user skips to next episode */
  onPlayNext?: () => void
  /** Auto-play countdown duration in seconds (default: 5) */
  countdownDuration?: number
  /** Class name for styling */
  className?: string
}

/**
 * NextEpisodeSuggestion component
 * Shows overlay when video ends with countdown timer
 * Allows user to skip or cancel auto-play
 */
export function NextEpisodeSuggestion({
  animeId,
  currentEpisode,
  totalEpisodes,
  animeTitle = '',
  nextEpisodeTitle,
  show,
  onCancel,
  onPlayNext,
  countdownDuration = 5,
  className = '',
}: NextEpisodeSuggestionProps) {
  const router = useRouter()
  const [countdown, setCountdown] = useState(countdownDuration)
  const [isVisible, setIsVisible] = useState(false)

  // Check if next episode exists
  const hasNextEpisode = currentEpisode < totalEpisodes
  const nextEpisode = currentEpisode + 1

  /**
   * Reset countdown when show prop changes
   */
  useEffect(() => {
    if (show && hasNextEpisode) {
      setCountdown(countdownDuration)
      setIsVisible(true)
    } else {
      setIsVisible(false)
    }
  }, [show, hasNextEpisode, countdownDuration])

  /**
   * Countdown timer
   */
  useEffect(() => {
    if (!isVisible || !hasNextEpisode) return

    if (countdown <= 0) {
      handlePlayNext()
      return
    }

    const timer = setTimeout(() => {
      setCountdown((prev) => prev - 1)
    }, 1000)

    return () => clearTimeout(timer)
  }, [countdown, isVisible, hasNextEpisode])

  /**
   * Handle play next episode
   */
  const handlePlayNext = useCallback(() => {
    if (!hasNextEpisode) return

    if (onPlayNext) {
      onPlayNext()
    } else {
      // Default behavior: navigate to next episode
      router.push(`/anime/${animeId}/watch/${nextEpisode}`)
    }
  }, [animeId, nextEpisode, hasNextEpisode, onPlayNext, router])

  /**
   * Handle cancel
   */
  const handleCancel = useCallback(() => {
    setIsVisible(false)
    onCancel?.()
  }, [onCancel])

  /**
   * Handle keyboard events
   */
  useEffect(() => {
    if (!isVisible) return

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault()
        handlePlayNext()
      } else if (e.key === 'Escape') {
        e.preventDefault()
        handleCancel()
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [isVisible, handlePlayNext, handleCancel])

  // Don't render if no next episode exists or not visible
  if (!hasNextEpisode || !isVisible) {
    return null
  }

  return (
    <div
      className={`absolute inset-0 flex items-center justify-center bg-black/80 backdrop-blur-md z-50 animate-fade-in ${className}`}
      role="dialog"
      aria-modal="true"
      aria-labelledby="next-episode-title"
    >
      <div className="flex flex-col items-center gap-6 px-8 py-10 max-w-md mx-4 bg-gradient-to-br from-white/10 to-white/5 backdrop-blur-xl rounded-3xl border border-white/20 shadow-2xl animate-scale-in">
        {/* Icon */}
        <div className="relative">
          <div className="absolute inset-0 bg-gradient-to-br from-rose-400/20 to-orange-400/20 rounded-full blur-xl animate-pulse" />
          <div className="relative w-20 h-20 flex items-center justify-center bg-gradient-to-br from-rose-400/30 to-orange-400/30 backdrop-blur-sm rounded-full border border-white/30">
            <span className="material-symbols-outlined text-white text-5xl">
              skip_next
            </span>
          </div>
        </div>

        {/* Title */}
        <div className="flex flex-col items-center gap-2 text-center">
          <h3
            id="next-episode-title"
            className="text-white text-xl font-semibold"
          >
            下一集
          </h3>
          {animeTitle && (
            <p className="text-white/70 text-sm font-medium">
              {animeTitle}
            </p>
          )}
        </div>

        {/* Episode Info */}
        <div className="flex flex-col items-center gap-2 text-center">
          <p className="text-white text-lg font-medium">
            第 {nextEpisode} 集
          </p>
          {nextEpisodeTitle && (
            <p className="text-white/80 text-sm line-clamp-2 max-w-xs">
              {nextEpisodeTitle}
            </p>
          )}
        </div>

        {/* Countdown */}
        <div className="flex flex-col items-center gap-2">
          <div className="relative w-16 h-16">
            {/* Countdown circle */}
            <svg
              className="absolute inset-0 -rotate-90"
              viewBox="0 0 64 64"
              xmlns="http://www.w3.org/2000/svg"
            >
              <circle
                cx="32"
                cy="32"
                r="28"
                fill="none"
                stroke="rgba(255, 255, 255, 0.1)"
                strokeWidth="4"
              />
              <circle
                cx="32"
                cy="32"
                r="28"
                fill="none"
                stroke="rgba(251, 113, 133, 0.8)"
                strokeWidth="4"
                strokeDasharray={`${2 * Math.PI * 28}`}
                strokeDashoffset={`${2 * Math.PI * 28 * (1 - countdown / countdownDuration)}`}
                strokeLinecap="round"
                className="transition-all duration-1000 ease-linear"
              />
            </svg>
            {/* Countdown number */}
            <div className="absolute inset-0 flex items-center justify-center">
              <span className="text-white text-2xl font-bold">
                {countdown}
              </span>
            </div>
          </div>
          <p className="text-white/60 text-sm">
            下一集将在 {countdown} 秒后播放
          </p>
        </div>

        {/* Action Buttons */}
        <div className="flex items-center gap-3 w-full">
          {/* Cancel Button */}
          <button
            onClick={handleCancel}
            className="flex-1 px-6 py-3 bg-white/10 hover:bg-white/20 backdrop-blur-sm rounded-full text-white text-sm font-medium transition-all duration-200 active:scale-95 min-h-[44px] min-w-[44px]"
            aria-label="取消自动播放"
          >
            取消
          </button>

          {/* Play Now Button */}
          <button
            onClick={handlePlayNext}
            className="flex-1 px-6 py-3 bg-gradient-to-r from-rose-400 to-orange-400 hover:from-rose-500 hover:to-orange-500 rounded-full text-white text-sm font-semibold transition-all duration-200 active:scale-95 shadow-lg shadow-rose-500/30 min-h-[44px] min-w-[44px]"
            aria-label="立即播放下一集"
          >
            立即播放
          </button>
        </div>
      </div>
    </div>
  )
}

// Add animations to global CSS if not already present
// @keyframes fade-in {
//   from { opacity: 0; }
//   to { opacity: 1; }
// }
// @keyframes scale-in {
//   from { opacity: 0; transform: scale(0.9); }
//   to { opacity: 1; transform: scale(1); }
// }
// .animate-fade-in { animation: fade-in 0.3s ease-out; }
// .animate-scale-in { animation: scale-in 0.3s ease-out; }
