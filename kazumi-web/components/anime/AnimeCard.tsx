import React from 'react'
import Image from 'next/image'
import { AnimeDetail } from '@/types/anime'
import { GlassCard } from '@/components/ui/GlassCard'
import { cn } from '@/lib/utils/cn'

export interface AnimeCardProps {
  /**
   * Anime data to display
   */
  anime: AnimeDetail
  /**
   * Click handler for card interaction
   */
  onClick?: () => void
  /**
   * Additional CSS classes
   */
  className?: string
  /**
   * Whether to show full summary or truncate
   * @default true
   */
  truncateSummary?: boolean
  /**
   * Priority loading for above-the-fold images
   * @default false
   */
  priority?: boolean
}

/**
 * AnimeCard - Display anime cover, title, rating, and summary
 * 
 * Implements iOS 26 liquid glass aesthetic with:
 * - Next.js Image component for optimization (Requirement 12.1)
 * - Tap animation with spring easing (Requirement 10.8)
 * - Responsive layout
 * - Warm color palette
 * 
 * Requirements: 1.3, 2.2, 3.2, 12.1
 */
export const AnimeCard = React.forwardRef<HTMLDivElement, AnimeCardProps>(
  (
    {
      anime,
      onClick,
      className,
      truncateSummary = true,
      priority = false,
    },
    ref
  ) => {
    // Use Chinese name if available, fallback to original name
    const displayName = anime.nameCn || anime.name
    
    // Format rating score
    const ratingScore = anime.rating?.score 
      ? anime.rating.score.toFixed(1) 
      : '暂无评分'
    
    // Truncate summary if needed
    const displaySummary = truncateSummary && anime.summary?.length > 120
      ? `${anime.summary.slice(0, 120)}...`
      : anime.summary || '暂无简介'

    return (
      <GlassCard
        ref={ref}
        interactive={!!onClick}
        hoverable={!!onClick}
        padding="none"
        className={cn(
          'overflow-hidden group',
          className
        )}
        onClick={onClick}
        aria-label={`查看 ${displayName} 详情`}
      >
        {/* Cover Image - 照抄原项目使用 large 尺寸 */}
        <div className="relative w-full aspect-[3/4] overflow-hidden bg-gradient-to-br from-[#F5F1E8] to-[#E8D5D5]">
          {anime.images?.large || anime.images?.common || anime.images?.medium ? (
            <Image
              src={anime.images.large || anime.images.common || anime.images.medium}
              alt={displayName}
              fill
              sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw"
              className="object-cover transition-transform duration-500 group-hover:scale-105"
              priority={priority}
            />
          ) : (
            <div className="absolute inset-0 flex items-center justify-center">
              <span className="material-symbols-rounded text-6xl text-gray-400">
                image
              </span>
            </div>
          )}
          
          {/* Rating Badge */}
          {anime.rating?.score && (
            <div className="absolute top-2 right-2 glass-panel rounded-full px-3 py-1 flex items-center gap-1">
              <span className="material-symbols-rounded text-[#FF6B6B] text-sm">
                star
              </span>
              <span className="text-sm font-semibold text-gray-800">
                {ratingScore}
              </span>
            </div>
          )}
        </div>

        {/* Content */}
        <div className="p-4 space-y-2">
          {/* Title */}
          <h3 className="font-semibold text-gray-900 line-clamp-2 text-base leading-tight">
            {displayName}
          </h3>

          {/* Summary */}
          <p className="text-sm text-gray-600 line-clamp-3 leading-relaxed">
            {displaySummary}
          </p>

          {/* Metadata */}
          <div className="flex items-center gap-3 text-xs text-gray-500 pt-1">
            {anime.date && (
              <span className="flex items-center gap-1">
                <span className="material-symbols-rounded text-base">
                  calendar_today
                </span>
                {anime.date}
              </span>
            )}
            {anime.eps > 0 && (
              <span className="flex items-center gap-1">
                <span className="material-symbols-rounded text-base">
                  movie
                </span>
                {anime.eps}集
              </span>
            )}
          </div>
        </div>
      </GlassCard>
    )
  }
)

AnimeCard.displayName = 'AnimeCard'
