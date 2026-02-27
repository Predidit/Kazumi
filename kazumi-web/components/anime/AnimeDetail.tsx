'use client'

import React, { useState, useEffect, useRef } from 'react'
import Image from 'next/image'
import { AnimeDetail as AnimeDetailType, Character } from '@/types'
import { GlassPanel } from '@/components/ui/GlassPanel'
import { GlassPill } from '@/components/ui/GlassPill'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils/cn'

export interface AnimeDetailProps {
  /**
   * Anime data to display
   */
  anime: AnimeDetailType
  /**
   * Characters data (optional)
   */
  characters?: Character[]
  /**
   * Whether anime is favorited
   */
  isFavorited?: boolean
  /**
   * Favorite toggle handler
   */
  onFavoriteToggle?: () => void
  /**
   * Additional CSS classes
   */
  className?: string
}

/**
 * AnimeDetail - Full anime information display with parallax cover
 * 
 * Implements:
 * - Parallax scrolling effect on cover image (Requirement 3.5)
 * - Complete anime information display (Requirement 3.2)
 * - Characters display (Requirement 3.3)
 * - Tags and metadata (Requirement 3.2)
 * - Favorite button with heart icon (Requirement 9.1, 9.2)
 * - Responsive layout
 * 
 * Requirements: 3.1, 3.2, 3.3, 3.4, 9.1, 9.2, 12.1
 */
export const AnimeDetail: React.FC<AnimeDetailProps> = ({
  anime,
  characters = [],
  isFavorited = false,
  onFavoriteToggle,
  className,
}) => {
  const [scrollY, setScrollY] = useState(0)
  const coverRef = useRef<HTMLDivElement>(null)

  // Use Chinese name if available
  const displayName = anime.nameCn || anime.name

  // Format rating
  const ratingScore = anime.rating?.score 
    ? anime.rating.score.toFixed(1) 
    : '暂无评分'

  // Extract info from infobox
  const getInfoboxValue = (key: string): string => {
    const item = anime.infobox?.find(
      (info) => info.key.toLowerCase() === key.toLowerCase()
    )
    if (!item) return ''
    
    if (typeof item.value === 'string') {
      return item.value
    }
    
    if (Array.isArray(item.value)) {
      return item.value.map((v) => v.v).join(', ')
    }
    
    return ''
  }

  const director = getInfoboxValue('导演') || getInfoboxValue('监督')
  const studio = getInfoboxValue('动画制作') || getInfoboxValue('制作')
  const originalWork = getInfoboxValue('原作')

  // Parallax effect on scroll
  useEffect(() => {
    const handleScroll = () => {
      if (coverRef.current) {
        const scrollPosition = window.scrollY
        setScrollY(scrollPosition)
      }
    }

    window.addEventListener('scroll', handleScroll, { passive: true })
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  // Calculate parallax transform
  const parallaxTransform = `translateY(${scrollY * 0.5}px)`

  return (
    <div className={cn('space-y-6', className)}>
      {/* Parallax Cover Section */}
      <div className="parallax-container relative h-[400px] sm:h-[500px] rounded-glass overflow-hidden">
        {/* Background Image with Parallax */}
        <div
          ref={coverRef}
          className="parallax-image absolute inset-0 w-full h-[120%]"
          style={{ transform: parallaxTransform }}
        >
          {anime.images?.large || anime.images?.common ? (
            <Image
              src={anime.images.large || anime.images.common}
              alt={displayName}
              fill
              sizes="100vw"
              className="object-cover"
              priority
            />
          ) : (
            <div className="w-full h-full bg-gradient-to-br from-[#F5F1E8] to-[#E8D5D5]" />
          )}
          {/* Gradient Overlay */}
          <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/40 to-transparent" />
        </div>

        {/* Content Overlay */}
        <div className="absolute inset-0 flex flex-col justify-end p-6 sm:p-8">
          <div className="space-y-4">
            {/* Title */}
            <h1 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-white drop-shadow-lg">
              {displayName}
            </h1>

            {/* Metadata Row */}
            <div className="flex flex-wrap items-center gap-3">
              {/* Rating */}
              {anime.rating?.score && (
                <div className="glass-panel rounded-full px-4 py-2 flex items-center gap-2">
                  <span className="material-symbols-rounded text-[#FF6B6B]">
                    star
                  </span>
                  <span className="font-semibold text-gray-900">
                    {ratingScore}
                  </span>
                </div>
              )}

              {/* Date */}
              {anime.date && (
                <div className="glass-panel rounded-full px-4 py-2 flex items-center gap-2">
                  <span className="material-symbols-rounded text-gray-700">
                    calendar_today
                  </span>
                  <span className="text-gray-900">{anime.date}</span>
                </div>
              )}

              {/* Episodes */}
              {anime.eps > 0 && (
                <div className="glass-panel rounded-full px-4 py-2 flex items-center gap-2">
                  <span className="material-symbols-rounded text-gray-700">
                    movie
                  </span>
                  <span className="text-gray-900">{anime.eps}集</span>
                </div>
              )}

              {/* Favorite Button */}
              <Button
                variant={isFavorited ? 'rose' : 'default'}
                size="icon"
                icon={isFavorited ? 'favorite' : 'favorite_border'}
                onClick={onFavoriteToggle}
                aria-label={isFavorited ? '取消收藏' : '添加收藏'}
                className="ml-auto"
              />
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="space-y-6">
        {/* Summary */}
        {anime.summary && (
          <GlassPanel className="p-6">
            <h2 className="text-xl font-semibold text-gray-900 mb-3 flex items-center gap-2">
              <span className="material-symbols-rounded text-[#FF6B6B]">
                description
              </span>
              简介
            </h2>
            <p className="text-gray-700 leading-relaxed whitespace-pre-wrap">
              {anime.summary}
            </p>
          </GlassPanel>
        )}

        {/* Info Grid */}
        <GlassPanel className="p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-4 flex items-center gap-2">
            <span className="material-symbols-rounded text-[#FF6B6B]">
              info
            </span>
            详细信息
          </h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {director && (
              <div>
                <span className="text-sm text-gray-500">导演</span>
                <p className="text-gray-900 font-medium">{director}</p>
              </div>
            )}
            {studio && (
              <div>
                <span className="text-sm text-gray-500">制作公司</span>
                <p className="text-gray-900 font-medium">{studio}</p>
              </div>
            )}
            {originalWork && (
              <div>
                <span className="text-sm text-gray-500">原作</span>
                <p className="text-gray-900 font-medium">{originalWork}</p>
              </div>
            )}
            {anime.platform && (
              <div>
                <span className="text-sm text-gray-500">播放平台</span>
                <p className="text-gray-900 font-medium">{anime.platform}</p>
              </div>
            )}
            {anime.rating?.rank && (
              <div>
                <span className="text-sm text-gray-500">排名</span>
                <p className="text-gray-900 font-medium">#{anime.rating.rank}</p>
              </div>
            )}
            {anime.collection && (
              <div>
                <span className="text-sm text-gray-500">收藏数</span>
                <p className="text-gray-900 font-medium">
                  {anime.collection.collect.toLocaleString()}
                </p>
              </div>
            )}
          </div>
        </GlassPanel>

        {/* Tags */}
        {anime.tags && anime.tags.length > 0 && (
          <GlassPanel className="p-6">
            <h2 className="text-xl font-semibold text-gray-900 mb-4 flex items-center gap-2">
              <span className="material-symbols-rounded text-[#FF6B6B]">
                label
              </span>
              标签
            </h2>
            <div className="flex flex-wrap gap-2">
              {anime.tags.slice(0, 15).map((tag, index) => (
                <GlassPill key={index} size="md">
                  {tag.name}
                </GlassPill>
              ))}
            </div>
          </GlassPanel>
        )}

        {/* Characters */}
        {characters && characters.length > 0 && (
          <GlassPanel className="p-6">
            <h2 className="text-xl font-semibold text-gray-900 mb-4 flex items-center gap-2">
              <span className="material-symbols-rounded text-[#FF6B6B]">
                people
              </span>
              角色
            </h2>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
              {characters.slice(0, 10).map((character) => (
                <div key={character.id} className="space-y-2">
                  {/* 角色图片 - 照抄原项目使用 large 或 medium 尺寸 */}
                  <div className="relative aspect-[3/4] rounded-glass overflow-hidden bg-gradient-to-br from-[#F5F1E8] to-[#E8D5D5]">
                    {character.images?.large || character.images?.medium || character.images?.common ? (
                      <Image
                        src={character.images.large || character.images.medium || character.images.common}
                        alt={character.name}
                        fill
                        sizes="(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 20vw"
                        className="object-cover"
                      />
                    ) : (
                      <div className="absolute inset-0 flex items-center justify-center">
                        <span className="material-symbols-rounded text-4xl text-gray-400">
                          person
                        </span>
                      </div>
                    )}
                  </div>
                  <div className="text-center">
                    <p className="text-sm font-medium text-gray-900 line-clamp-2">
                      {character.name}
                    </p>
                    {character.relation && (
                      <p className="text-xs text-gray-500">{character.relation}</p>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </GlassPanel>
        )}
      </div>
    </div>
  )
}
