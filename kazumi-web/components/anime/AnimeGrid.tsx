'use client'

import React, { useRef, useCallback, useEffect, useState } from 'react'
import { AnimeDetail } from '@/types/anime'
import { AnimeCard } from './AnimeCard'
import { cn } from '@/lib/utils/cn'

export interface AnimeGridProps {
  /**
   * Array of anime to display
   */
  animes: AnimeDetail[]
  /**
   * Click handler for anime cards
   */
  onAnimeClick?: (anime: AnimeDetail) => void
  /**
   * Additional CSS classes
   */
  className?: string
  /**
   * Loading state
   * @default false
   */
  loading?: boolean
  /**
   * Empty state message
   * @default '暂无内容'
   */
  emptyMessage?: string
  /**
   * Enable lazy loading for images below fold
   * @default true
   */
  lazyLoad?: boolean
}

/**
 * AnimeGrid - Responsive grid layout for anime cards
 * 
 * Implements:
 * - Responsive grid (1 col mobile, 2-4 col tablet/desktop) (Requirement 14.1, 14.2)
 * - Lazy loading for images below fold (Requirement 12.3)
 * - Intersection Observer for performance
 * - Loading and empty states
 * 
 * Grid breakpoints:
 * - Mobile (< 640px): 1 column
 * - Tablet (640px - 1024px): 2 columns
 * - Desktop (1024px - 1536px): 3 columns
 * - Large Desktop (>= 1536px): 4 columns
 * 
 * Requirements: 12.3, 14.1, 14.2
 */
export const AnimeGrid: React.FC<AnimeGridProps> = ({
  animes,
  onAnimeClick,
  className,
  loading = false,
  emptyMessage = '暂无内容',
  lazyLoad = true,
}) => {
  const gridRef = useRef<HTMLDivElement>(null)
  const [visibleIndices, setVisibleIndices] = useState<Set<number>>(new Set())
  const observerRef = useRef<IntersectionObserver | null>(null)

  // Set up Intersection Observer for lazy loading
  useEffect(() => {
    if (!lazyLoad || typeof window === 'undefined') {
      // If lazy loading is disabled, mark all as visible
      setVisibleIndices(new Set(animes.map((_, i) => i)))
      return
    }

    // Create intersection observer
    observerRef.current = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            const index = parseInt(entry.target.getAttribute('data-index') || '0', 10)
            setVisibleIndices((prev) => new Set(Array.from(prev).concat(index)))
          }
        })
      },
      {
        root: null,
        rootMargin: '200px', // Start loading 200px before entering viewport
        threshold: 0.01,
      }
    )

    // Observe all grid items
    const gridItems = gridRef.current?.querySelectorAll('[data-index]')
    gridItems?.forEach((item) => {
      observerRef.current?.observe(item)
    })

    return () => {
      observerRef.current?.disconnect()
    }
  }, [animes.length, lazyLoad])

  // Handle anime card click
  const handleAnimeClick = useCallback(
    (anime: AnimeDetail) => {
      onAnimeClick?.(anime)
    },
    [onAnimeClick]
  )

  // Loading state
  if (loading) {
    return (
      <div className={cn('grid gap-4', className)}>
        <div className="grid grid-cols-2 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-4 gap-4">
          {Array.from({ length: 8 }).map((_, i) => (
            <div
              key={i}
              className="glass-panel rounded-glass overflow-hidden animate-pulse"
            >
              <div className="w-full aspect-[3/4] bg-gray-200" />
              <div className="p-4 space-y-3">
                <div className="h-5 bg-gray-200 rounded w-3/4" />
                <div className="h-4 bg-gray-200 rounded w-full" />
                <div className="h-4 bg-gray-200 rounded w-5/6" />
                <div className="flex gap-3">
                  <div className="h-4 bg-gray-200 rounded w-20" />
                  <div className="h-4 bg-gray-200 rounded w-16" />
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    )
  }

  // Empty state
  if (!animes || animes.length === 0) {
    return (
      <div className={cn('flex flex-col items-center justify-center py-16', className)}>
        <span className="material-symbols-rounded text-6xl text-gray-300 mb-4">
          search_off
        </span>
        <p className="text-gray-500 text-lg">{emptyMessage}</p>
      </div>
    )
  }

  return (
    <div
      ref={gridRef}
      className={cn(
        'grid grid-cols-2 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-4 gap-4',
        className
      )}
    >
      {animes.map((anime, index) => {
        // Determine if this card should be rendered
        // First 4 items are always visible (above fold on most screens)
        const isAboveFold = index < 4
        const isVisible = !lazyLoad || isAboveFold || visibleIndices.has(index)

        return (
          <div
            key={anime.id}
            data-index={index}
          >
            {isVisible ? (
              <AnimeCard
                anime={anime}
                onClick={() => handleAnimeClick(anime)}
                priority={isAboveFold} // Priority load for above-fold images
              />
            ) : (
              // Placeholder for lazy-loaded items
              <div className="glass-panel rounded-glass w-full aspect-[3/4]" />
            )}
          </div>
        )
      })}
    </div>
  )
}
