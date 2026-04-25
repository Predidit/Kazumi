'use client'

import React, { useRef, useEffect, useState } from 'react'
import Image from 'next/image'
import { Character } from '@/types'
import { GlassCard } from '@/components/ui/GlassCard'
import { cn } from '@/lib/utils/cn'

export interface CharacterListProps {
  /**
   * Array of characters to display
   */
  characters: Character[]
  /**
   * Character click handler
   */
  onCharacterClick?: (character: Character) => void
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
   * Show voice actors
   * @default true
   */
  showActors?: boolean
}

/**
 * CharacterList - Horizontal scrolling character cards
 * 
 * Implements:
 * - Character cards with images and names (Requirement 3.3)
 * - Voice actor information display (Requirement 3.3)
 * - Horizontal scroll with no-scrollbar styling
 * - Touch-friendly interactions
 * - Responsive card sizing
 * 
 * Requirements: 3.3
 */
export const CharacterList: React.FC<CharacterListProps> = ({
  characters,
  onCharacterClick,
  className,
  loading = false,
  showActors = true,
}) => {
  const scrollRef = useRef<HTMLDivElement>(null)
  const [canScrollLeft, setCanScrollLeft] = useState(false)
  const [canScrollRight, setCanScrollRight] = useState(false)

  // Check scroll position to show/hide navigation buttons
  const checkScroll = () => {
    if (scrollRef.current) {
      const { scrollLeft, scrollWidth, clientWidth } = scrollRef.current
      setCanScrollLeft(scrollLeft > 0)
      setCanScrollRight(scrollLeft < scrollWidth - clientWidth - 10)
    }
  }

  useEffect(() => {
    checkScroll()
    const scrollElement = scrollRef.current
    if (scrollElement) {
      scrollElement.addEventListener('scroll', checkScroll, { passive: true })
      return () => scrollElement.removeEventListener('scroll', checkScroll)
    }
  }, [characters])

  // Scroll left/right
  const scroll = (direction: 'left' | 'right') => {
    if (scrollRef.current) {
      const scrollAmount = 300
      const newScrollLeft =
        direction === 'left'
          ? scrollRef.current.scrollLeft - scrollAmount
          : scrollRef.current.scrollLeft + scrollAmount

      scrollRef.current.scrollTo({
        left: newScrollLeft,
        behavior: 'smooth',
      })
    }
  }

  // Get primary voice actor
  const getPrimaryActor = (character: Character) => {
    if (!character.actors || character.actors.length === 0) return null
    // Return first actor (usually the primary one)
    return character.actors[0]
  }

  // Loading state
  if (loading) {
    return (
      <div className={cn('relative', className)}>
        <div className="flex gap-4 overflow-hidden">
          {Array.from({ length: 6 }).map((_, i) => (
            <div
              key={i}
              className="flex-shrink-0 w-[140px] sm:w-[160px] space-y-3 animate-pulse"
            >
              <div className="aspect-[3/4] bg-gray-200 rounded-glass" />
              <div className="space-y-2">
                <div className="h-4 bg-gray-200 rounded w-3/4" />
                <div className="h-3 bg-gray-200 rounded w-1/2" />
              </div>
            </div>
          ))}
        </div>
      </div>
    )
  }

  // Empty state
  if (!characters || characters.length === 0) {
    return (
      <div className={cn('flex flex-col items-center justify-center py-12', className)}>
        <span className="material-symbols-rounded text-5xl text-gray-300 mb-3">
          person_off
        </span>
        <p className="text-gray-500">暂无角色信息</p>
      </div>
    )
  }

  return (
    <div className={cn('relative group', className)}>
      {/* Scroll Left Button */}
      {canScrollLeft && (
        <button
          onClick={() => scroll('left')}
          className="absolute left-0 top-1/2 -translate-y-1/2 z-10 glass-panel rounded-full p-2 opacity-0 group-hover:opacity-100 transition-opacity duration-300 hover:bg-white/90"
          aria-label="向左滚动"
        >
          <span className="material-symbols-rounded text-gray-800">
            chevron_left
          </span>
        </button>
      )}

      {/* Scroll Right Button */}
      {canScrollRight && (
        <button
          onClick={() => scroll('right')}
          className="absolute right-0 top-1/2 -translate-y-1/2 z-10 glass-panel rounded-full p-2 opacity-0 group-hover:opacity-100 transition-opacity duration-300 hover:bg-white/90"
          aria-label="向右滚动"
        >
          <span className="material-symbols-rounded text-gray-800">
            chevron_right
          </span>
        </button>
      )}

      {/* Character Cards Container */}
      <div
        ref={scrollRef}
        className="flex gap-4 overflow-x-auto no-scrollbar scroll-smooth pb-2"
      >
        {characters.map((character) => {
          const actor = showActors ? getPrimaryActor(character) : null

          return (
            <div
              key={character.id}
              className="flex-shrink-0 w-[140px] sm:w-[160px]"
            >
              <GlassCard
                interactive={!!onCharacterClick}
                hoverable={!!onCharacterClick}
                padding="none"
                className="overflow-hidden h-full"
                onClick={() => onCharacterClick?.(character)}
              >
                {/* Character Image - 照抄原项目使用 medium 尺寸 */}
                <div className="relative aspect-[3/4] overflow-hidden bg-gradient-to-br from-[#F5F1E8] to-[#E8D5D5]">
                  {character.images?.large || character.images?.medium || character.images?.common ? (
                    <Image
                      src={character.images.large || character.images.medium || character.images.common}
                      alt={character.name}
                      fill
                      sizes="160px"
                      className="object-cover transition-transform duration-500 group-hover:scale-105"
                    />
                  ) : (
                    <div className="absolute inset-0 flex items-center justify-center">
                      <span className="material-symbols-rounded text-5xl text-gray-400">
                        person
                      </span>
                    </div>
                  )}
                </div>

                {/* Character Info */}
                <div className="p-3 space-y-2">
                  {/* Character Name */}
                  <div>
                    <p className="text-sm font-semibold text-gray-900 line-clamp-2 leading-tight">
                      {character.name}
                    </p>
                    {character.relation && (
                      <p className="text-xs text-gray-500 mt-0.5">
                        {character.relation}
                      </p>
                    )}
                  </div>

                  {/* Voice Actor */}
                  {actor && (
                    <div className="pt-2 border-t border-gray-200/50">
                      <p className="text-xs text-gray-500 mb-1">声优</p>
                      <div className="flex items-center gap-2">
                        {/* Actor Avatar */}
                        {actor.images?.small || actor.images?.medium ? (
                          <div className="relative w-6 h-6 rounded-full overflow-hidden flex-shrink-0 bg-gradient-to-br from-[#F5F1E8] to-[#E8D5D5]">
                            <Image
                              src={actor.images.small || actor.images.medium}
                              alt={actor.name}
                              fill
                              sizes="24px"
                              className="object-cover"
                            />
                          </div>
                        ) : (
                          <div className="w-6 h-6 rounded-full bg-gradient-to-br from-[#F5F1E8] to-[#E8D5D5] flex items-center justify-center flex-shrink-0">
                            <span className="material-symbols-rounded text-xs text-gray-400">
                              person
                            </span>
                          </div>
                        )}
                        {/* Actor Name */}
                        <p className="text-xs text-gray-700 font-medium line-clamp-1 flex-1">
                          {actor.name}
                        </p>
                      </div>
                    </div>
                  )}
                </div>
              </GlassCard>
            </div>
          )
        })}
      </div>

      {/* Scroll Hint (visible on mobile) */}
      {characters.length > 2 && (
        <div className="flex justify-center mt-3 sm:hidden">
          <div className="flex items-center gap-1 text-xs text-gray-400">
            <span className="material-symbols-rounded text-sm">
              swipe
            </span>
            <span>左右滑动查看更多</span>
          </div>
        </div>
      )}
    </div>
  )
}
