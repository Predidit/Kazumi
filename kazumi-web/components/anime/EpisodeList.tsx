'use client'

import React from 'react'
import { Episode, VideoSource } from '@/types'
import { GlassCard } from '@/components/ui/GlassCard'
import { GlassPill } from '@/components/ui/GlassPill'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils/cn'

export interface EpisodeListProps {
  /**
   * Array of episodes to display
   */
  episodes: Episode[]
  /**
   * Current anime ID for progress tracking
   */
  animeId: number
  /**
   * Episode click handler
   */
  onEpisodeClick?: (episode: Episode) => void
  /**
   * Video sources for episodes (optional)
   * Map of episode ID to array of video sources
   */
  videoSources?: Record<number, VideoSource[]>
  /**
   * Watch progress data (optional)
   * Map of episode number to progress (0-1)
   */
  watchProgress?: Record<number, number>
  /**
   * Currently playing episode number (optional)
   */
  currentEpisode?: number
  /**
   * Additional CSS classes
   */
  className?: string
  /**
   * Loading state
   * @default false
   */
  loading?: boolean
}

/**
 * EpisodeList - Display episodes with metadata and progress
 * 
 * Implements:
 * - Episode number, title, air date display (Requirement 4.2)
 * - Progress indicators for watched episodes (Requirement 4.5)
 * - Multiple source options display (Requirement 4.4)
 * - Responsive layout
 * - Loading states
 * 
 * Requirements: 4.1, 4.2, 4.4, 4.5
 */
export const EpisodeList: React.FC<EpisodeListProps> = ({
  episodes,
  animeId,
  onEpisodeClick,
  videoSources = {},
  watchProgress = {},
  currentEpisode,
  className,
  loading = false,
}) => {
  // Format episode number for display
  const formatEpisodeNumber = (episode: Episode): string => {
    if (episode.type === 0) {
      // Main episode
      return `第${episode.sort}集`
    } else if (episode.type === 1) {
      return `SP${episode.sort}`
    } else if (episode.type === 2) {
      return `OP${episode.sort}`
    } else if (episode.type === 3) {
      return `ED${episode.sort}`
    }
    return `第${episode.sort}集`
  }

  // Get episode title (prefer Chinese)
  const getEpisodeTitle = (episode: Episode): string => {
    return episode.nameCn || episode.name || '未命名'
  }

  // Format air date
  const formatAirDate = (airdate: string): string => {
    if (!airdate) return ''
    
    try {
      const date = new Date(airdate)
      return date.toLocaleDateString('zh-CN', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
      })
    } catch {
      return airdate
    }
  }

  // Get progress percentage for an episode
  const getProgressPercentage = (episodeNumber: number): number => {
    return watchProgress[episodeNumber] || 0
  }

  // Check if episode has been watched (progress > 0)
  const isWatched = (episodeNumber: number): boolean => {
    const progress = getProgressPercentage(episodeNumber)
    return progress > 0 && progress < 1
  }

  // Check if episode is completed (progress >= 0.95)
  const isCompleted = (episodeNumber: number): boolean => {
    return getProgressPercentage(episodeNumber) >= 0.95
  }

  // Get video sources for an episode
  const getEpisodeSources = (episode: Episode): VideoSource[] => {
    return videoSources[episode.id] || []
  }

  // Loading state
  if (loading) {
    return (
      <div className={cn('space-y-3', className)}>
        {Array.from({ length: 5 }).map((_, i) => (
          <div
            key={i}
            className="glass-panel rounded-glass p-4 animate-pulse"
          >
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-gray-200 rounded-full" />
              <div className="flex-1 space-y-2">
                <div className="h-5 bg-gray-200 rounded w-3/4" />
                <div className="h-4 bg-gray-200 rounded w-1/2" />
              </div>
            </div>
          </div>
        ))}
      </div>
    )
  }

  // Empty state
  if (!episodes || episodes.length === 0) {
    return (
      <div className={cn('flex flex-col items-center justify-center py-12', className)}>
        <span className="material-symbols-rounded text-5xl text-gray-300 mb-3">
          movie_off
        </span>
        <p className="text-gray-500">暂无剧集信息</p>
      </div>
    )
  }

  return (
    <div className={cn('space-y-3', className)}>
      {episodes.map((episode) => {
        const sources = getEpisodeSources(episode)
        const progress = getProgressPercentage(episode.sort)
        const watched = isWatched(episode.sort)
        const completed = isCompleted(episode.sort)
        const isCurrent = currentEpisode === episode.sort

        return (
          <GlassCard
            key={episode.id}
            interactive
            hoverable
            padding="md"
            className={cn(
              'transition-all',
              isCurrent && 'ring-2 ring-[#FF6B6B]'
            )}
            onClick={() => onEpisodeClick?.(episode)}
          >
            <div className="flex items-start gap-4">
              {/* Episode Number Badge */}
              <div
                className={cn(
                  'flex-shrink-0 w-12 h-12 rounded-full flex items-center justify-center font-semibold text-sm',
                  completed
                    ? 'bg-[#FF6B6B]/20 text-[#FF6B6B]'
                    : watched
                    ? 'bg-[#E8D5D5] text-[#6b4848]'
                    : 'bg-[#F5F1E8] text-gray-700'
                )}
              >
                {episode.sort}
              </div>

              {/* Episode Info */}
              <div className="flex-1 min-w-0 space-y-2">
                {/* Title Row */}
                <div className="flex items-start justify-between gap-3">
                  <div className="flex-1 min-w-0">
                    <h3 className="font-semibold text-gray-900 line-clamp-1">
                      {formatEpisodeNumber(episode)}
                      {getEpisodeTitle(episode) && ` · ${getEpisodeTitle(episode)}`}
                    </h3>
                  </div>

                  {/* Status Icons */}
                  <div className="flex items-center gap-1 flex-shrink-0">
                    {completed && (
                      <span
                        className="material-symbols-rounded text-[#FF6B6B] text-xl"
                        title="已观看"
                      >
                        check_circle
                      </span>
                    )}
                    {isCurrent && (
                      <span
                        className="material-symbols-rounded text-[#FF6B6B] text-xl"
                        title="正在播放"
                      >
                        play_circle
                      </span>
                    )}
                  </div>
                </div>

                {/* Metadata Row */}
                <div className="flex flex-wrap items-center gap-3 text-sm text-gray-600">
                  {/* Air Date */}
                  {episode.airdate && (
                    <span className="flex items-center gap-1">
                      <span className="material-symbols-rounded text-base">
                        calendar_today
                      </span>
                      {formatAirDate(episode.airdate)}
                    </span>
                  )}

                  {/* Duration */}
                  {episode.duration && (
                    <span className="flex items-center gap-1">
                      <span className="material-symbols-rounded text-base">
                        schedule
                      </span>
                      {episode.duration}
                    </span>
                  )}
                </div>

                {/* Progress Bar */}
                {watched && progress > 0 && progress < 1 && (
                  <div className="space-y-1">
                    <div className="flex items-center justify-between text-xs text-gray-500">
                      <span>观看进度</span>
                      <span>{Math.round(progress * 100)}%</span>
                    </div>
                    <div className="h-1.5 bg-gray-200 rounded-full overflow-hidden">
                      <div
                        className="h-full bg-[#FF6B6B] rounded-full transition-all duration-300"
                        style={{ width: `${progress * 100}%` }}
                      />
                    </div>
                  </div>
                )}

                {/* Multiple Sources */}
                {sources.length > 1 && (
                  <div className="flex items-center gap-2 pt-1">
                    <span className="text-xs text-gray-500">播放源:</span>
                    <div className="flex flex-wrap gap-1">
                      {sources.map((source, index) => (
                        <GlassPill key={index} size="sm">
                          {source.plugin}
                        </GlassPill>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              {/* Play Button */}
              <Button
                variant="primary"
                size="icon"
                icon="play_arrow"
                aria-label={`播放${formatEpisodeNumber(episode)}`}
                onClick={(e) => {
                  e.stopPropagation()
                  onEpisodeClick?.(episode)
                }}
              />
            </div>
          </GlassCard>
        )
      })}
    </div>
  )
}
